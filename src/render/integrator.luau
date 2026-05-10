--!strict
--!optimize 2
--!native

local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local lights = require("../lights")
local probabilityMod = require("./probability")
local backgroundMod = require("./background")
local spectrum = require("./spectrum")

local integrator = {}

function integrator.rayColor(
	r: Ray.Ray,
	maxDepth: number,
	world: hittable.Hittable,
	background: backgroundMod.Background,
	sceneLights: { lights.Light }?,
	samplers: hittable.Hittable?
): vector
	local accum = vector.zero
	local attenuation = if r.wavelength > 0 then spectrum.wavelengthToRgb(r.wavelength) else vector.one
	local ray = r

	for depth = 1, maxDepth do
		local rec = world:hit(ray, 0.001, math.huge)

		if not rec then
			return accum + attenuation * background(ray)
		end

		if rec.material.emitted then
			accum += attenuation * (rec.material :: any):emitted(rec)
		end

		if sceneLights and rec.material.evalDirect and math.max(attenuation.x, attenuation.y, attenuation.z) > 0.01 then
			for _, light in sceneLights do
				local s = light:sample(rec.p)
				local shadow = Ray.new(rec.p, s.dir, ray.time, ray.wavelength)

				if not world:hit(shadow, 0.001, s.distance - 0.001) then
					local f = (rec.material :: any):evalDirect(ray, rec, s.dir)
					accum += attenuation * f * s.emitted / s.probability
				end
			end
		end

		local att, scattered = rec.material:scatter(ray, rec)

		if not att or not scattered then
			return accum
		end

		if samplers and rec.material.probability then
			local matProbability = (rec.material :: any):probability(ray, rec)
			local lightProbability = probabilityMod.Hittable.new(samplers, rec.p)
			local mixed = probabilityMod.Mixture.new(lightProbability, matProbability)

			local newDir = mixed:generate()
			scattered = Ray.new(rec.p, newDir, ray.time, ray.wavelength)

			local samplingDensity = mixed:value(newDir)
			local brdfDensity = matProbability:value(newDir)

			if samplingDensity <= 0 or brdfDensity <= 0 then
				return accum
			end

			attenuation *= att * brdfDensity / samplingDensity
		else
			attenuation *= att
		end

		if depth >= 8 then
			local survive = math.min(0.95, math.max(attenuation.x, attenuation.y, attenuation.z))
			if math.random() > survive then
				return accum
			end
			attenuation /= survive
		end

		ray = scattered
	end

	return accum
end

function integrator.firstHitGBuffer(r: Ray.Ray, world: hittable.Hittable): (vector, vector)
	local ray = r
	local lastAlbedo = vector.one
	local lastNormal = vector.zero

	for _ = 1, 6 do
		local rec = world:hit(ray, 0.001, math.huge)
		if not rec then
			return lastAlbedo, lastNormal
		end

		local material = rec.material
		lastNormal = rec.normal
		lastAlbedo = if material.surfaceAlbedo then (material :: any):surfaceAlbedo(rec) else vector.one

		if not material.specularBounce then
			return lastAlbedo, lastNormal
		end

		local nextRay = (material :: any):specularBounce(ray, rec)
		if not nextRay then
			return lastAlbedo, lastNormal
		end

		ray = nextRay
	end

	return lastAlbedo, lastNormal
end

return integrator
