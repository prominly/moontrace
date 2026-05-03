--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")
local ONB = require("../math/onb")
local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local probability = require("../render/probability")
local textures = require("../textures")
local textureTypes = require("../textures/types")

local Lambertian = {}
Lambertian.__index = Lambertian

export type Lambertian = typeof(setmetatable({} :: { texture: textureTypes.Texture }, Lambertian))

function Lambertian.new(albedo: vector | textureTypes.Texture): hittable.Material
	local tex: textureTypes.Texture
	if typeof(albedo) == "vector" then
		texture = textures.Solid.new(albedo :: vector)
	else
		texture = albedo :: textureTypes.Texture
	end
	return setmetatable({ texture = texture }, Lambertian) :: any
end

function Lambertian.scatter(self: Lambertian, rIn: Ray.Ray, rec: hittable.HitRecord): (vector?, Ray.Ray?)
	local uvw = ONB.new(rec.normal)
	local scatterDir = vector.normalize(uvw:transform(Vec3.randomCosineDirection()))

	return self.texture:value(rec.u, rec.v, rec.p), Ray.new(rec.p, scatterDir, rIn.time)
end

function Lambertian.probability(_self: Lambertian, _rIn: Ray.Ray, rec: hittable.HitRecord)
	return probability.Cosine.new(rec.normal)
end

function Lambertian.evalDirect(self: Lambertian, _rIn: Ray.Ray, rec: hittable.HitRecord, wi: Vec3.Vec3): vector
	local cosTheta = math.max(0, vector.dot(rec.normal, wi))

	return self.texture:value(rec.u, rec.v, rec.p) * cosTheta / math.pi
end

return Lambertian
