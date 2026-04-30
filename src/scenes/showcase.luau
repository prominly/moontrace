local Vec3 = require("../math/vec3")
local Sphere = require("../shapes/sphere")
local Box = require("../shapes/box")
local transforms = require("../transforms")
local HittableList = require("../core/hittable_list")
local material = require("../materials")
local textures = require("../textures")
local lights = require("../lights")
local background = require("../render/background")
local types = require("./types")

local showcase = {}

local PEBBLE_PALETTE = {
	Vec3.new(0.45, 0.35, 0.20),
	Vec3.new(0.20, 0.35, 0.20),
	Vec3.new(0.55, 0.20, 0.25),
	Vec3.new(0.35, 0.20, 0.55),
	Vec3.new(0.65, 0.50, 0.20),
	Vec3.new(0.25, 0.35, 0.55),
	Vec3.new(0.60, 0.35, 0.20),
	Vec3.new(0.40, 0.45, 0.30),
}

local METAL_TINT = {
	Vec3.new(0.85, 0.65, 0.35),
	Vec3.new(0.78, 0.55, 0.40),
	Vec3.new(0.90, 0.90, 0.92),
	Vec3.new(0.70, 0.70, 0.75),
	Vec3.new(0.80, 0.60, 0.45),
}

function showcase.build(): types.Scene
	local world = HittableList.new()

	-- ground: slightly rough metal, dark teal, reflects the sunset sky
	world:add(Sphere.new(Vec3.new(0, -1000, 0), 1000, material.Metal.new(Vec3.new(0.22, 0.26, 0.32), 0.02)))

	-- distant objects on the horizon
	world:add(Sphere.new(Vec3.new(-30, 0, -22), 8.5, material.Lambertian.new(textures.Noise.new(64))))
	world:add(Sphere.new(Vec3.new(28, 0, -38), 12.0, material.Lambertian.new(Vec3.new(0.08, 0.07, 0.15))))
	world:add(
		Sphere.new(
			Vec3.new(-15, 0, -45),
			10.5,
			material.Lambertian.new(
				textures.loadOrDefault("assets/textures/earth_texture.ppm", Vec3.new(0.09, 0.08, 0.17))
			)
		)
	)
	world:add(Sphere.new(Vec3.new(45, 0, -20), 9.0, material.Lambertian.new(Vec3.new(0.11, 0.09, 0.18))))
	world:add(
		Sphere.new(
			Vec3.new(-55, 0, -8),
			13.0,
			material.Lambertian.new(
				textures.loadOrDefault("assets/textures/moon_texture.ppm", Vec3.new(0.07, 0.06, 0.13))
			)
		)
	)
	world:add(Sphere.new(Vec3.new(62, 0, -55), 15.0, material.Lambertian.new(Vec3.new(0.05, 0.05, 0.12))))
	world:add(Sphere.new(Vec3.new(8, 0, -60), 11.0, material.Lambertian.new(Vec3.new(0.08, 0.08, 0.16))))

	-- glass, rust, polished
	world:add(Sphere.new(Vec3.new(0, 3.5, 0), 3.5, material.Dielectric.new(1.5)))
	world:add(Sphere.new(Vec3.new(-7.5, 2.0, -2.5), 2.0, material.Lambertian.new(Vec3.new(0.55, 0.25, 0.15))))
	world:add(Sphere.new(Vec3.new(6.0, 1.6, -3.5), 1.6, material.Metal.new(Vec3.new(0.88, 0.75, 0.40), 0.0)))

	-- large waterline boulders
	world:add(Sphere.new(Vec3.new(4.2, 1.0, 2.8), 1.0, material.Lambertian.new(Vec3.new(0.45, 0.35, 0.20))))
	world:add(Sphere.new(Vec3.new(-3.8, 0.8, 3.0), 0.8, material.Dielectric.new(1.33)))
	world:add(Sphere.new(Vec3.new(-2.2, 0.9, -4.5), 0.9, material.Metal.new(Vec3.new(0.85, 0.85, 0.88), 0.0)))
	world:add(Sphere.new(Vec3.new(3.0, 0.7, -5.5), 0.7, material.Lambertian.new(Vec3.new(0.30, 0.15, 0.40))))
	world:add(Sphere.new(Vec3.new(-9.5, 0.6, 1.5), 0.6, material.Metal.new(Vec3.new(0.78, 0.55, 0.35), 0.1)))

	-- track every ground-level object so the scatter can reject any overlap
	local placed = {
		{ x = 0, z = 0, r = 3.5 },
		{ x = -7.5, z = -2.5, r = 2.0 },
		{ x = 6.0, z = -3.5, r = 1.6 },
		{ x = 4.2, z = 2.8, r = 1.0 },
		{ x = -3.8, z = 3.0, r = 0.8 },
		{ x = -2.2, z = -4.5, r = 0.9 },
		{ x = 3.0, z = -5.5, r = 0.7 },
		{ x = -9.5, z = 1.5, r = 0.6 },
	}

	-- scatter of medium spheres with rejection sampling
	for a = -13, 7 do
		for b = -13, 7 do
			if math.random() < 0.18 then
				local cx = a + 0.9 * math.random()
				local cz = b + 0.9 * math.random()
				local dcam2 = (cx - 10) ^ 2 + (cz - 10) ^ 2

				if dcam2 > 25 then
					local ok = true
					local radius = 0.3 + math.random() * 0.25

					for _, p in placed do
						local dx = cx - p.x
						local dz = cz - p.z
						local minDist = radius + p.r + 0.08

						if dx * dx + dz * dz < minDist * minDist then
							ok = false
							break
						end
					end

					if ok then
						local currentMaterial
						local roll = math.random()

						table.insert(placed, { x = cx, z = cz, r = radius })

						if roll < 0.55 then
							currentMaterial = material.Lambertian.new(PEBBLE_PALETTE[math.random(#PEBBLE_PALETTE)])
						elseif roll < 0.85 then
							currentMaterial =
								material.Metal.new(METAL_TINT[math.random(#METAL_TINT)], math.random() * 0.25)
						else
							currentMaterial = material.Dielectric.new(if math.random() < 0.5 then 1.33 else 1.5)
						end

						world:add(Sphere.new(Vec3.new(cx, radius, cz), radius, currentMaterial))
					end
				end
			end
		end
	end

	-- satellites drifting around the main sphere
	world:add(Sphere.new(Vec3.new(4.5, 5.8, 1.5), 0.40, material.DiffuseLight.new(Vec3.new(8, 4, 2))))
	world:add(Sphere.new(Vec3.new(-4.8, 4.5, -3.0), 0.45, material.Metal.new(Vec3.new(0.88, 0.85, 0.82), 0.0)))
	world:add(Sphere.new(Vec3.new(4.2, 7.6, -2.5), 0.35, material.Dielectric.new(1.8)))
	world:add(Sphere.new(Vec3.new(-3.8, 7.2, 3.0), 0.35, material.Metal.new(Vec3.new(0.78, 0.55, 0.35), 0.05)))
	world:add(Sphere.new(Vec3.new(1.8, 2.5, 5.0), 0.32, material.Lambertian.new(Vec3.new(0.80, 0.70, 0.30))))
	world:add(Sphere.new(Vec3.new(-5.5, 5.0, 3.5), 0.38, material.Lambertian.new(Vec3.new(0.20, 0.55, 0.60))))

	-- airborne cluster above the main sphere
	world:add(
		Sphere.newMoving(Vec3.new(-1.5, 9.5, -1.0), Vec3.new(-1.3, 9.9, -0.8), 0.50, material.Dielectric.new(1.33))
	)
	world:add(
		Sphere.newMoving(
			Vec3.new(1.2, 10.2, 0.8),
			Vec3.new(1.0, 10.5, 0.6),
			0.40,
			material.Metal.new(Vec3.new(0.90, 0.75, 0.45), 0.02)
		)
	)
	world:add(Sphere.newMoving(Vec3.new(2.8, 8.8, -1.8), Vec3.new(3.0, 9.1, -2.0), 0.35, material.Dielectric.new(1.5)))
	world:add(
		Sphere.newMoving(
			Vec3.new(-0.5, 11.5, 0.8),
			Vec3.new(-0.7, 11.8, 1.0),
			0.35,
			material.Lambertian.new(Vec3.new(0.70, 0.30, 0.50))
		)
	)

	-- lone high spheres
	world:add(Sphere.new(Vec3.new(-6.5, 12.0, -4.5), 0.55, material.Metal.new(Vec3.new(0.88, 0.88, 0.92), 0.0)))
	world:add(Sphere.new(Vec3.new(8.0, 11.2, -6.0), 0.45, material.Dielectric.new(1.5)))

	-- boxes
	world:add(
		transforms.Translation.new(
			transforms.RotationY.new(
				Box.new(vector.zero, Vec3.new(1.0, 1.0, 1.0), material.Metal.new(Vec3.new(1.0, 1.0, 1.0), 0.01)),
				-28
			),
			Vec3.new(0, -0.03, 7.1)
		)
	)
	world:add(
		transforms.Translation.new(
			transforms.RotationY.new(
				Box.new(vector.zero, Vec3.new(1.0, 1.75, 1.0), material.Lambertian.new(textures.Noise.new(2))),
				38
			),
			Vec3.new(0.7, -0.03, 6.7)
		)
	)

	return {
		objects = world.objects,
		camera = {
			vfov = 50,
			lookfrom = Vec3.new(10, 2.8, 10),
			lookat = Vec3.new(0, 3.5, 0),
			vup = Vec3.new(0, 1, 0),
			defocusAngle = 0.0,
			focusDist = 14.0,
			time0 = 0,
			time1 = 1,
		},
		sky = background.sunset,
		lights = {
			lights.Point.new(Vec3.new(-12, 14, 6), Vec3.new(1.0, 0.55, 0.30), 90, 2.0),
			lights.Directional.new(Vec3.new(-0.6, 0.35, 0.7), Vec3.new(1.0, 0.55, 0.30), 1.8),
		},
	}
end

return showcase
