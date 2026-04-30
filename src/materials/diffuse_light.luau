local Ray = require("../core/ray")
local hittable = require("../core/hittable")
local textures = require("../textures")
local textureTypes = require("../textures/types")

local DiffuseLight = {}
DiffuseLight.__index = DiffuseLight

export type DiffuseLight = typeof(setmetatable({} :: { texture: textureTypes.Texture }, DiffuseLight))

function DiffuseLight.new(emit: vector | textureTypes.Texture): hittable.Material
	local tex: textureTypes.Texture

	if typeof(emit) == "vector" then
		tex = textures.Solid.new(emit :: vector)
	else
		tex = emit :: textureTypes.Texture
	end

	return setmetatable({ texture = tex }, DiffuseLight) :: any
end

function DiffuseLight.scatter(_self: DiffuseLight, _rIn: Ray.Ray, _rec: hittable.HitRecord): (vector?, Ray.Ray?)
	return nil, nil
end

function DiffuseLight.emitted(self: DiffuseLight, rec: hittable.HitRecord): vector
	if not rec.frontFace then
		return vector.zero
	end

	return self.texture:value(rec.u, rec.v, rec.p)
end

return DiffuseLight
