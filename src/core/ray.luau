local Vec3 = require("../math/vec3")

local Ray = {}
Ray.__index = Ray

export type Ray = typeof(setmetatable({} :: { origin: Vec3.Point3, direction: Vec3.Vec3 }, Ray))

function Ray.new(origin: Vec3.Point3, direction: Vec3.Vec3): Ray
	return setmetatable({ origin = origin, direction = direction }, Ray)
end

function Ray.at(r: Ray, t: number): Vec3.Point3
	return r.origin + t * r.direction
end

return Ray
