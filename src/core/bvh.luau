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
		_isBVH: boolean,
	},
	BVH
))

type Entry = { obj: hittable.Hittable, box: AABB.AABB }

local TRAVERSAL_STACK: { BVH } = table.create(64)

local function surfaceArea(box: AABB.AABB): number
	local d = box.max - box.min
	return d.x * d.y + d.y * d.z + d.x * d.z
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
			_isBVH = true,
		}, BVH) :: any
	end

	-- Surface Area Heuristic
	-- pick the (axis, split) that minimizes SA(left) * |left| + SA(right) * |right|
	local bestCost = math.huge
	local bestAxis = 0
	local bestSplit = 1

	local leftBoxes: { AABB.AABB } = table.create(n)
	local rightBoxes: { AABB.AABB } = table.create(n)

	for axis = 0, 2 do
		table.sort(entries, compareByAxis(axis))

		leftBoxes[1] = entries[1].box
		for i = 2, n do
			leftBoxes[i] = AABB.surrounding(leftBoxes[i - 1], entries[i].box)
		end

		rightBoxes[n] = entries[n].box
		for i = n - 1, 1, -1 do
			rightBoxes[i] = AABB.surrounding(rightBoxes[i + 1], entries[i].box)
		end

		for i = 1, n - 1 do
			local cost = surfaceArea(leftBoxes[i]) * i + surfaceArea(rightBoxes[i + 1]) * (n - i)
			if cost < bestCost then
				bestCost = cost
				bestAxis = axis
				bestSplit = i
			end
		end
	end

	if bestAxis ~= 2 then
		table.sort(entries, compareByAxis(bestAxis))
	end

	local leftEntries: { Entry } = table.create(bestSplit)
	for i = 1, bestSplit do
		leftEntries[i] = entries[i]
	end

	local rightEntries: { Entry } = table.create(n - bestSplit)
	for i = bestSplit + 1, n do
		rightEntries[i - bestSplit] = entries[i]
	end

	return setmetatable({
		left = buildEntries(leftEntries),
		right = buildEntries(rightEntries),
		box = box,
		boxMin = box.min,
		boxMax = box.max,
		_isBVH = true,
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
	local origin = r.origin
	local invD = r.invDirection

	local closestRec: hittable.HitRecord? = nil
	local closestT = tMax

	local stack = TRAVERSAL_STACK
	stack[1] = self
	local top = 1

	while top > 0 do
		local node = stack[top]
		top -= 1

		local t0 = (node.boxMin - origin) * invD
		local t1 = (node.boxMax - origin) * invD
		local tNear = vector.min(t0, t1)
		local tFar = vector.max(t0, t1)

		if math.min(closestT, tFar.x, tFar.y, tFar.z) <= math.max(tMin, tNear.x, tNear.y, tNear.z) then
			continue
		end

		-- push right first so left pops first (matches recursive left-to-right order)
		local right = node.right
		if (right :: any)._isBVH then
			top += 1
			stack[top] = right :: any
		else
			local rec = (right :: any):hit(r, tMin, closestT)
			if rec then
				closestRec = rec
				closestT = rec.t
			end
		end

		local left = node.left
		if (left :: any)._isBVH then
			top += 1
			stack[top] = left :: any
		else
			local rec = (left :: any):hit(r, tMin, closestT)
			if rec then
				closestRec = rec
				closestT = rec.t
			end
		end
	end

	return closestRec
end

function BVH.boundingBox(self: BVH): AABB.AABB
	return self.box
end

return BVH
