--!strict
--!optimize 2
--!native

local fs = require("@std/fs")
local types = require("./types")

local Image = {}
Image.__index = Image

export type Image = typeof(setmetatable(
	{} :: { width: number, height: number, data: string, dataOffset: number, linear: boolean },
	Image
))

local function readFile(path: string): string
	local handle = fs.open(path, "r")
	local raw = fs.read(handle)

	fs.close(handle)

	return raw
end

local function parsePpm(raw: string): (number, number, number)
	local pos = 1

	local function skipWs()
		while pos <= #raw do
			local c = string.byte(raw, pos)

			if c == 0x20 or c == 0x09 or c == 0x0A or c == 0x0D then
				pos += 1
			elseif c == 0x23 then
				while pos <= #raw and string.byte(raw, pos) ~= 0x0A do
					pos += 1
				end
			else
				break
			end
		end
	end

	local function token(): string
		skipWs()

		local start = pos
		while pos <= #raw do
			local c = string.byte(raw, pos)

			if c == 0x20 or c == 0x09 or c == 0x0A or c == 0x0D then
				break
			end

			pos += 1
		end

		return string.sub(raw, start, pos - 1)
	end

	if token() ~= "P6" then
		error("not a P6 PPM")
	end

	local width = assert(tonumber(token()), "PPM: bad width")
	local height = assert(tonumber(token()), "PPM: bad height")
	local max_value = assert(tonumber(token()), "PPM: bad max_value")

	if max_value ~= 255 then
		error("PPM max value must be 255, got " .. tostring(max_value))
	end

	pos += 1

	return width, height, pos
end

local cache: { [string]: Image } = {}

local function makeImage(raw: string, linear: boolean): Image
	local width, height, dataOffset = parsePpm(raw)

	return setmetatable({ width = width, height = height, data = raw, dataOffset = dataOffset, linear = linear }, Image)
end

local function withColorSpace(image: Image, linear: boolean): Image
	if image.linear == linear then
		return image
	end

	return setmetatable({
		width = image.width,
		height = image.height,
		data = image.data,
		dataOffset = image.dataOffset,
		linear = linear,
	}, Image)
end

function Image.preload(path: string, raw: string)
	cache[path] = makeImage(raw, true)
end

function Image.hasCached(path: string): boolean
	return cache[path] ~= nil
end

function Image.new(path: string, linear: boolean?): types.Texture
	local sampleLinear = if linear == nil then true else linear
	local cached = cache[path]

	if cached then
		return withColorSpace(cached, sampleLinear) :: any
	end

	return makeImage(readFile(path), sampleLinear) :: any
end

local function srgbToLinear(c: number): number
	if c <= 0.04045 then
		return c / 12.92
	end

	return ((c + 0.055) / 1.055) ^ 2.4
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function sampleByte(self: Image, x: number, y: number): vector
	local index = self.dataOffset + (y * self.width + x) * 3
	local r, g, b = string.byte(self.data, index, index + 2)

	local rf = r / 255
	local gf = g / 255
	local bf = b / 255

	if not self.linear then
		rf = srgbToLinear(rf)
		gf = srgbToLinear(gf)
		bf = srgbToLinear(bf)
	end

	return vector.create(rf, gf, bf)
end

function Image.value(self: Image, u: number, v: number, _p: vector): vector
	if u < 0 then
		u = 0
	elseif u > 1 then
		u = 1
	end

	if v < 0 then
		v = 0
	elseif v > 1 then
		v = 1
	end

	local x = u * (self.width - 1)
	local y = (1 - v) * (self.height - 1)

	local x0 = math.floor(x)
	local x1 = math.min(x0 + 1, self.width - 1)

	local y0 = math.floor(y)
	local y1 = math.min(y0 + 1, self.height - 1)

	local tx = x - x0
	local ty = y - y0

	local c00 = sampleByte(self, x0, y0)
	local c10 = sampleByte(self, x1, y0)
	local c01 = sampleByte(self, x0, y1)
	local c11 = sampleByte(self, x1, y1)

	local r0 = lerp(c00.x, c10.x, tx)
	local r1 = lerp(c01.x, c11.x, tx)

	local g0 = lerp(c00.y, c10.y, tx)
	local g1 = lerp(c01.y, c11.y, tx)

	local b0 = lerp(c00.z, c10.z, tx)
	local b1 = lerp(c01.z, c11.z, tx)

	return vector.create(lerp(r0, r1, ty), lerp(g0, g1, ty), lerp(b0, b1, ty))
end

return Image
