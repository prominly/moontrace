local Ray = require("./ray")

local AABB = {}
AABB.__index = AABB

export type AABB = typeof(setmetatable({} :: { min: vector, max: vector }, AABB))

function AABB.new(min: vector, max: vector): AABB
	return setmetatable({ min = min, max = max }, AABB)
end

function AABB.surrounding(a: AABB, b: AABB): AABB
	return AABB.new(
		vector.create(math.min(a.min.x, b.min.x), math.min(a.min.y, b.min.y), math.min(a.min.z, b.min.z)),
		vector.create(math.max(a.max.x, b.max.x), math.max(a.max.y, b.max.y), math.max(a.max.z, b.max.z))
	)
end

function AABB.hit(self: AABB, r: Ray.Ray, tMin: number, tMax: number): boolean
	local ox, oy, oz = r.origin.x, r.origin.y, r.origin.z
	local dx, dy, dz = r.direction.x, r.direction.y, r.direction.z

	local invD = 1 / dx
	local t0 = (self.min.x - ox) * invD
	local t1 = (self.max.x - ox) * invD

	if invD < 0 then
		t0, t1 = t1, t0
	end

	if t0 > tMin then
		tMin = t0
	end

	if t1 < tMax then
		tMax = t1
	end

	if tMax <= tMin then
		return false
	end

	invD = 1 / dy
	t0 = (self.min.y - oy) * invD
	t1 = (self.max.y - oy) * invD

	if invD < 0 then
		t0, t1 = t1, t0
	end

	if t0 > tMin then
		tMin = t0
	end

	if t1 < tMax then
		tMax = t1
	end

	if tMax <= tMin then
		return false
	end

	invD = 1 / dz
	t0 = (self.min.z - oz) * invD
	t1 = (self.max.z - oz) * invD

	if invD < 0 then
		t0, t1 = t1, t0
	end

	if t0 > tMin then
		tMin = t0
	end

	if t1 < tMax then
		tMax = t1
	end

	return tMax > tMin
end

return AABB
