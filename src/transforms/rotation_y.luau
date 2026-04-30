local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local AABB = require("../core/aabb")

local RotationY = {}
RotationY.__index = RotationY

export type RotationY = typeof(setmetatable(
	{} :: { object: hittable.Hittable, sinTheta: number, cosTheta: number, bbox: AABB.AABB },
	RotationY
))

function RotationY.new(object: hittable.Hittable, angleDegrees: number): hittable.Hittable
	local rad = math.rad(angleDegrees)
	local sinTheta = math.sin(rad)
	local cosTheta = math.cos(rad)
	local inner = object:boundingBox()

	local mnx, mny, mnz = math.huge, math.huge, math.huge
	local mxx, mxy, mxz = -math.huge, -math.huge, -math.huge

	for i = 0, 1 do
		for j = 0, 1 do
			for k = 0, 1 do
				local x = if i == 1 then inner.max.x else inner.min.x
				local y = if j == 1 then inner.max.y else inner.min.y
				local z = if k == 1 then inner.max.z else inner.min.z

				local newx = cosTheta * x + sinTheta * z
				local newz = -sinTheta * x + cosTheta * z

				if newx < mnx then
					mnx = newx
				end

				if newx > mxx then
					mxx = newx
				end

				if y < mny then
					mny = y
				end

				if y > mxy then
					mxy = y
				end

				if newz < mnz then
					mnz = newz
				end

				if newz > mxz then
					mxz = newz
				end
			end
		end
	end

	return setmetatable({
		object = object,
		sinTheta = sinTheta,
		cosTheta = cosTheta,
		bbox = AABB.new(vector.create(mnx, mny, mnz), vector.create(mxx, mxy, mxz)),
	}, RotationY) :: any
end

function RotationY.hit(self: RotationY, r: Ray.Ray, tMin: number, tMax: number): hittable.HitRecord?
	local s = self.sinTheta
	local c = self.cosTheta

	local ox, oy, oz = r.origin.x, r.origin.y, r.origin.z
	local dx, dy, dz = r.direction.x, r.direction.y, r.direction.z

	local origin = vector.create(c * ox - s * oz, oy, s * ox + c * oz)
	local direction = vector.create(c * dx - s * dz, dy, s * dx + c * dz)

	local rec = self.object:hit(Ray.new(origin, direction, r.time), tMin, tMax)

	if not rec then
		return nil
	end

	local px, py, pz = rec.p.x, rec.p.y, rec.p.z
	local nx, ny, nz = rec.normal.x, rec.normal.y, rec.normal.z

	rec.p = vector.create(c * px + s * pz, py, -s * px + c * pz)
	rec.normal = vector.create(c * nx + s * nz, ny, -s * nx + c * nz)

	return rec
end

function RotationY.boundingBox(self: RotationY): AABB.AABB
	return self.bbox
end

return RotationY
