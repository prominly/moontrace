--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")
local Sphere = require("../shapes/sphere")
local Quad = require("../shapes/quad")
local HittableList = require("../core/hittable_list")
local material = require("../materials")
local background = require("../render/background")
local types = require("./types")

local glossy = {}

function glossy.build(): types.Scene
	local world = HittableList.new()
	local lightSamplers = HittableList.new()

	local floor = material.PBR.new(Vec3.new(0.16, 0.17, 0.19), 0.0, 0.16)
	local backWall = material.Lambertian.new(Vec3.new(0.075, 0.085, 0.105))
	local sideWall = material.Lambertian.new(Vec3.new(0.11, 0.10, 0.09))
	local brushedGold = material.PBR.new(Vec3.new(0.95, 0.68, 0.28), 1.0, 0.045)
	local polishedChrome = material.Metal.new(Vec3.new(0.92, 0.94, 0.97), 0.0)
	local glossyPaint = material.PBR.new(Vec3.new(0.18, 0.35, 0.92), 0.0, 0.055)
	local glass = material.Dielectric.new(1.5, 0.02)
	local whiteLight = material.DiffuseLight.new(Vec3.new(32, 32, 32))
	local warmLight = material.DiffuseLight.new(Vec3.new(22, 14, 7))

	world:add(Quad.new(Vec3.new(-5, 0, -4.5), Vec3.new(10, 0, 0), Vec3.new(0, 0, 9), floor))
	world:add(Quad.new(Vec3.new(-5, 0, -4.5), Vec3.new(10, 0, 0), Vec3.new(0, 4.5, 0), backWall))
	world:add(Quad.new(Vec3.new(-5, 0, 4.5), Vec3.new(0, 4.5, 0), Vec3.new(0, 0, -9), sideWall))
	world:add(Quad.new(Vec3.new(5, 0, -4.5), Vec3.new(0, 0, 9), Vec3.new(0, 4.5, 0), sideWall))

	world:add(Sphere.new(Vec3.new(-1.55, 0.82, -1.15), 0.82, polishedChrome))
	world:add(Sphere.new(Vec3.new(0.35, 0.68, -0.45), 0.68, brushedGold))
	world:add(Sphere.new(Vec3.new(1.72, 0.58, -1.55), 0.58, glossyPaint))
	world:add(Sphere.new(Vec3.new(0.95, 0.42, 1.15), 0.42, glass))

	local keyLight = Quad.new(Vec3.new(-0.85, 4.42, -2.85), Vec3.new(1.70, 0, 0), Vec3.new(0, 0, 0.55), whiteLight)
	local stripLight = Quad.new(Vec3.new(4.92, 0.90, -2.80), Vec3.new(0, 0, 2.50), Vec3.new(0, 1.10, 0), warmLight)
	world:add(keyLight)
	world:add(stripLight)
	lightSamplers:add(keyLight)
	lightSamplers:add(stripLight)

	return {
		objects = world.objects,
		camera = {
			vfov = 34,
			lookfrom = Vec3.new(3.6, 1.8, 5.2),
			lookat = Vec3.new(0.05, 0.85, -0.65),
			vup = Vec3.new(0, 1, 0),
			defocusAngle = 0,
			focusDist = 6.9,
		},
		sky = background.solid(Vec3.new(0.004, 0.005, 0.007)),
		samplers = lightSamplers :: any,
	}
end

return glossy
