local Lambertian = require("@self/lambertian")
local Metal = require("@self/metal")
local Dielectric = require("@self/dielectric")

return {
	Lambertian = Lambertian,
	Metal = Metal,
	Dielectric = Dielectric,
}
