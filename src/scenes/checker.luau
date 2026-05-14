--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")
local Sphere = require("../shapes/sphere")
local Quad = require("../shapes/quad")
local HittableList = require("../core/hittable_list")
local material = require("../materials")
local textures = require("../textures")
local background = require("../render/background")
local types = require("./types")

local checker = {}

function checker.build(): types.Scene
	local world = HittableList.new()

	local floorTexture = textures.Checker.new(Vec3.new(0.92, 0.90, 0.84), Vec3.new(0.06, 0.08, 0.11), 14)
	local wallTexture = textures.Checker.new(Vec3.new(0.84, 0.14, 0.10), Vec3.new(0.08, 0.30, 0.78), 12)
	local sphereTexture = textures.Checker.new(Vec3.new(0.95, 0.82, 0.12), Vec3.new(0.05, 0.08, 0.12), 10)
	local fineTexture = textures.Checker.new(Vec3.new(0.96, 0.96, 0.94), Vec3.new(0.02, 0.02, 0.025), 24)

	local floor = material.Lambertian.new(floorTexture)
	local wall = material.Lambertian.new(wallTexture)
	local checkerSphere = material.Lambertian.new(sphereTexture)
	local fineSphere = material.Lambertian.new(fineTexture)
	local matteGreen = material.Lambertian.new(Vec3.new(0.20, 0.62, 0.32))
	local matteWhite = material.Lambertian.new(Vec3.new(0.78, 0.78, 0.74))
	local light = material.DiffuseLight.new(Vec3.new(8, 8, 8))

	world:add(Quad.new(Vec3.new(-4, 0, -4), Vec3.new(8, 0, 0), Vec3.new(0, 0, 8), floor))
	world:add(Quad.new(Vec3.new(-4, 0, -4), Vec3.new(8, 0, 0), Vec3.new(0, 4.5, 0), wall))
	world:add(Quad.new(Vec3.new(-4, 0, 4), Vec3.new(0, 4.5, 0), Vec3.new(0, 0, -8), matteWhite))
	world:add(Quad.new(Vec3.new(4, 0, -4), Vec3.new(0, 0, 8), Vec3.new(0, 4.5, 0), matteWhite))

	world:add(Sphere.new(Vec3.new(-1.35, 0.85, -1.35), 0.85, checkerSphere))
	world:add(Sphere.new(Vec3.new(1.15, 0.65, -0.55), 0.65, fineSphere))
	world:add(Sphere.new(Vec3.new(-0.10, 0.45, 1.15), 0.45, matteGreen))

	local lightQuad = Quad.new(Vec3.new(-1.25, 4.45, -2.35), Vec3.new(2.5, 0, 0), Vec3.new(0, 0, 1.35), light)
	world:add(lightQuad)

	return {
		objects = world.objects,
		camera = {
			vfov = 36,
			lookfrom = Vec3.new(3.2, 2.1, 5.6),
			lookat = Vec3.new(0, 1.05, -0.75),
			vup = Vec3.new(0, 1, 0),
			defocusAngle = 0,
			focusDist = 7.2,
		},
		sky = background.solid(Vec3.new(0.01, 0.012, 0.016)),
		samplers = lightQuad,
	}
end

return checker
