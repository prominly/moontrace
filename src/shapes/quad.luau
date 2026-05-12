--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")
local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local AABB = require("../core/aabb")

local Quad = {}
Quad.__index = Quad

export type Quad = typeof(setmetatable(
	{} :: {
		Q: Vec3.Point3,
		u: Vec3.Vec3,
		v: Vec3.Vec3,
		w: Vec3.Vec3,
		normal: Vec3.Vec3,
		D: number,
		material: hittable.Material,
		bbox: AABB.AABB,
	},
	Quad
))

local PAD = 0.0001

local function paddedBox(p1: vector, p2: vector, p3: vector, p4: vector): AABB.AABB
	local mnx = math.min(p1.x, p2.x, p3.x, p4.x)
	local mny = math.min(p1.y, p2.y, p3.y, p4.y)
	local mnz = math.min(p1.z, p2.z, p3.z, p4.z)
	local mxx = math.max(p1.x, p2.x, p3.x, p4.x)
	local mxy = math.max(p1.y, p2.y, p3.y, p4.y)
	local mxz = math.max(p1.z, p2.z, p3.z, p4.z)

	if mxx - mnx < PAD then
		mnx -= PAD * 0.5
		mxx += PAD * 0.5
	end
	if mxy - mny < PAD then
		mny -= PAD * 0.5
		mxy += PAD * 0.5
	end
	if mxz - mnz < PAD then
		mnz -= PAD * 0.5
		mxz += PAD * 0.5
	end

	return AABB.new(vector.create(mnx, mny, mnz), vector.create(mxx, mxy, mxz))
end

function Quad.new(Q: Vec3.Point3, u: Vec3.Vec3, v: Vec3.Vec3, material: hittable.Material): hittable.Hittable
	local n = vector.cross(u, v)
	local normal = vector.normalize(n)
	local w = n / vector.dot(n, n)
	local D = vector.dot(normal, Q)

	return setmetatable({
		Q = Q,
		u = u,
		v = v,
		w = w,
		normal = normal,
		D = D,
		material = material,
		bbox = paddedBox(Q, Q + u, Q + v, Q + u + v),
	}, Quad) :: any
end

function Quad.hit(self: Quad, r: Ray.Ray, tMin: number, tMax: number): hittable.HitRecord?
	local denom = vector.dot(self.normal, r.direction)

	if math.abs(denom) < 1e-8 then
		return nil
	end

	local t = (self.D - vector.dot(self.normal, r.origin)) / denom

	if t <= tMin or t >= tMax then
		return nil
	end

	local p = Ray.at(r, t)
	local planar = p - self.Q
	local alpha = vector.dot(self.w, vector.cross(planar, self.v))
	local beta = vector.dot(self.w, vector.cross(self.u, planar))

	if alpha < 0 or alpha > 1 or beta < 0 or beta > 1 then
		return nil
	end

	local tangent = vector.normalize(self.u)
	local bitangent = vector.normalize(vector.cross(self.normal, tangent))

	return hittable.makeHitRecord(r, t, p, self.normal, self.material, alpha, beta, tangent, bitangent)
end

function Quad.boundingBox(self: Quad): AABB.AABB
	return self.bbox
end

return Quad
