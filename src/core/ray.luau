local Vec3 = require("../math/vec3")

local Ray = {}
Ray.__index = Ray

export type Ray = typeof(setmetatable(
	{} :: { origin: Vec3.Point3, direction: Vec3.Vec3, invDirection: Vec3.Vec3, time: number },
	Ray
))

function Ray.new(origin: Vec3.Point3, direction: Vec3.Vec3, time: number?): Ray
	return setmetatable({
		origin = origin,
		direction = direction,
		invDirection = vector.one / direction,
		time = time or 0,
	}, Ray)
end

function Ray.at(r: Ray, t: number): Vec3.Point3
	return r.origin + t * r.direction
end

return Ray
