--!strict
--!optimize 2
--!native

local sampler = {}

local BASES = { 2, 3, 5, 7, 11, 13, 17, 19 }

-- Halton sequence
local HASH_X = 127.1
local HASH_Y = 311.7
local HASH_DIMENSION = 74.7
local HASH_SCALE = 43758.5453123

local function fract(x: number): number
	return x - math.floor(x)
end

local function hash01(i: number, j: number, dimension: number): number
	local n = (i + 1) * HASH_X + (j + 1) * HASH_Y + (dimension + 1) * HASH_DIMENSION

	return fract(math.sin(n) * HASH_SCALE)
end

function sampler.radicalInverse(index: number, base: number): number
	local invBase = 1 / base
	local invBi = invBase
	local n = index
	local value = 0

	while n > 0 do
		value += (n % base) * invBi
		n = math.floor(n / base)
		invBi *= invBase
	end

	return value
end

function sampler.dimension(i: number, j: number, sampleIndex: number, dimension: number): number
	local base = BASES[(dimension % #BASES) + 1]
	local value = sampler.radicalInverse(math.max(0, sampleIndex - 1), base)

	return fract(value + hash01(i, j, dimension))
end

function sampler.square(i: number, j: number, sampleIndex: number, dimension: number): vector
	return vector.create(
		sampler.dimension(i, j, sampleIndex, dimension),
		sampler.dimension(i, j, sampleIndex, dimension + 1),
		0
	)
end

function sampler.centeredSquare(i: number, j: number, sampleIndex: number, dimension: number): vector
	return sampler.square(i, j, sampleIndex, dimension) - vector.create(0.5, 0.5, 0)
end

function sampler.disk(i: number, j: number, sampleIndex: number, dimension: number): vector
	local u = sampler.square(i, j, sampleIndex, dimension) * 2 - vector.create(1, 1, 0)

	if u.x == 0 and u.y == 0 then
		return vector.zero
	end

	local r
	local theta

	if math.abs(u.x) > math.abs(u.y) then
		r = u.x
		theta = (math.pi / 4) * (u.y / u.x)
	else
		r = u.y
		theta = (math.pi / 2) - (math.pi / 4) * (u.x / u.y)
	end

	return vector.create(r * math.cos(theta), r * math.sin(theta), 0)
end

return sampler
