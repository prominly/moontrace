local Vec3 = require("../math/vec3")
local Ray = require("./ray")
local AABB = require("./aabb")

export type Material = {
	scatter: (any, rIn: Ray.Ray, rec: HitRecord) -> (vector?, Ray.Ray?),
}

export type HitRecord = {
	p: Vec3.Point3,
	normal: Vec3.Vec3,
	t: number,
	frontFace: boolean,
	mat: Material,
}

export type Hittable = {
	hit: (any, r: Ray.Ray, tMin: number, tMax: number) -> HitRecord?,
	boundingBox: (any) -> AABB.AABB,
}

local hittable = {}

function hittable.makeHitRecord(
	r: Ray.Ray,
	t: number,
	p: Vec3.Point3,
	outwardNormal: Vec3.Vec3,
	mat: Material
): HitRecord
	local frontFace = Vec3.dot(r.direction, outwardNormal) < 0

	return {
		t = t,
		p = p,
		normal = if frontFace then outwardNormal else -outwardNormal,
		frontFace = frontFace,
		mat = mat,
	}
end

return hittable
