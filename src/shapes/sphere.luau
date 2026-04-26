local Vec3 = require("../math/vec3")
local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local AABB = require("../core/aabb")

local Sphere = {}
Sphere.__index = Sphere

export type Sphere = typeof(setmetatable(
	{} :: { center: Vec3.Point3, radius: number, material: hittable.Material },
	Sphere
))

function Sphere.new(center: Vec3.Point3, radius: number, material: hittable.Material): hittable.Hittable
	return setmetatable({ center = center, radius = math.max(0, radius), material = material }, Sphere) :: any
end

function Sphere.hit(self: Sphere, r: Ray.Ray, tMin: number, tMax: number): hittable.HitRecord?
	local oc = self.center - r.origin
	local a = Vec3.lengthSquared(r.direction)
	local h = Vec3.dot(r.direction, oc)
	local c = Vec3.lengthSquared(oc) - self.radius * self.radius
	local discriminant = h * h - a * c

	if discriminant < 0 then
		return nil
	end

	local sqrtd = math.sqrt(discriminant)
	local root = (h - sqrtd) / a

	if root <= tMin or root >= tMax then
		root = (h + sqrtd) / a

		if root <= tMin or root >= tMax then
			return nil
		end
	end

	local p = Ray.at(r, root)
	local outwardNormal = (p - self.center) / self.radius

	return hittable.makeHitRecord(r, root, p, outwardNormal, self.material)
end

function Sphere.boundingBox(self: Sphere): AABB.AABB
	local r = vector.create(self.radius, self.radius, self.radius)

	return AABB.new(self.center - r, self.center + r)
end

return Sphere
