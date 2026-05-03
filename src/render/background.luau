--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")
local Ray = require("../core/ray")

local background = {}

export type Background = (r: Ray.Ray) -> vector

function background.gradientSky(r: Ray.Ray): vector
	local unitDir = Vec3.unitVector(r.direction)
	local a = 0.5 * (unitDir.y + 1.0)

	return (1.0 - a) * vector.one + a * vector.create(0.5, 0.7, 1.0)
end

function background.solid(color: vector): Background
	return function(_r: Ray.Ray): vector
		return color
	end
end

function background.sunset(r: Ray.Ray): vector
	local unitDir = Vec3.unitVector(r.direction)
	local t = 0.5 * (unitDir.y + 1.0)
	local horizon = vector.create(0.98, 0.52, 0.28)
	local zenith = vector.create(0.10, 0.08, 0.28)

	return (1 - t) * horizon + t * zenith
end

return background
