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

function HittableList.boundingBox(self: HittableList): AABB.AABB
	local objects = self.objects
	local box = objects[1]:boundingBox()

	for i = 2, #objects do
		box = AABB.surrounding(box, objects[i]:boundingBox())
	end

	return box
end

return HittableList
