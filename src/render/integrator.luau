local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local backgroundMod = require("./background")

local integrator = {}

function integrator.rayColor(
	r: Ray.Ray,
	maxDepth: number,
	world: hittable.Hittable,
	background: backgroundMod.Background
): vector
	local attenuation = vector.one
	local ray = r

	for _ = 1, maxDepth do
		local rec = world:hit(ray, 0.001, math.huge)

		if not rec then
			return attenuation * background(ray)
		end

		local att, scattered = rec.mat:scatter(ray, rec)

		if not att or not scattered then
			return vector.zero
		end

		attenuation = attenuation * att
		ray = scattered
	end

	return vector.zero
end

return integrator
