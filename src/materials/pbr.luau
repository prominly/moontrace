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

type ScalarInput = number | textureTypes.Texture
type Surface = {
	albedo: vector,
	metallic: number,
	roughness: number,
	normal: vector,
}

export type PBR = typeof(setmetatable(
	{} :: {
		texture: textureTypes.Texture,
		metallic: number,
		metallicTexture: textureTypes.Texture?,
		roughness: number,
		roughnessTexture: textureTypes.Texture?,
		normalTexture: textureTypes.Texture?,
		bumpTexture: textureTypes.Texture?,
		bumpStrength: number,
	},
	PBR
))

local DIELECTRIC_F0 = vector.create(0.04, 0.04, 0.04)
local MIN_ROUGHNESS = 0.02
local EPS = 1e-6
local BUMP_UV_STEP = 0.001
local BUMP_POSITION_STEP = 0.01

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

local function textureFrom(input: vector | textureTypes.Texture): textureTypes.Texture
	if typeof(input) == "vector" then
		return textures.Solid.new(input :: vector)
	end

	return input :: textureTypes.Texture
end

local function scalarInput(input: ScalarInput?, defaultValue: number): (number, textureTypes.Texture?)
	if typeof(input) == "number" then
		return math.clamp(input :: number, 0, 1), nil
	end

	if input then
		return math.clamp(defaultValue, 0, 1), input :: textureTypes.Texture
	end

	return math.clamp(defaultValue, 0, 1), nil
end

local function scalarValue(texture: textureTypes.Texture?, fallback: number, rec: hittable.HitRecord): number
	if texture then
		return math.clamp(texture:value(rec.u, rec.v, rec.p).x, 0, 1)
	end

	return fallback
end

local function heightValue(texture: textureTypes.Texture, u: number, v: number, p: vector): number
	local h = texture:value(u, v, p)

	return 0.2126 * h.x + 0.7152 * h.y + 0.0722 * h.z
end

local function normalFromMap(texture: textureTypes.Texture?, rec: hittable.HitRecord): vector
	if not texture then
		return rec.normal
	end

	local sampled = texture:value(rec.u, rec.v, rec.p)
	local tangentNormal = vector.create(sampled.x * 2 - 1, sampled.y * 2 - 1, sampled.z * 2 - 1)

	if Vec3.lengthSquared(tangentNormal) <= EPS then
		return rec.normal
	end

	tangentNormal = vector.normalize(tangentNormal)

	local n =
		vector.normalize(rec.tangent * tangentNormal.x + rec.bitangent * tangentNormal.y + rec.normal * tangentNormal.z)
	if vector.dot(n, rec.normal) <= EPS then
		return rec.normal
	end

	return n
end

local function bumpedNormal(
	texture: textureTypes.Texture?,
	strength: number,
	baseNormal: vector,
	rec: hittable.HitRecord
): vector
	if not texture or strength <= 0 then
		return baseNormal
	end

	local u = rec.u
	local v = rec.v
	local p = rec.p

	local tangent = rec.tangent
	local bitangent = rec.bitangent

	local hU0 = heightValue(texture, u - BUMP_UV_STEP, v, p - tangent * BUMP_POSITION_STEP)
	local hU1 = heightValue(texture, u + BUMP_UV_STEP, v, p + tangent * BUMP_POSITION_STEP)
	local hV0 = heightValue(texture, u, v - BUMP_UV_STEP, p - bitangent * BUMP_POSITION_STEP)
	local hV1 = heightValue(texture, u, v + BUMP_UV_STEP, p + bitangent * BUMP_POSITION_STEP)

	local dU = hU1 - hU0
	local dV = hV1 - hV0

	local n = vector.normalize(baseNormal - strength * (dU * tangent + dV * bitangent))

	if vector.dot(n, rec.normal) <= EPS then
		return baseNormal
	end

	return n
end

local function surfaceAt(self: PBR, rec: hittable.HitRecord): Surface
	local normal = normalFromMap(self.normalTexture, rec)

	return {
		albedo = self.texture:value(rec.u, rec.v, rec.p),
		metallic = scalarValue(self.metallicTexture, self.metallic, rec),
		roughness = math.max(MIN_ROUGHNESS, scalarValue(self.roughnessTexture, self.roughness, rec)),
		normal = bumpedNormal(self.bumpTexture, self.bumpStrength, normal, rec),
	}
end

local function evaluateSurface(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord, wi: vector, surface: Surface): vector
	local n = surface.normal
	local l = safeUnit(wi)
	local v = safeUnit(-rIn.direction)

	if not l or not v then
		return vector.zero
	end

	if vector.dot(rec.normal, l) <= 0 or vector.dot(rec.normal, v) <= 0 then
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

	local albedo = surface.albedo
	local metallic = surface.metallic
	local alpha = alphaFor(surface.roughness)

	local f0 = f0For(albedo, metallic)
	local f = fresnelSchlick(vDotH, f0)
	local d = ggxD(nDotH, alpha)
	local g = smithG1(nDotL, alpha) * smithG1(nDotV, alpha)

	local specular = f * (d * g / math.max(EPS, 4 * nDotL * nDotV))
	local diffuse = (vector.one - f) * (1 - metallic) * albedo / math.pi

	return (diffuse + specular) * nDotL
end

local function diffusePdf(normal: vector, rec: hittable.HitRecord, wi: vector): number
	local l = safeUnit(wi)
	if not l then
		return 0
	end

	if vector.dot(rec.normal, l) <= 0 then
		return 0
	end

	return math.max(0, vector.dot(normal, l)) / math.pi
end

local function specularPdf(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord, wi: vector, surface: Surface): number
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

	local nDotH = math.max(0, vector.dot(surface.normal, h))
	local vDotH = math.max(0, vector.dot(v, h))

	if nDotH <= 0 or vDotH <= 0 then
		return 0
	end

	return ggxD(nDotH, alphaFor(surface.roughness)) * nDotH / (4 * vDotH)
end

local function mixturePdf(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord, wi: vector, surface: Surface): number
	local chance = specularChance(surface.albedo, surface.metallic)

	return chance * specularPdf(self, rIn, rec, wi, surface) + (1 - chance) * diffusePdf(surface.normal, rec, wi)
end

function PBR.new(
	albedo: vector | textureTypes.Texture,
	metallic: ScalarInput?,
	roughness: ScalarInput?,
	normalMap: textureTypes.Texture?,
	bumpMap: textureTypes.Texture?,
	bumpStrength: number?
): hittable.Material
	local metallicValue, metallicTexture = scalarInput(metallic, 0)
	local roughnessValue, roughnessTexture = scalarInput(roughness, 0.5)

	return setmetatable({
		texture = textureFrom(albedo),
		metallic = metallicValue,
		metallicTexture = metallicTexture,
		roughness = math.max(MIN_ROUGHNESS, roughnessValue),
		roughnessTexture = roughnessTexture,
		normalTexture = normalMap,
		bumpTexture = bumpMap,
		bumpStrength = math.max(0, bumpStrength or 0.05),
	}, PBR) :: any
end

function PBR.scatter(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord): (vector?, Ray.Ray?)
	local surface = surfaceAt(self, rec)
	local chance = specularChance(surface.albedo, surface.metallic)
	local scatteredDir: vector? = nil

	if math.random() < chance then
		local v = safeUnit(-rIn.direction)

		if v then
			for _ = 1, 8 do
				local h = sampleGgxNormal(surface.normal, alphaFor(surface.roughness))
				local l = Vec3.reflect(-v, h)

				if vector.dot(l, surface.normal) > EPS and vector.dot(l, rec.normal) > EPS then
					scatteredDir = vector.normalize(l)
					break
				end
			end
		end
	end

	if not scatteredDir then
		scatteredDir = vector.normalize(ONB.new(surface.normal):transform(Vec3.randomCosineDirection()))
	end

	local direction = scatteredDir :: vector
	local pdf = mixturePdf(self, rIn, rec, direction, surface)
	if pdf <= EPS then
		return nil, nil
	end

	local attenuation = evaluateSurface(self, rIn, rec, direction, surface) / pdf
	if maxComponent(attenuation) <= 0 then
		return nil, nil
	end

	return attenuation, Ray.new(rec.p, direction, rIn.time, rIn.wavelength)
end

function PBR.probability(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord)
	return setmetatable({ material = self, rIn = rIn, rec = rec, surface = surfaceAt(self, rec) }, PBRPdf)
end

function PBR.evalDirect(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord, wi: Vec3.Vec3): vector
	return evaluateSurface(self, rIn, rec, wi, surfaceAt(self, rec))
end

function PBR.textureAlbedo(self: PBR, rec: hittable.HitRecord): vector
	return self.texture:value(rec.u, rec.v, rec.p)
end

function PBR.surfaceAlbedo(self: PBR, rec: hittable.HitRecord): vector
	return self:textureAlbedo(rec)
end

function PBR.specularBounce(self: PBR, rIn: Ray.Ray, rec: hittable.HitRecord): Ray.Ray?
	local surface = surfaceAt(self, rec)
	if surface.metallic < 0.9 or surface.roughness > 0.05 then
		return nil
	end

	local reflected = Vec3.reflect(Vec3.unitVector(rIn.direction), surface.normal)
	if vector.dot(reflected, rec.normal) <= 0 then
		return nil
	end

	return Ray.new(rec.p, reflected, rIn.time, rIn.wavelength)
end

function PBRPdf.value(
	self: { material: PBR, rIn: Ray.Ray, rec: hittable.HitRecord, surface: Surface },
	direction: vector
): number
	return mixturePdf(self.material, self.rIn, self.rec, direction, self.surface)
end

return PBR
