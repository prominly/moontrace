local Ray = require("./ray")
local AABB = require("./aabb")
local hittable = require("./hittable")

local BVH = {}
BVH.__index = BVH

export type BVH = typeof(setmetatable({} :: { left: hittable.Hittable, right: hittable.Hittable, box: AABB.AABB }, BVH))

local function longestAxis(box: AABB.AABB): number
	local ex = box.max.x - box.min.x
	local ey = box.max.y - box.min.y
	local ez = box.max.z - box.min.z

	if ex > ey and ex > ez then
		return 0
	end

	if ey >= ez then
		return 1
	end

	return 2
end

local function compareByAxis(axis: number)
	if axis == 0 then
		return function(a: hittable.Hittable, b: hittable.Hittable)
			return a:boundingBox().min.x < b:boundingBox().min.x
		end
	elseif axis == 1 then
		return function(a: hittable.Hittable, b: hittable.Hittable)
			return a:boundingBox().min.y < b:boundingBox().min.y
		end
	else
		return function(a: hittable.Hittable, b: hittable.Hittable)
			return a:boundingBox().min.z < b:boundingBox().min.z
		end
	end
end

function BVH.build(objects: { hittable.Hittable }): hittable.Hittable
	local n = #objects

	if n == 1 then
		return objects[1]
	end

	local box = objects[1]:boundingBox()
	for i = 2, n do
		box = AABB.surrounding(box, objects[i]:boundingBox())
	end

	if n == 2 then
		return setmetatable({ left = objects[1], right = objects[2], box = box }, BVH) :: any
	end

	table.sort(objects, compareByAxis(longestAxis(box)))

	local mid = math.floor(n / 2)
	local leftObjs: { hittable.Hittable } = {}

	for i = 1, mid do
		leftObjs[i] = objects[i]
	end

	local rightObjs: { hittable.Hittable } = {}
	for i = mid + 1, n do
		rightObjs[i - mid] = objects[i]
	end

	return setmetatable({
		left = BVH.build(leftObjs),
		right = BVH.build(rightObjs),
		box = box,
	}, BVH) :: any
end

function BVH.hit(self: BVH, r: Ray.Ray, tMin: number, tMax: number): hittable.HitRecord?
	if not AABB.hit(self.box, r, tMin, tMax) then
		return nil
	end

	local leftRec = self.left:hit(r, tMin, tMax)
	local newMax = if leftRec then leftRec.t else tMax
	local rightRec = self.right:hit(r, tMin, newMax)

	return rightRec or leftRec
end

function BVH.boundingBox(self: BVH): AABB.AABB
	return self.box
end

return BVH
