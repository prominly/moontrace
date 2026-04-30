local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local AABB = require("../core/aabb")

local Translation = {}
Translation.__index = Translation

export type Translation = typeof(setmetatable(
	{} :: { object: hittable.Hittable, offset: vector, bbox: AABB.AABB },
	Translation
))

function Translation.new(object: hittable.Hittable, offset: vector): hittable.Hittable
	local inner = object:boundingBox()

	return setmetatable({
		object = object,
		offset = offset,
		bbox = AABB.new(inner.min + offset, inner.max + offset),
	}, Translation) :: any
end

function Translation.hit(self: Translation, r: Ray.Ray, tMin: number, tMax: number): hittable.HitRecord?
	local moved = Ray.new(r.origin - self.offset, r.direction, r.time)
	local rec = self.object:hit(moved, tMin, tMax)

	if not rec then
		return nil
	end

	rec.p += self.offset

	return rec
end

function Translation.boundingBox(self: Translation): AABB.AABB
	return self.bbox
end

return Translation
