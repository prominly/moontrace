local Lambertian = require("@self/lambertian")
local Metal = require("@self/metal")
local Dielectric = require("@self/dielectric")
local DiffuseLight = require("@self/diffuse_light")

return {
	Lambertian = Lambertian,
	Metal = Metal,
	Dielectric = Dielectric,
	DiffuseLight = DiffuseLight,
}
