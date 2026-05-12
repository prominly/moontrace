--!strict
--!optimize 2
--!native

local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local AABB = require("../core/aabb")
local materials = require("../materials")
local textureTypes = require("../textures/types")

local ConstantMedium = {}
ConstantMedium.__index = ConstantMedium

export type ConstantMedium = typeof(setmetatable(
	{} :: {
		boundary: hittable.Hittable,
		negInvDensity: number,
		phaseFunction: hittable.Material,
	},
	ConstantMedium
))

function ConstantMedium.new(
	boundary: hittable.Hittable,
	density: number,
	albedo: vector | textureTypes.Texture
): hittable.Hittable
	return setmetatable({
		boundary = boundary,
		negInvDensity = -1 / density,
		phaseFunction = materials.Isotropic.new(albedo),
	}, ConstantMedium) :: any
end

function ConstantMedium.hit(self: ConstantMedium, r: Ray.Ray, tMin: number, tMax: number): hittable.HitRecord?
	local rec1 = self.boundary:hit(r, -math.huge, math.huge)

	if not rec1 then
		return nil
	end

	local rec2 = self.boundary:hit(r, rec1.t + 1e-4, math.huge)

	if not rec2 then
		return nil
	end

	local t1 = if rec1.t < tMin then tMin else rec1.t
	local t2 = if rec2.t > tMax then tMax else rec2.t

	if t1 >= t2 then
		return nil
	end

	if t1 < 0 then
		t1 = 0
	end

	local rayLength = vector.magnitude(r.direction)
	local distInside = (t2 - t1) * rayLength
	local hitDistance = self.negInvDensity * math.log(math.random())

	if hitDistance > distInside then
		return nil
	end

	local t = t1 + hitDistance / rayLength

	return {
		t = t,
		p = Ray.at(r, t),
		normal = vector.create(1, 0, 0),
		tangent = vector.create(0, 0, 1),
		bitangent = vector.create(0, 1, 0),
		frontFace = true,
		material = self.phaseFunction,
		materialCache = nil,
		u = 0,
		v = 0,
	}
end

function ConstantMedium.occluded(self: ConstantMedium, r: Ray.Ray, tMin: number, tMax: number): boolean
	return self:hit(r, tMin, tMax) ~= nil
end

function ConstantMedium.boundingBox(self: ConstantMedium): AABB.AABB
	return self.boundary:boundingBox()
end

return ConstantMedium
