local Ray = require("./ray")
local AABB = require("./aabb")
local hittable = require("./hittable")

local BVH = {}
BVH.__index = BVH

export type BVH = typeof(setmetatable(
	{} :: {
		left: hittable.Hittable,
		right: hittable.Hittable,
		box: AABB.AABB,
		boxMin: vector,
		boxMax: vector,
	},
	BVH
))

type Entry = { obj: hittable.Hittable, box: AABB.AABB }

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
		return function(a: Entry, b: Entry)
			return a.box.min.x < b.box.min.x
		end
	elseif axis == 1 then
		return function(a: Entry, b: Entry)
			return a.box.min.y < b.box.min.y
		end
	else
		return function(a: Entry, b: Entry)
			return a.box.min.z < b.box.min.z
		end
	end
end

local function buildEntries(entries: { Entry }): hittable.Hittable
	local n = #entries

	if n == 1 then
		return entries[1].obj
	end

	local box = entries[1].box
	for i = 2, n do
		box = AABB.surrounding(box, entries[i].box)
	end

	if n == 2 then
		return setmetatable({
			left = entries[1].obj,
			right = entries[2].obj,
			box = box,
			boxMin = box.min,
			boxMax = box.max,
		}, BVH) :: any
	end

	table.sort(entries, compareByAxis(longestAxis(box)))

	local mid = math.floor(n / 2)
	local leftEntries: { Entry } = {}

	for i = 1, mid do
		leftEntries[i] = entries[i]
	end

	local rightEntries: { Entry } = {}
	for i = mid + 1, n do
		rightEntries[i - mid] = entries[i]
	end

	return setmetatable({
		left = buildEntries(leftEntries),
		right = buildEntries(rightEntries),
		box = box,
		boxMin = box.min,
		boxMax = box.max,
	}, BVH) :: any
end

function BVH.build(objects: { hittable.Hittable }): hittable.Hittable
	local entries: { Entry } = {}

	for i, obj in objects do
		entries[i] = { obj = obj, box = obj:boundingBox() }
	end

	return buildEntries(entries)
end

function BVH.hit(self: BVH, r: Ray.Ray, tMin: number, tMax: number): hittable.HitRecord?
	-- AABB hit
	local origin = r.origin

	local invD = r.invDirection
	local t0 = (self.boxMin - origin) * invD
	local t1 = (self.boxMax - origin) * invD

	local tNear = vector.min(t0, t1)
	local tFar = vector.max(t0, t1)

	if math.min(tMax, tFar.x, tFar.y, tFar.z) <= math.max(tMin, tNear.x, tNear.y, tNear.z) then
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
