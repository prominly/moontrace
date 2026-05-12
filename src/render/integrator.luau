--!strict
--!optimize 2
--!native

local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local lights = require("../lights")
local backgroundMod = require("./background")
local environmentMod = require("./environment")
local spectrum = require("./spectrum")

local integrator = {}

local function maxComponent(v: vector): number
	return math.max(v.x, v.y, v.z)
end

local function powerHeuristic(pdfA: number, pdfB: number): number
	local a2 = pdfA * pdfA
	local b2 = pdfB * pdfB
	local sum = a2 + b2

	if sum <= 0 then
		return 0
	end

	return a2 / sum
end

local function lightPdf(
	sceneLights: { lights.Light }?,
	samplers: hittable.Hittable?,
	sceneEnvironment: environmentMod.Environment?,
	origin: vector,
	direction: vector
): number
	local pdf = 0

	if samplers and samplers.probabilityValue then
		pdf += (samplers :: any):probabilityValue(origin, direction)
	end

	if sceneLights then
		for _, light in sceneLights do
			if light.probabilityValue then
				pdf += (light :: any):probabilityValue(origin, direction)
			end
		end
	end

	if sceneEnvironment then
		pdf += sceneEnvironment:probabilityValue(direction)
	end

	return pdf
end

local function analyticLightHit(
	sceneLights: { lights.Light }?,
	origin: vector,
	direction: vector
): (vector, number, number)
	if not sceneLights then
		return vector.zero, math.huge, 0
	end

	local closestEmission = vector.zero
	local closestDistance = math.huge
	local closestPdf = 0

	for _, light in sceneLights do
		if light.hitEmission then
			local emitted, distance, pdf = (light :: any):hitEmission(origin, direction)

			if distance < closestDistance and maxComponent(emitted) > 0 then
				closestEmission = emitted
				closestDistance = distance
				closestPdf = pdf
			end
		end
	end

	return closestEmission, closestDistance, closestPdf
end

local function addDirectLighting(
	ray: Ray.Ray,
	rec: hittable.HitRecord,
	attenuation: vector,
	world: hittable.Hittable,
	sceneLights: { lights.Light }?,
	samplers: hittable.Hittable?,
	sceneEnvironment: environmentMod.Environment?
): vector
	if not rec.material.evalDirect or not rec.material.probability or maxComponent(attenuation) <= 0.01 then
		return vector.zero
	end

	local accum = vector.zero
	local matProbability = (rec.material :: any):probability(ray, rec)

	if sceneLights then
		for _, light in sceneLights do
			local sample = light:sample(rec.p)

			if sample.probability <= 0 or maxComponent(sample.emitted) <= 0 then
				continue
			end

			local shadow = Ray.new(rec.p, sample.dir, ray.time, ray.wavelength)

			if world:hit(shadow, 0.001, sample.distance - 0.001) then
				continue
			end

			local brdfDensity = matProbability:value(sample.dir)
			if brdfDensity <= 0 then
				continue
			end

			local weight = 1
			if not sample.delta then
				weight = powerHeuristic(sample.probability, brdfDensity)
			end

			local f = (rec.material :: any):evalDirect(ray, rec, sample.dir)
			accum += attenuation * f * sample.emitted * weight / sample.probability
		end
	end

	if samplers and samplers.random and samplers.probabilityValue then
		local dir = (samplers :: any):random(rec.p)
		local pdf = (samplers :: any):probabilityValue(rec.p, dir)

		if pdf > 0 then
			local shadow = Ray.new(rec.p, dir, ray.time, ray.wavelength)
			local lightRec = world:hit(shadow, 0.001, math.huge)

			if lightRec and lightRec.material.emitted then
				local emitted = (lightRec.material :: any):emitted(lightRec)
				local brdfDensity = matProbability:value(dir)

				if brdfDensity > 0 and maxComponent(emitted) > 0 then
					local weight = powerHeuristic(pdf, brdfDensity)
					local f = (rec.material :: any):evalDirect(ray, rec, dir)
					accum += attenuation * f * emitted * weight / pdf
				end
			end
		end
	end

	if sceneEnvironment then
		local sample = sceneEnvironment:sample()

		if sample.probability > 0 and maxComponent(sample.emitted) > 0 then
			local shadow = Ray.new(rec.p, sample.dir, ray.time, ray.wavelength)

			if not world:hit(shadow, 0.001, math.huge) then
				local brdfDensity = matProbability:value(sample.dir)

				if brdfDensity > 0 then
					local weight = powerHeuristic(sample.probability, brdfDensity)
					local f = (rec.material :: any):evalDirect(ray, rec, sample.dir)
					accum += attenuation * f * sample.emitted * weight / sample.probability
				end
			end
		end
	end

	return accum
end

function integrator.rayColor(
	r: Ray.Ray,
	maxDepth: number,
	world: hittable.Hittable,
	background: backgroundMod.Background,
	sceneLights: { lights.Light }?,
	samplers: hittable.Hittable?,
	sceneEnvironment: environmentMod.Environment?
): vector
	local accum = vector.zero
	local attenuation = vector.one
	local ray = r
	local previousBsdfPdf = 0
	local previousLightPdf = 0

	if r.wavelength > 0 then
		attenuation = spectrum.wavelengthToRgb(r.wavelength)
	end

	for depth = 1, maxDepth do
		local analyticEmission = vector.zero
		local analyticDistance = math.huge
		local analyticPdf = 0

		if depth > 1 then
			analyticEmission, analyticDistance, analyticPdf = analyticLightHit(sceneLights, ray.origin, ray.direction)
		end

		local rec = world:hit(ray, 0.001, analyticDistance - 0.001)

		if not rec then
			if maxComponent(analyticEmission) > 0 then
				local weight = powerHeuristic(previousBsdfPdf, analyticPdf)
				accum += attenuation * analyticEmission * weight

				return accum
			end

			local emitted = if sceneEnvironment then sceneEnvironment:value(ray) else background(ray)
			local weight = 1

			if sceneEnvironment and depth > 1 and previousBsdfPdf > 0 then
				weight = powerHeuristic(previousBsdfPdf, previousLightPdf)
			end

			return accum + attenuation * emitted * weight
		end

		if rec.material.emitted then
			local emitted = (rec.material :: any):emitted(rec)
			local weight = 1

			if depth > 1 and previousBsdfPdf > 0 then
				weight = powerHeuristic(previousBsdfPdf, previousLightPdf)
			end

			accum += attenuation * emitted * weight
		end

		accum += addDirectLighting(ray, rec, attenuation, world, sceneLights, samplers, sceneEnvironment)

		local att, scattered = rec.material:scatter(ray, rec)

		if not att or not scattered then
			return accum
		end

		previousBsdfPdf = 0
		previousLightPdf = 0

		if rec.material.probability then
			local matProbability = (rec.material :: any):probability(ray, rec)
			previousBsdfPdf = matProbability:value(scattered.direction)

			if previousBsdfPdf <= 0 then
				return accum
			end

			previousLightPdf = lightPdf(sceneLights, samplers, sceneEnvironment, rec.p, scattered.direction)
		end

		attenuation *= att

		if depth >= 8 then
			local survive = math.min(0.95, maxComponent(attenuation))
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
		lastAlbedo = vector.one
		if material.surfaceAlbedo then
			lastAlbedo = (material :: any):surfaceAlbedo(rec)
		end

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
