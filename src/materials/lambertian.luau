local Vec3 = require("../math/vec3")
local Ray = require("../core/ray")
local hittable = require("../core/hittable")

local Lambertian = {}
Lambertian.__index = Lambertian

export type Lambertian = typeof(setmetatable({} :: { albedo: Vec3.Vec3 }, Lambertian))

function Lambertian.new(albedo: Vec3.Vec3): hittable.Material
	return setmetatable({ albedo = albedo }, Lambertian) :: any
end

function Lambertian.scatter(self: Lambertian, rIn: Ray.Ray, rec: hittable.HitRecord): (vector?, Ray.Ray?)
	local scatterDir = rec.normal + Vec3.randomUnitVector()

	if Vec3.nearZero(scatterDir) then
		scatterDir = rec.normal
	end

	return self.albedo, Ray.new(rec.p, scatterDir, rIn.time)
end

function Lambertian.evalDirect(self: Lambertian, _rIn: Ray.Ray, rec: hittable.HitRecord, wi: Vec3.Vec3): vector
	local cosTheta = math.max(0, vector.dot(rec.normal, wi))

	return self.albedo * cosTheta / math.pi
end

return Lambertian
