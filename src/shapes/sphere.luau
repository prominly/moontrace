local Vec3 = require("../math/vec3")
local ONB = require("../math/onb")
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
		radiusSquared: number,
		material: hittable.Material,
	},
	Sphere
))

function Sphere.new(center: Vec3.Point3, radius: number, material: hittable.Material): hittable.Hittable
	local r = math.max(0, radius)
	return setmetatable({
		centerStart = center,
		centerVec = vector.zero,
		radius = r,
		radiusSquared = r * r,
		material = material,
	}, Sphere) :: any
end

function Sphere.newMoving(
	center0: Vec3.Point3,
	center1: Vec3.Point3,
	radius: number,
	material: hittable.Material
): hittable.Hittable
	local r = math.max(0, radius)
	return setmetatable({
		centerStart = center0,
		centerVec = center1 - center0,
		radius = r,
		radiusSquared = r * r,
		material = material,
	}, Sphere) :: any
end

function Sphere.hit(self: Sphere, r: Ray.Ray, tMin: number, tMax: number): hittable.HitRecord?
	local center = self.centerStart + r.time * self.centerVec
	local oc = center - r.origin
	local a = Vec3.lengthSquared(r.direction)
	local h = Vec3.dot(r.direction, oc)
	local c = Vec3.lengthSquared(oc) - self.radiusSquared
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

local function randomToSphere(radius: number, distSquared: number): vector
	local r1 = math.random()
	local r2 = math.random()
	local z = 1 + r2 * (math.sqrt(1 - radius * radius / distSquared) - 1)
	local sinTheta = math.sqrt(math.max(0, 1 - z * z))
	local phi = 2 * math.pi * r1

	return vector.create(math.cos(phi) * sinTheta, math.sin(phi) * sinTheta, z)
end

function Sphere.probabilityValue(self: Sphere, origin: Vec3.Point3, direction: Vec3.Vec3): number
	if not self:hit(Ray.new(origin, direction, 0), 0.001, math.huge) then
		return 0
	end

	local toCenter = self.centerStart - origin
	local distSquared = Vec3.lengthSquared(toCenter)

	if distSquared <= self.radiusSquared then
		return 0
	end

	local cosThetaMax = math.sqrt(1 - self.radiusSquared / distSquared)

	return 1 / (2 * math.pi * (1 - cosThetaMax))
end

function Sphere.random(self: Sphere, origin: Vec3.Point3): Vec3.Vec3
	local toCenter = self.centerStart - origin
	local distSquared = Vec3.lengthSquared(toCenter)

	if distSquared <= self.radiusSquared then
		return Vec3.randomUnitVector()
	end

	return ONB.new(toCenter):transform(randomToSphere(self.radius, distSquared))
end

return Sphere
