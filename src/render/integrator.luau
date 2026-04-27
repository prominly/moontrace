local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local lights = require("../lights")
local backgroundMod = require("./background")

local integrator = {}

function integrator.rayColor(
	r: Ray.Ray,
	maxDepth: number,
	world: hittable.Hittable,
	background: backgroundMod.Background,
	sceneLights: { lights.Light }?
): vector
	local accum = vector.zero
	local attenuation = vector.one
	local ray = r

	for _ = 1, maxDepth do
		local rec = world:hit(ray, 0.001, math.huge)

		if not rec then
			return accum + attenuation * background(ray)
		end

		if sceneLights and rec.material.evalDirect then
			for _, light in sceneLights do
				local s = light:sample(rec.p)
				local shadow = Ray.new(rec.p, s.dir, ray.time)

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

		attenuation *= att
		ray = scattered
	end

	return accum
end

return integrator
