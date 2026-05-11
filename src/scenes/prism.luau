--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")
local Sphere = require("../shapes/sphere")
local HittableList = require("../core/hittable_list")
local material = require("../materials")
local background = require("../render/background")
local types = require("./types")

local prism = {}

function prism.build(): types.Scene
	local world = HittableList.new()

	world:add(Sphere.new(Vec3.new(0, -1000, 0), 1000, material.Lambertian.new(Vec3.new(0.04, 0.04, 0.05))))

	world:add(Sphere.new(Vec3.new(-2.4, 1, 0), 1, material.Dielectric.new(1.45, 0.02)))
	-- exaggerated dispersion (real crown glass: 0.0042; here: 0.06)
	world:add(Sphere.new(Vec3.new(0, 1, 0), 1, material.Dielectric.new(1.45, 0.06)))
	world:add(Sphere.new(Vec3.new(2.4, 1, 0), 1, material.Dielectric.new(1.45, 0.12)))

	-- tinted dispersive gems: Beer-Lambert absorption (ruby, emerald)
	world:add(
		Sphere.new(
			Vec3.new(-1.2, 0.45, -2.5),
			0.45,
			material.Dielectric.new(1.77, 0.05, Vec3.new(0.92, 0.20, 0.18), 2.5)
		)
	)
	world:add(
		Sphere.new(
			Vec3.new(1.2, 0.45, -2.5),
			0.45,
			material.Dielectric.new(1.58, 0.05, Vec3.new(0.20, 0.85, 0.32), 2.5)
		)
	)

	return {
		objects = world.objects,
		camera = {
			vfov = 25,
			lookfrom = Vec3.new(0, 1.6, 9),
			lookat = Vec3.new(0, 1, 0),
			vup = Vec3.new(0, 1, 0),
			defocusAngle = 0,
			focusDist = 9,
			spectral = true,
		},
		sky = background.gradientSky,
	}
end

return prism
