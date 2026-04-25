local Vec3 = require("../math/vec3")
local Sphere = require("../shapes/sphere")
local HittableList = require("../core/hittable_list")
local material = require("../materials")
local types = require("./types")

local default = {}

function default.build(): types.Scene
	local world = HittableList.new()

	local groundMaterial = material.Lambertian.new(Vec3.new(0.5, 0.5, 0.5))
	world:add(Sphere.new(Vec3.new(0, -1000, 0), 1000, groundMaterial))

	for a = -11, 10 do
		for b = -11, 10 do
			local roll = math.random()
			local center = Vec3.new(a + 0.9 * math.random(), 0.2, b + 0.9 * math.random())

			if Vec3.length(center - Vec3.new(4, 0.2, 0)) > 0.9 then
				local currentMaterial

				if roll < 0.8 then
					currentMaterial = material.Lambertian.new(Vec3.random() * Vec3.random())
				elseif roll < 0.95 then
					currentMaterial = material.Metal.new(Vec3.randomRange(0.5, 1), math.random() * 0.5)
				else
					currentMaterial = material.Dielectric.new(1.5)
				end

				world:add(Sphere.new(center, 0.2, currentMaterial))
			end
		end
	end

	world:add(Sphere.new(Vec3.new(0, 1, 0), 1.0, material.Dielectric.new(1.5)))
	world:add(Sphere.new(Vec3.new(-4, 1, 0), 1.0, material.Lambertian.new(Vec3.new(0.4, 0.2, 0.1))))
	world:add(Sphere.new(Vec3.new(4, 1, 0), 1.0, material.Metal.new(Vec3.new(0.7, 0.6, 0.5), 0.0)))

	return {
		objects = world.objects,
		camera = {
			vfov = 20,
			lookfrom = Vec3.new(13, 2, 3),
			lookat = Vec3.new(0, 0, 0),
			vup = Vec3.new(0, 1, 0),
			defocusAngle = 0.6,
			focusDist = 10.0,
		},
	}
end

return default
