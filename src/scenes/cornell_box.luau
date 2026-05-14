--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")
local Quad = require("../shapes/quad")
local Box = require("../shapes/box")
local transforms = require("../transforms")
local HittableList = require("../core/hittable_list")
local material = require("../materials")
local background = require("../render/background")
local types = require("./types")

local cornellBox = {}

local BOX_SIZE = 555
local BOX_CENTER = BOX_SIZE / 2
local CAMERA_Z = -800
local FRONT_Z = 0

local function vfovForFrame(frameHeight: number, distance: number): number
	return math.deg(2 * math.atan((frameHeight / 2) / distance))
end

function cornellBox.build(): types.Scene
	local world = HittableList.new()
	local cameraDistance = FRONT_Z - CAMERA_Z

	local red = material.Lambertian.new(Vec3.new(0.65, 0.05, 0.05))
	local white = material.Lambertian.new(Vec3.new(0.73, 0.73, 0.73))
	local green = material.Lambertian.new(Vec3.new(0.12, 0.45, 0.15))
	local light = material.DiffuseLight.new(Vec3.new(15, 15, 15))

	world:add(Quad.new(Vec3.new(555, 0, 0), Vec3.new(0, 555, 0), Vec3.new(0, 0, 555), red))
	world:add(Quad.new(Vec3.new(0, 0, 0), Vec3.new(0, 555, 0), Vec3.new(0, 0, 555), green))
	world:add(Quad.new(Vec3.new(0, 0, 0), Vec3.new(555, 0, 0), Vec3.new(0, 0, 555), white))
	world:add(Quad.new(Vec3.new(555, 555, 555), Vec3.new(-555, 0, 0), Vec3.new(0, 0, -555), white))
	world:add(Quad.new(Vec3.new(0, 0, 555), Vec3.new(555, 0, 0), Vec3.new(0, 555, 0), white))

	local lightQuad = Quad.new(Vec3.new(343, 554, 332), Vec3.new(-130, 0, 0), Vec3.new(0, 0, -105), light)
	world:add(lightQuad)

	world:add(
		transforms.Translation.new(
			transforms.RotationY.new(Box.new(Vec3.new(0, 0, 0), Vec3.new(165, 330, 165), white), 15),
			Vec3.new(265, 0, 295)
		)
	)
	world:add(
		transforms.Translation.new(
			transforms.RotationY.new(Box.new(Vec3.new(0, 0, 0), Vec3.new(165, 165, 165), white), -18),
			Vec3.new(130, 0, 65)
		)
	)

	return {
		objects = world.objects,
		camera = {
			vfov = vfovForFrame(BOX_SIZE, cameraDistance),
			lookfrom = Vec3.new(BOX_CENTER, BOX_CENTER, CAMERA_Z),
			lookat = Vec3.new(BOX_CENTER, BOX_CENTER, FRONT_Z),
			vup = Vec3.new(0, 1, 0),
			defocusAngle = 0,
			focusDist = cameraDistance,
		},
		sky = background.solid(vector.zero),
		samplers = lightQuad,
	}
end

return cornellBox
