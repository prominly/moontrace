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
	denoise: boolean,
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
	local albedoBuf: buffer? = if args.denoise then buffer.create(byteSize) else nil
	local normalBuf: buffer? = if args.denoise then buffer.create(byteSize) else nil

	local offset = 0
	for j = args.yStart, args.yEnd - 1 do
		for i = 0, args.width - 1 do
			local pixelColor = vector.zero

			local firstRay = camera:getRay(i, j, 1)
			local firstAlbedo = vector.zero
			local firstNormal = vector.zero
			if args.denoise then
				firstAlbedo, firstNormal = integrator.firstHitGBuffer(firstRay, bvh)
			end

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

			if args.denoise then
				local ab = albedoBuf :: buffer
				local nb = normalBuf :: buffer

				buffer.writef32(ab, offset, firstAlbedo.x)
				buffer.writef32(ab, offset + 4, firstAlbedo.y)
				buffer.writef32(ab, offset + 8, firstAlbedo.z)
				buffer.writef32(nb, offset, firstNormal.x)
				buffer.writef32(nb, offset + 4, firstNormal.y)
				buffer.writef32(nb, offset + 8, firstNormal.z)
			end

			offset += 12
		end
	end

	return {
		color = buffer.tostring(colorBuf),
		albedo = if albedoBuf then buffer.tostring(albedoBuf) else "",
		normal = if normalBuf then buffer.tostring(normalBuf) else "",
	}
end

return worker
