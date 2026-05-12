--!strict
--!optimize 2
--!native

local Camera = require("./render/camera")
local BVH = require("./core/bvh")
local hittable = require("./core/hittable")
local integrator = require("./render/integrator")
local background = require("./render/background")
local scenes = require("./scenes")
local types = require("./scenes/types")
local textures = require("./textures")

local worker = {}

local cachedKey: string? = nil
local cachedScene: types.Scene? = nil
local cachedBvh: hittable.Hittable? = nil

export type TileResult = {
	color: string,
	albedo: string,
	normal: string,
}

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
}): TileResult
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

	local sky = scene.sky or background.gradientSky
	local sceneEnvironment = scene.environment
	local scale = camera.pixelSamplesScale

	local pixelCount = (args.yEnd - args.yStart) * args.width
	local byteSize = pixelCount * 12
	local colorBuf = buffer.create(byteSize)
	local albedoBuf = buffer.create(byteSize)
	local normalBuf = buffer.create(byteSize)

	local offset = 0
	for j = args.yStart, args.yEnd - 1 do
		for i = 0, args.width - 1 do
			local pixelColor = vector.zero

			local firstRay = camera:getRay(i, j, 1)
			local a, n = integrator.firstHitGBuffer(firstRay, bvh)
			pixelColor += integrator.rayColor(
				firstRay,
				args.depth,
				bvh,
				sky,
				scene.lights,
				scene.samplers,
				sceneEnvironment
			)

			for sampleIndex = 2, args.samples do
				pixelColor += integrator.rayColor(
					camera:getRay(i, j, sampleIndex),
					args.depth,
					bvh,
					sky,
					scene.lights,
					scene.samplers,
					sceneEnvironment
				)
			end

			pixelColor *= scale
			buffer.writef32(colorBuf, offset, pixelColor.x)
			buffer.writef32(colorBuf, offset + 4, pixelColor.y)
			buffer.writef32(colorBuf, offset + 8, pixelColor.z)
			buffer.writef32(albedoBuf, offset, a.x)
			buffer.writef32(albedoBuf, offset + 4, a.y)
			buffer.writef32(albedoBuf, offset + 8, a.z)
			buffer.writef32(normalBuf, offset, n.x)
			buffer.writef32(normalBuf, offset + 4, n.y)
			buffer.writef32(normalBuf, offset + 8, n.z)
			offset += 12
		end
	end

	return {
		color = buffer.tostring(colorBuf),
		albedo = buffer.tostring(albedoBuf),
		normal = buffer.tostring(normalBuf),
	}
end

return worker
