local fs = require("@std/fs")
local types = require("./types")

local Image = {}
Image.__index = Image

export type Image = typeof(setmetatable(
	{} :: { width: number, height: number, data: string, dataOffset: number },
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

local function makeImage(raw: string): Image
	local width, height, dataOffset = parsePpm(raw)

	return setmetatable({ width = width, height = height, data = raw, dataOffset = dataOffset }, Image)
end

function Image.preload(path: string, raw: string)
	cache[path] = makeImage(raw)
end

function Image.hasCached(path: string): boolean
	return cache[path] ~= nil
end

function Image.new(path: string): types.Texture
	local cached = cache[path]

	if cached then
		return cached :: any
	end

	return makeImage(readFile(path)) :: any
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

	local x = math.floor(u * self.width)
	local y = math.floor((1 - v) * self.height)

	if x >= self.width then
		x = self.width - 1
	end

	if y >= self.height then
		y = self.height - 1
	end

	local idx = self.dataOffset + (y * self.width + x) * 3
	local r, g, b = string.byte(self.data, idx, idx + 2)

	return vector.create(r / 255, g / 255, b / 255)
end

return Image
