--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")
local ONB = require("../math/onb")
local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local textures = require("../textures")
local textureTypes = require("../textures/types")

local PBR = {}
PBR.__index = PBR

local PBRPdf = {}
PBRPdf.__index = PBRPdf

export type PBR = typeof(setmetatable(
	{} :: {
		texture: textureTypes.Texture,
		metallic: number,
		roughness: number,
	},
	PBR
))

local DIELECTRIC_F0 = vector.create(0.04, 0.04, 0.04)
local MIN_ROUGHNESS = 0.02
local EPS = 1e-6

local function maxComponent(v: vector): number
	return math.max(v.x, v.y, v.z)
end

local function luminance(v: vector): number
	return 0.2126 * v.x + 0.7152 * v.y + 0.0722 * v.z
end

local function safeUnit(v: vector): vector?
	if Vec3.lengthSquared(v) <= EPS then
		return nil
	end

	return vector.normalize(v)
end

local function alphaFor(roughness: number): number
	local r = math.max(MIN_ROUGHNESS, roughness)

	return r * r
end

local function fresnelSchlick(cosTheta: number, f0: vector): vector
	local f = (1 - math.clamp(cosTheta, 0, 1)) ^ 5

	return f0 + (vector.one - f0) * f
end

local function ggxD(nDotH: number, alpha: number): number
	local a2 = alpha * alpha
	local denom = nDotH * nDotH * (a2 - 1) + 1

	return a2 / (math.pi * denom * denom)
end

local function smithG1(nDotX: number, alpha: number): number
	if nDotX <= 0 then
		return 0
	end

	local a2 = alpha * alpha

	return 2 * nDotX / (nDotX + math.sqrt(a2 + (1 - a2) * nDotX * nDotX))
end

local function f0For(albedo: vector, metallic: number): vector
	return DIELECTRIC_F0 * (1 - metallic) + albedo * metallic
end

local function specularChance(albedo: vector, metallic: number): number
	return math.clamp(0.5 * metallic + luminance(f0For(albedo, metallic)), 0.1, 0.9)
end

local function sampleGgxNormal(normal: vector, alpha: number): vector
	local u1 = math.random()
	local u2 = math.random()
	local phi = 2 * math.pi * u1
	local a2 = alpha * alpha
	local cosTheta = math.sqrt((1 - u2) / (1 + (a2 - 1) * u2))
	local sinTheta = math.sqrt(math.max(0, 1 - cosTheta * cosTheta))
	local localH = vector.create(math.cos(phi) * sinTheta, math.sin(phi) * sinTheta, cosTheta)

	return vector.normalize(ONB.new(normal):transform(localH))
end

local function evaluateWithAlbedo(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord, wi: vector, albedo: vector): vector
	local n = rec.normal
	local l = safeUnit(wi)
	local v = safeUnit(-rIn.direction)

	if not l or not v then
		return vector.zero
	end

	local nDotL = vector.dot(n, l)
	local nDotV = vector.dot(n, v)

	if nDotL <= 0 or nDotV <= 0 then
		return vector.zero
	end

	local h = safeUnit(l + v)
	if not h then
		return vector.zero
	end

	local nDotH = math.max(0, vector.dot(n, h))
	local vDotH = math.max(0, vector.dot(v, h))

	if nDotH <= 0 or vDotH <= 0 then
		return vector.zero
	end

	local alpha = alphaFor(self.roughness)
	local f0 = f0For(albedo, self.metallic)
	local f = fresnelSchlick(vDotH, f0)
	local d = ggxD(nDotH, alpha)
	local g = smithG1(nDotL, alpha) * smithG1(nDotV, alpha)
	local specular = f * (d * g / math.max(EPS, 4 * nDotL * nDotV))
	local diffuse = (vector.one - f) * (1 - self.metallic) * albedo / math.pi

	return (diffuse + specular) * nDotL
end

local function diffusePdf(rec: hittable.HitRecord, wi: vector): number
	local l = safeUnit(wi)
	if not l then
		return 0
	end

	return math.max(0, vector.dot(rec.normal, l)) / math.pi
end

local function specularPdf(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord, wi: vector): number
	local l = safeUnit(wi)
	local v = safeUnit(-rIn.direction)

	if not l or not v then
		return 0
	end

	if vector.dot(rec.normal, l) <= 0 or vector.dot(rec.normal, v) <= 0 then
		return 0
	end

	local h = safeUnit(l + v)
	if not h then
		return 0
	end

	local nDotH = math.max(0, vector.dot(rec.normal, h))
	local vDotH = math.max(0, vector.dot(v, h))

	if nDotH <= 0 or vDotH <= 0 then
		return 0
	end

	return ggxD(nDotH, alphaFor(self.roughness)) * nDotH / (4 * vDotH)
end

local function mixturePdf(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord, wi: vector, albedo: vector): number
	local chance = specularChance(albedo, self.metallic)

	return chance * specularPdf(self, rIn, rec, wi) + (1 - chance) * diffusePdf(rec, wi)
end

function PBR.new(albedo: vector | textureTypes.Texture, metallic: number?, roughness: number?): hittable.Material
	local entity: textureTypes.Texture

	if typeof(albedo) == "vector" then
		entity = textures.Solid.new(albedo :: vector)
	else
		entity = albedo :: textureTypes.Texture
	end

	return setmetatable({
		texture = entity,
		metallic = math.clamp(metallic or 0, 0, 1),
		roughness = math.clamp(roughness or 0.5, MIN_ROUGHNESS, 1),
	}, PBR) :: any
end

function PBR.scatter(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord): (vector?, Ray.Ray?)
	local albedo = self:textureAlbedo(rec)
	local chance = specularChance(albedo, self.metallic)
	local scatteredDir: vector? = nil

	if math.random() < chance then
		local v = safeUnit(-rIn.direction)

		if v then
			for _ = 1, 8 do
				local h = sampleGgxNormal(rec.normal, alphaFor(self.roughness))
				local l = Vec3.reflect(-v, h)

				if vector.dot(l, rec.normal) > EPS then
					scatteredDir = vector.normalize(l)
					break
				end
			end
		end
	end

	if not scatteredDir then
		scatteredDir = vector.normalize(ONB.new(rec.normal):transform(Vec3.randomCosineDirection()))
	end

	local direction = scatteredDir :: vector
	local pdf = mixturePdf(self, rIn, rec, direction, albedo)
	if pdf <= EPS then
		return nil, nil
	end

	local attenuation = evaluateWithAlbedo(self, rIn, rec, direction, albedo) / pdf
	if maxComponent(attenuation) <= 0 then
		return nil, nil
	end

	return attenuation, Ray.new(rec.p, direction, rIn.time, rIn.wavelength)
end

function PBR.probability(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord)
	return setmetatable({ material = self, rIn = rIn, rec = rec }, PBRPdf)
end

function PBR.evalDirect(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord, wi: Vec3.Vec3): vector
	return evaluateWithAlbedo(self, rIn, rec, wi, self:textureAlbedo(rec))
end

function PBR.textureAlbedo(self: PBR, rec: hittable.HitRecord): vector
	return self.texture:value(rec.u, rec.v, rec.p)
end

function PBR.surfaceAlbedo(self: PBR, rec: hittable.HitRecord): vector
	return self:textureAlbedo(rec)
end

function PBR.specularBounce(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord): Ray.Ray?
	if self.metallic < 0.9 or self.roughness > 0.05 then
		return nil
	end

	local reflected = Vec3.reflect(Vec3.unitVector(rIn.direction), rec.normal)
	if vector.dot(reflected, rec.normal) <= 0 then
		return nil
	end

	return Ray.new(rec.p, reflected, rIn.time, rIn.wavelength)
end

function PBRPdf.value(self: { material: PBR, rIn: Ray.Ray, rec: hittable.HitRecord }, direction: vector): number
	return mixturePdf(self.material, self.rIn, self.rec, direction, self.material:textureAlbedo(self.rec))
end

return PBR
