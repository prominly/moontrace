--!strict
--!optimize 2
--!native

local Camera = require("./render/camera")
local BVH = require("./core/bvh")
local hittable = require("./core/hittable")
local integrator = require("./render/integrator")
local renderStats = require("./render/stats")
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
	stats: renderStats.Stats,
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
	aovs: boolean,
	clampDirect: number,
	clampIndirect: number,
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
	local stats = renderStats.new()
	local fireflyContext: renderStats.Context = {
		pixelX = 0,
		pixelY = 0,
		sampleIndex = 0,
	}

	local fireflyOptions: renderStats.Options? = nil
	if args.clampDirect > 0 or args.clampIndirect > 0 then
		fireflyOptions = {
			clampDirect = args.clampDirect,
			clampIndirect = args.clampIndirect,
		}
	end

	local pixelCount = (args.yEnd - args.yStart) * args.width
	local byteSize = pixelCount * 12
	local colorBuf = buffer.create(byteSize)
	local albedoBuf: buffer? = if args.aovs then buffer.create(byteSize) else nil
	local normalBuf: buffer? = if args.aovs then buffer.create(byteSize) else nil

	local offset = 0
	for j = args.yStart, args.yEnd - 1 do
		for i = 0, args.width - 1 do
			local pixelColor = vector.zero
			local pixelAlbedo = vector.zero
			local pixelNormal = vector.zero

			for sampleIndex = 1, args.samples do
				local ray = camera:getRay(i, j, sampleIndex)
				fireflyContext.pixelX = i
				fireflyContext.pixelY = j
				fireflyContext.sampleIndex = sampleIndex

				if args.aovs then
					local sampleAlbedo, sampleNormal = integrator.firstHitGBuffer(ray, bvh)
					pixelAlbedo += sampleAlbedo
					pixelNormal += sampleNormal
				end

				local sampleColor = integrator.rayColor(
					ray,
					args.depth,
					bvh,
					sky,
					scene.lights,
					scene.samplers,
					sceneEnvironment,
					fireflyOptions,
					stats,
					fireflyContext
				)
				renderStats.recordFinalSample(stats, sampleColor, i, j, sampleIndex)
				pixelColor += sampleColor
			end

			pixelColor *= scale
			pixelAlbedo *= scale
			pixelNormal *= scale

			buffer.writef32(colorBuf, offset, pixelColor.x)
			buffer.writef32(colorBuf, offset + 4, pixelColor.y)
			buffer.writef32(colorBuf, offset + 8, pixelColor.z)

			if args.aovs then
				local ab = albedoBuf :: buffer
				local nb = normalBuf :: buffer

				buffer.writef32(ab, offset, pixelAlbedo.x)
				buffer.writef32(ab, offset + 4, pixelAlbedo.y)
				buffer.writef32(ab, offset + 8, pixelAlbedo.z)
				buffer.writef32(nb, offset, pixelNormal.x)
				buffer.writef32(nb, offset + 4, pixelNormal.y)
				buffer.writef32(nb, offset + 8, pixelNormal.z)
			end

			offset += 12
		end
	end

	return {
		color = buffer.tostring(colorBuf),
		albedo = if albedoBuf then buffer.tostring(albedoBuf) else "",
		normal = if normalBuf then buffer.tostring(normalBuf) else "",
		stats = stats,
	}
end

return worker
