--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")
local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local probability = require("../render/probability")
local textures = require("../textures")
local textureTypes = require("../textures/types")

local Isotropic = {}
Isotropic.__index = Isotropic

export type Isotropic = typeof(setmetatable({} :: { texture: textureTypes.Texture }, Isotropic))

function Isotropic.new(albedo: vector | textureTypes.Texture): hittable.Material
	local entity: textureTypes.Texture

	if typeof(albedo) == "vector" then
		entity = textures.Solid.new(albedo :: vector)
	else
		entity = albedo :: textureTypes.Texture
	end

	return setmetatable({ texture = entity }, Isotropic) :: any
end

function Isotropic.scatter(self: Isotropic, rIn: Ray.Ray, rec: hittable.HitRecord): (vector?, Ray.Ray?)
	return self.texture:value(rec.u, rec.v, rec.p), Ray.new(rec.p, Vec3.randomUnitVector(), rIn.time, rIn.wavelength)
end

function Isotropic.probability(_self: Isotropic, _rIn: Ray.Ray, _rec: hittable.HitRecord)
	return probability.Sphere.new()
end

function Isotropic.surfaceAlbedo(self: Isotropic, rec: hittable.HitRecord): vector
	return self.texture:value(rec.u, rec.v, rec.p)
end

return Isotropic
