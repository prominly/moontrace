local Vec3 = require("../math/vec3")
local Ray = require("../core/ray")
local hittable = require("../core/hittable")

local Metal = {}
Metal.__index = Metal

export type Metal = typeof(setmetatable({} :: { albedo: Vec3.Vec3, fuzz: number }, Metal))

function Metal.new(albedo: Vec3.Vec3, fuzz: number): hittable.Material
	return setmetatable({ albedo = albedo, fuzz = math.min(fuzz, 1) }, Metal) :: any
end

function Metal.scatter(self: Metal, rIn: Ray.Ray, rec: hittable.HitRecord): (vector?, Ray.Ray?)
	local reflected = Vec3.reflect(Vec3.unitVector(rIn.direction), rec.normal)
	reflected = reflected + self.fuzz * Vec3.randomUnitVector()

	local scattered = Ray.new(rec.p, reflected)

	if Vec3.dot(scattered.direction, rec.normal) > 0 then
		return self.albedo, scattered
	end

	return nil, nil
end

return Metal
