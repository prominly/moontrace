--!strict
--!optimize 2
--!native

local Camera = require("./render/camera")
local BVH = require("./core/bvh")
local hittable = require("./core/hittable")
local integrator = require("./render/integrator")
local background = require("./render/background")
local ppm = require("./render/ppm")
local scenes = require("./scenes")
local types = require("./scenes/types")
local textures = require("./textures")

local worker = {}

local cachedKey: string? = nil
local cachedScene: types.Scene? = nil
local cachedBvh: hittable.Hittable? = nil

function worker.preloadTexture(path: string, data: string)
	textures.Image.preload(path, data)
end

function worker.renderTile(args: {
	width: number,
	samples: number,
	depth: number,
	yStart: number,
	yEnd: number,
	sceneSeed: number,
	rngSeed: number,
	aspectRatio: number,
	scene: string,
}): string
	local builder = scenes[args.scene]
	if not builder then
		error("unknown scene: " .. args.scene)
	end

	local key = args.scene .. ":" .. args.sceneSeed
	if cachedKey ~= key then
		math.randomseed(args.sceneSeed)
		cachedScene = builder()
		cachedBvh = BVH.build((cachedScene :: types.Scene).objects)
		cachedKey = key
	end

	local scene = cachedScene :: types.Scene
	local bvh = cachedBvh :: hittable.Hittable

	math.randomseed(args.rngSeed)

	local camera = Camera.new(scene.camera, {
		aspectRatio = args.aspectRatio,
		imageWidth = args.width,
		samplesPerPixel = args.samples,
		maxDepth = args.depth,
	})

	local index = 1
	local chunks = {}
	local sky = scene.sky or background.gradientSky

	for j = args.yStart, args.yEnd - 1 do
		for i = 0, args.width - 1 do
			local pixelColor = vector.zero

			for _ = 1, args.samples do
				pixelColor += integrator.rayColor(
					camera:getRay(i, j),
					args.depth,
					bvh,
					sky,
					scene.lights,
					scene.samplers
				)
			end

			chunks[index] = ppm.formatPixel(camera.pixelSamplesScale * pixelColor)
			index += 1
		end
	end

	return table.concat(chunks)
end

return worker
