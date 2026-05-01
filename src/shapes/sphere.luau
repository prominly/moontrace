local Vec3 = require("../math/vec3")
local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local AABB = require("../core/aabb")

local Sphere = {}
Sphere.__index = Sphere

export type Sphere = typeof(setmetatable(
	{} :: {
		centerStart: Vec3.Point3,
		centerVec: Vec3.Vec3,
		radius: number,
		material: hittable.Material,
	},
	Sphere
))

function Sphere.new(center: Vec3.Point3, radius: number, material: hittable.Material): hittable.Hittable
	return setmetatable({
		centerStart = center,
		centerVec = vector.zero,
		radius = math.max(0, radius),
		material = material,
	}, Sphere) :: any
end

function Sphere.newMoving(
	center0: Vec3.Point3,
	center1: Vec3.Point3,
	radius: number,
	material: hittable.Material
): hittable.Hittable
	return setmetatable({
		centerStart = center0,
		centerVec = center1 - center0,
		radius = math.max(0, radius),
		material = material,
	}, Sphere) :: any
end

function Sphere.hit(self: Sphere, r: Ray.Ray, tMin: number, tMax: number): hittable.HitRecord?
	local center = self.centerStart + r.time * self.centerVec
	local oc = center - r.origin
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
	local outwardNormal = (p - center) / self.radius

	local theta = math.acos(math.clamp(-outwardNormal.y, -1, 1))
	local phi = math.atan2(-outwardNormal.z, outwardNormal.x) + math.pi
	local u = phi / (2 * math.pi)
	local v = theta / math.pi

	return hittable.makeHitRecord(r, root, p, outwardNormal, self.material, u, v)
end

function Sphere.boundingBox(self: Sphere): AABB.AABB
	local r = vector.create(self.radius, self.radius, self.radius)
	local box0 = AABB.new(self.centerStart - r, self.centerStart + r)
	local centerEnd = self.centerStart + self.centerVec
	local box1 = AABB.new(centerEnd - r, centerEnd + r)

	return AABB.surrounding(box0, box1)
end

return Sphere
