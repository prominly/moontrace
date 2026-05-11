--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")
local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local spectrum = require("../render/spectrum")

local Dielectric = {}
Dielectric.__index = Dielectric

export type Dielectric = typeof(setmetatable(
	{} :: {
		refractionIndex: number,
		dispersion: number,
		sigma: vector,
		absorbs: boolean,
	},
	Dielectric
))

local TINT_FLOOR = 1e-6

function Dielectric.new(
	refractionIndex: number,
	dispersion: number?,
	tint: vector?,
	absorption: number?
): hittable.Material
	local t = tint or vector.one
	local a = absorption or 0
	local absorbs = a > 0 and (t.x < 1 or t.y < 1 or t.z < 1)
	local sigma = vector.zero

	if absorbs then
		sigma = vector.create(
			-math.log(math.max(t.x, TINT_FLOOR)),
			-math.log(math.max(t.y, TINT_FLOOR)),
			-math.log(math.max(t.z, TINT_FLOOR))
		) * a
	end

	return setmetatable({
		refractionIndex = refractionIndex,
		dispersion = dispersion or 0,
		sigma = sigma,
		absorbs = absorbs,
	}, Dielectric) :: any
end

local function indexFor(self: Dielectric, wavelength: number): number
	if self.dispersion ~= 0 and wavelength > 0 then
		return spectrum.cauchyIor(wavelength, self.refractionIndex, self.dispersion)
	end

	return self.refractionIndex
end

local function reflectance(cosine: number, ri: number): number
	local r0 = (1 - ri) / (1 + ri)
	r0 = r0 * r0

	return r0 + (1 - r0) * math.pow(1 - cosine, 5)
end

function Dielectric.scatter(self: Dielectric, rIn: Ray.Ray, rec: hittable.HitRecord): (vector?, Ray.Ray?)
	local n = indexFor(self, rIn.wavelength)
	local ri = if rec.frontFace then (1.0 / n) else n
	local unitDir = Vec3.unitVector(rIn.direction)
	local cosTheta = math.min(Vec3.dot(-unitDir, rec.normal), 1.0)
	local sinTheta = math.sqrt(1.0 - cosTheta * cosTheta)

	local direction
	if ri * sinTheta > 1.0 or reflectance(cosTheta, ri) > math.random() then
		direction = Vec3.reflect(unitDir, rec.normal)
	else
		direction = Vec3.refract(unitDir, rec.normal, ri)
	end

	local attenuation = vector.one
	if self.absorbs and not rec.frontFace then
		local distance = rec.t * vector.magnitude(rIn.direction)
		local s = self.sigma

		attenuation = vector.create(math.exp(-s.x * distance), math.exp(-s.y * distance), math.exp(-s.z * distance))
	end

	return attenuation, Ray.new(rec.p, direction, rIn.time, rIn.wavelength)
end

function Dielectric.surfaceAlbedo(_self: Dielectric, _rec: hittable.HitRecord): vector
	return vector.one
end

function Dielectric.specularBounce(self: Dielectric, rIn: Ray.Ray, rec: hittable.HitRecord): Ray.Ray?
	local n = indexFor(self, rIn.wavelength)
	local ri = if rec.frontFace then 1.0 / n else n
	local unitDir = Vec3.unitVector(rIn.direction)
	local cosTheta = math.min(Vec3.dot(-unitDir, rec.normal), 1.0)
	local sinTheta = math.sqrt(1.0 - cosTheta * cosTheta)

	local direction
	if ri * sinTheta > 1.0 then
		direction = Vec3.reflect(unitDir, rec.normal)
	else
		direction = Vec3.refract(unitDir, rec.normal, ri)
	end

	return Ray.new(rec.p, direction, rIn.time, rIn.wavelength)
end

return Dielectric
