--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")
local ONB = require("../math/onb")
local Ray = require("../core/ray")
local textureTypes = require("../textures/types")

local environment = {}

export type LightSample = {
	dir: vector,
	distance: number,
	emitted: vector,
	probability: number,
	delta: boolean?,
}

export type Environment = {
	value: (any, r: Ray.Ray) -> vector,
	sample: (any) -> LightSample,
	probabilityValue: (any, direction: vector) -> number,
}

local INV_4PI = 1 / (4 * math.pi)

-- helpers
local function directionToUv(direction: vector): (number, number)
	local unitDir = Vec3.unitVector(direction)
	local theta = math.acos(math.clamp(-unitDir.y, -1, 1))
	local phi = math.atan2(-unitDir.z, unitDir.x) + math.pi

	return phi / (2 * math.pi), theta / math.pi
end

local function randomUnitVector(): vector
	local z = 1 - 2 * math.random()
	local phi = 2 * math.pi * math.random()
	local r = math.sqrt(math.max(0, 1 - z * z))

	return vector.create(r * math.cos(phi), z, r * math.sin(phi))
end

local function randomToCone(axis: vector, cosThetaMax: number): vector
	local z = 1 - math.random() * (1 - cosThetaMax)
	local phi = 2 * math.pi * math.random()
	local r = math.sqrt(math.max(0, 1 - z * z))

	return vector.normalize(ONB.new(axis):transform(vector.create(r * math.cos(phi), r * math.sin(phi), z)))
end

-- sun
local ProceduralSun = {}
ProceduralSun.__index = ProceduralSun

export type ProceduralSun = typeof(setmetatable(
	{} :: {
		toSun: vector,
		sunColor: vector,
		sunIntensity: number,
		skyHorizon: vector,
		skyZenith: vector,
		groundColor: vector,
		skyIntensity: number,
		sunCos: number,
		sunPdf: number,
		sunWeight: number,
		skyWeight: number,
	},
	ProceduralSun
))

function ProceduralSun.new(config: {
	toSun: vector,
	sunColor: vector?,
	sunIntensity: number?,
	skyHorizon: vector?,
	skyZenith: vector?,
	groundColor: vector?,
	skyIntensity: number?,
	sunAngleDegrees: number?,
	sunWeight: number?,
}): Environment
	local angle = math.rad(config.sunAngleDegrees or 0.75)
	local sunCos = math.cos(angle)
	local sunSolidAngle = 2 * math.pi * (1 - sunCos)
	local sunWeight = math.clamp(config.sunWeight or 0.7, 0.05, 0.95)

	return setmetatable({
		toSun = Vec3.unitVector(config.toSun),
		sunColor = config.sunColor or vector.create(1.0, 0.68, 0.38),
		sunIntensity = config.sunIntensity or 16,
		skyHorizon = config.skyHorizon or vector.create(0.95, 0.48, 0.25),
		skyZenith = config.skyZenith or vector.create(0.08, 0.08, 0.20),
		groundColor = config.groundColor or vector.create(0.03, 0.025, 0.03),
		skyIntensity = config.skyIntensity or 1,
		sunCos = sunCos,
		sunPdf = 1 / sunSolidAngle,
		sunWeight = sunWeight,
		skyWeight = 1 - sunWeight,
	}, ProceduralSun) :: any
end

function ProceduralSun.valueDirection(self: ProceduralSun, direction: vector): vector
	local dir = Vec3.unitVector(direction)
	local t = math.clamp(0.5 * (dir.y + 1), 0, 1)
	local base = ((1 - t) * self.skyHorizon + t * self.skyZenith) * self.skyIntensity

	local sunDot = vector.dot(dir, self.toSun)
	if sunDot >= self.sunCos then
		return base + self.sunColor * self.sunIntensity
	end

	local halo = math.max(0, (sunDot - 0.93) / 0.07) ^ 4

	return base + self.sunColor * (self.sunIntensity * 0.035 * halo)
end

function ProceduralSun.value(self: ProceduralSun, r: Ray.Ray): vector
	return self:valueDirection(r.direction)
end

function ProceduralSun.sample(self: ProceduralSun): LightSample
	local dir
	if math.random() < self.sunWeight then
		dir = randomToCone(self.toSun, self.sunCos)
	else
		dir = randomUnitVector()
	end

	return {
		dir = dir,
		distance = math.huge,
		emitted = self:valueDirection(dir),
		probability = self:probabilityValue(dir),
		delta = false,
	}
end

function ProceduralSun.probabilityValue(self: ProceduralSun, direction: vector): number
	local dir = Vec3.unitVector(direction)
	local pdf = self.skyWeight * INV_4PI

	if vector.dot(dir, self.toSun) >= self.sunCos then
		pdf += self.sunWeight * self.sunPdf
	end

	return pdf
end

-- latitude and longitude
local LatLong = {}
LatLong.__index = LatLong

export type LatLong = typeof(setmetatable(
	{} :: {
		texture: textureTypes.Texture,
		intensity: number,
	},
	LatLong
))

function LatLong.new(texture: textureTypes.Texture, intensity: number?): Environment
	return setmetatable({ texture = texture, intensity = intensity or 1 }, LatLong) :: any
end

function LatLong.valueDirection(self: LatLong, direction: vector): vector
	local u, v = directionToUv(direction)

	return self.texture:value(u, v, vector.zero) * self.intensity
end

function LatLong.value(self: LatLong, r: Ray.Ray): vector
	return self:valueDirection(r.direction)
end

function LatLong.sample(self: LatLong): LightSample
	local dir = randomUnitVector()
	local emitted = self:valueDirection(dir)

	return {
		dir = dir,
		distance = math.huge,
		emitted = emitted,
		probability = INV_4PI,
		delta = false,
	}
end

function LatLong.probabilityValue(_self: LatLong, _direction: vector): number
	return INV_4PI
end

environment.ProceduralSun = ProceduralSun
environment.LatLong = LatLong
environment.directionToUv = directionToUv

return environment
