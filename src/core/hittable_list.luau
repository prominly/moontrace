--!strict
--!optimize 2
--!native

local Ray = require("./ray")
local AABB = require("./aabb")
local hittable = require("./hittable")

local HittableList = {}
HittableList.__index = HittableList

export type HittableList = typeof(setmetatable({} :: { objects: { hittable.Hittable } }, HittableList))

function HittableList.new(): HittableList
	return setmetatable({ objects = {} }, HittableList)
end

function HittableList.add(self: HittableList, object: hittable.Hittable)
	table.insert(self.objects, object)
end

function HittableList.hit(self: HittableList, r: Ray.Ray, tMin: number, tMax: number): hittable.HitRecord?
	local closest = tMax
	local hitRec: hittable.HitRecord? = nil

	for _, object in self.objects do
		local rec = object:hit(r, tMin, closest)
		if rec then
			closest = rec.t
			hitRec = rec
		end
	end

	return hitRec
end

function HittableList.occluded(self: HittableList, r: Ray.Ray, tMin: number, tMax: number): boolean
	for _, object in self.objects do
		local objectOccluded = (object :: any).occluded

		if objectOccluded then
			if objectOccluded(object, r, tMin, tMax) then
				return true
			end
		elseif object:hit(r, tMin, tMax) then
			return true
		end
	end

	return false
end

function HittableList.boundingBox(self: HittableList): AABB.AABB
	local objects = self.objects
	local box = objects[1]:boundingBox()

	for i = 2, #objects do
		box = AABB.surrounding(box, objects[i]:boundingBox())
	end

	return box
end

function HittableList.probabilityValue(self: HittableList, origin: vector, direction: vector): number
	local n = #self.objects
	local weight = 1 / n
	local sum = 0

	for _, obj in self.objects do
		sum += weight * (obj :: any):probabilityValue(origin, direction)
	end

	return sum
end

function HittableList.random(self: HittableList, origin: vector): vector
	local index = math.random(1, #self.objects)

	return (self.objects[index] :: any):random(origin)
end

return HittableList
