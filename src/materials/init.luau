--!strict
--!optimize 2
--!native

local Lambertian = require("@self/lambertian")
local Metal = require("@self/metal")
local Dielectric = require("@self/dielectric")
local DiffuseLight = require("@self/diffuse_light")
local Isotropic = require("@self/isotropic")

return {
	Lambertian = Lambertian,
	Metal = Metal,
	Dielectric = Dielectric,
	DiffuseLight = DiffuseLight,
	Isotropic = Isotropic,
}
