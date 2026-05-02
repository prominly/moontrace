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
	local invD = vector.one / r.direction

	local t0 = (self.min - r.origin) * invD
	local t1 = (self.max - r.origin) * invD

	local tNear = vector.min(t0, t1)
	local tFar = vector.max(t0, t1)

	local tEnter = math.max(tMin, tNear.x, tNear.y, tNear.z)
	local tExit = math.min(tMax, tFar.x, tFar.y, tFar.z)

	return tExit > tEnter
end

return AABB
