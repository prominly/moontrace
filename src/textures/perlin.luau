--!strict
--!optimize 2
--!native

local types = require("./types")

local NoiseTexture = {}
NoiseTexture.__index = NoiseTexture

export type NoiseTexture = typeof(setmetatable({} :: { scale: number, depth: number }, NoiseTexture))

local POINT_COUNT = 256
local GREY = vector.create(0.5, 0.5, 0.5)

-- fixed seed so each worker VM ends up with the same lattice tables
math.randomseed(12345)

local function generatePerm(): { number }
	local perm = table.create(POINT_COUNT)

	for i = 1, POINT_COUNT do
		perm[i] = i - 1
	end

	for i = POINT_COUNT, 2, -1 do
		local target = math.random(1, i)
		perm[i], perm[target] = perm[target], perm[i]
	end

	return perm
end

local randvec: { vector } = table.create(POINT_COUNT)
for i = 1, POINT_COUNT do
	randvec[i] = vector.normalize(vector.create(-1 + 2 * math.random(), -1 + 2 * math.random(), -1 + 2 * math.random()))
end

local permX = generatePerm()
local permY = generatePerm()
local permZ = generatePerm()

local function noise(p: vector): number
	local px, py, pz = p.x, p.y, p.z
	local fi = math.floor(px)
	local fj = math.floor(py)
	local fk = math.floor(pz)
	local u = px - fi
	local v = py - fj
	local w = pz - fk

	local uu = u * u * (3 - 2 * u)
	local vv = v * v * (3 - 2 * v)
	local ww = w * w * (3 - 2 * w)

	local accum = 0

	for di = 0, 1 do
		local ix = (fi + di) % POINT_COUNT
		local wu = if di == 1 then uu else 1 - uu

		for dj = 0, 1 do
			local iy = (fj + dj) % POINT_COUNT
			local wv = if dj == 1 then vv else 1 - vv

			for dk = 0, 1 do
				local iz = (fk + dk) % POINT_COUNT
				local ww2 = if dk == 1 then ww else 1 - ww

				local index = bit32.bxor(permX[ix + 1], permY[iy + 1], permZ[iz + 1])
				local c = randvec[index + 1]
				local weightV = vector.create(u - di, v - dj, w - dk)

				accum += wu * wv * ww2 * vector.dot(c, weightV)
			end
		end
	end

	return accum
end

local function turb(p: vector, depth: number): number
	local accum = 0
	local tempP = p
	local weight = 1.0

	for _ = 1, depth do
		accum += weight * noise(tempP)
		weight *= 0.5
		tempP *= 2
	end

	return math.abs(accum)
end

function NoiseTexture.new(scale: number, depth: number?): types.Texture
	return setmetatable({ scale = scale, depth = depth or 7 }, NoiseTexture) :: any
end

function NoiseTexture.bump(scale: number): types.Texture
	return NoiseTexture.new(scale, 3)
end

function NoiseTexture.value(self: NoiseTexture, _u: number, _v: number, p: vector): vector
	return GREY * (1 + math.sin(self.scale * p.z + 10 * turb(p, self.depth)))
end

NoiseTexture.noise = noise
NoiseTexture.turb = turb

return NoiseTexture
