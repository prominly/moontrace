--!strict
--!optimize 2
--!native

local renderOptions = {}

local DEFAULT_WIDTH = 1200
local DEFAULT_ASPECT_RATIO = 16 / 9
local DEFAULT_HEIGHT = math.floor(DEFAULT_WIDTH / DEFAULT_ASPECT_RATIO)
local DEFAULT_PIXEL_COUNT = DEFAULT_WIDTH * DEFAULT_HEIGHT
local DEFAULT_SAMPLES = 1
local DEFAULT_DEPTH = 50
local DEFAULT_SCENE_SEED = 1
local DEFAULT_RNG_SEED = 100
local DEFAULT_SCENE = "showcase"
local DEFAULT_OUTPUT_BASE = "image"

export type OutputFormat = "ppm" | "pfm"

export type SceneMetadata = {
	aspectRatio: number?,
}

export type MetadataByScene = {
	[string]: SceneMetadata,
}

export type RenderOptions = {
	width: number,
	height: number,
	samples: number,
	depth: number,
	sceneSeed: number,
	rngSeed: number,
	aspectRatio: number,
	scene: string,
	threads: number,
	outputBase: string,
	outputFormat: OutputFormat,
	denoise: boolean,
	aovs: boolean,
	preview: boolean,
}

export type ParseResult = {
	help: boolean,
	options: RenderOptions?,
}

function renderOptions.usage(): string
	return [[Usage:
  lute run src/main.luau [spp] [options]

Options:
      --scene <name>       Scene name. Default: showcase
      --spp <n>            Samples per pixel. Default: 1
      --samples <n>        Alias for --spp
      --width <px>         Image width. Default: 1200 at 16:9, adjusted for scene aspect
      --height <px>        Image height. Default: width / aspect
      --aspect <ratio>     Aspect ratio as a number or W:H. Default: scene default or 16:9
      --depth <n>          Maximum path depth. Default: 50
      --scene-seed <n>     Seed used while building randomized scenes. Default: 1
      --rng-seed <n>       Base seed used for tile sampling. Default: 100
      --threads <n>        Worker VM count. Default: host thread count
  -o, --out <path>         Output base path. Default: image
      --output <path>      Alias for --out
      --format <ppm|pfm>   Color output format. Default: ppm, or inferred from --out.
                           PFM output also writes <out>_preview.ppm.
      --aovs               Write albedo and normal AOV PFM files
      --denoise            Run the built-in guided A-Trous denoiser
  -h, --help               Print this help.

Examples:
  lute run src/main.luau --scene showcase --spp 4 --format pfm --out renders/showcase/spp_0004/color
  lute run src/main.luau 16 --width 640 --aspect 16:9 --denoise
]]
end

local function endsWith(value: string, suffix: string): boolean
	return #value >= #suffix and string.sub(value, #value - #suffix + 1) == suffix
end

local function parseOutputFormat(value: string?): OutputFormat
	if value == "ppm" or value == "pfm" then
		return value
	end

	error("expected --format to be 'ppm' or 'pfm', got " .. tostring(value))
end

local function parseInteger(value: string?, name: string): number
	local parsed = tonumber(value)
	if not parsed or parsed % 1 ~= 0 then
		error("expected " .. name .. " to be an integer, got " .. tostring(value))
	end

	return parsed
end

local function parsePositiveInteger(value: string?, name: string): number
	local parsed = parseInteger(value, name)
	if parsed < 1 then
		error("expected " .. name .. " to be at least 1, got " .. tostring(value))
	end

	return parsed
end

local function parseAspectRatio(value: string?): number
	if not value then
		error("missing value for --aspect")
	end

	local colon = string.find(value, ":", 1, true)
	if colon then
		local w = tonumber(string.sub(value, 1, colon - 1))
		local h = tonumber(string.sub(value, colon + 1))

		if w and h and w > 0 and h > 0 then
			return w / h
		end

		error("expected --aspect to be a positive ratio like 16:9, got " .. value)
	end

	local parsed = tonumber(value)
	if not parsed or parsed <= 0 then
		error("expected --aspect to be a positive number, got " .. tostring(value))
	end

	return parsed
end

local function requireValue(args: { string }, index: number, option: string): string
	local value = args[index + 1]
	if not value then
		error("missing value for " .. option)
	end

	return value
end

local function normalizeOutputBase(
	path: string,
	currentFormat: OutputFormat,
	formatExplicit: boolean
): (string, OutputFormat)
	local lower = string.lower(path)
	local outputFormat = currentFormat
	local base = path

	if endsWith(lower, ".pfm") then
		base = string.sub(path, 1, #path - 4)
		if not formatExplicit then
			outputFormat = "pfm"
		end
	elseif endsWith(lower, ".ppm") then
		base = string.sub(path, 1, #path - 4)
		if not formatExplicit then
			outputFormat = "ppm"
		end
	end

	if base == "" then
		error("output path must include a file name")
	end

	return base, outputFormat
end

local function getSceneAspectRatio(sceneName: string, metadataByScene: MetadataByScene?): number?
	if not metadataByScene then
		return nil
	end

	local sceneMetadata = metadataByScene[sceneName]
	if not sceneMetadata then
		return nil
	end

	return sceneMetadata.aspectRatio
end

local function resolveTargetAspectRatio(
	requestedAspectRatio: number?,
	sceneName: string,
	metadataByScene: MetadataByScene?
): number
	if requestedAspectRatio then
		return requestedAspectRatio
	end

	local sceneAspectRatio = getSceneAspectRatio(sceneName, metadataByScene)
	if sceneAspectRatio then
		return sceneAspectRatio
	end

	return DEFAULT_ASPECT_RATIO
end

local function defaultWidthForAspectRatio(aspectRatio: number): number
	local width = math.sqrt(DEFAULT_PIXEL_COUNT * aspectRatio)
	local pixelWidth = math.floor(width)
	local clampedWidth = math.max(1, pixelWidth)

	return clampedWidth
end

function renderOptions.parse(args: { string }, defaultThreads: number, metadataByScene: MetadataByScene?): ParseResult
	local width = DEFAULT_WIDTH
	local widthExplicit = false
	local height: number? = nil
	local requestedAspectRatio: number? = nil
	local aspectExplicit = false
	local samples = DEFAULT_SAMPLES
	local depth = DEFAULT_DEPTH
	local sceneSeed = DEFAULT_SCENE_SEED
	local rngSeed = DEFAULT_RNG_SEED
	local scene = DEFAULT_SCENE
	local threads = math.max(1, defaultThreads)
	local outputBase = DEFAULT_OUTPUT_BASE
	local outputFormat: OutputFormat = "ppm"
	local formatExplicit = false
	local denoiseEnabled = false
	local aovsEnabled = false
	local positionalSamples = false

	local index = 2
	while index <= #args do
		local arg = args[index]

		if arg == "-h" or arg == "--help" then
			return { help = true }
		elseif arg == "--scene" then
			scene = requireValue(args, index, arg)
			index += 1
		elseif arg == "--spp" or arg == "--samples" then
			samples = parsePositiveInteger(requireValue(args, index, arg), arg)
			index += 1
		elseif arg == "--width" then
			width = parsePositiveInteger(requireValue(args, index, arg), arg)
			widthExplicit = true
			index += 1
		elseif arg == "--height" then
			height = parsePositiveInteger(requireValue(args, index, arg), arg)
			index += 1
		elseif arg == "--aspect" then
			requestedAspectRatio = parseAspectRatio(requireValue(args, index, arg))
			aspectExplicit = true
			index += 1
		elseif arg == "--depth" then
			depth = parsePositiveInteger(requireValue(args, index, arg), arg)
			index += 1
		elseif arg == "--scene-seed" then
			sceneSeed = parseInteger(requireValue(args, index, arg), arg)
			index += 1
		elseif arg == "--rng-seed" then
			rngSeed = parseInteger(requireValue(args, index, arg), arg)
			index += 1
		elseif arg == "--threads" then
			threads = parsePositiveInteger(requireValue(args, index, arg), arg)
			index += 1
		elseif arg == "-o" or arg == "--out" or arg == "--output" then
			outputBase, outputFormat = normalizeOutputBase(requireValue(args, index, arg), outputFormat, formatExplicit)
			index += 1
		elseif arg == "--format" then
			outputFormat = parseOutputFormat(requireValue(args, index, arg))
			formatExplicit = true
			index += 1
		elseif arg == "--aovs" then
			aovsEnabled = true
		elseif arg == "--denoise" then
			denoiseEnabled = true
		elseif string.sub(arg, 1, 1) == "-" then
			error("unknown option: " .. arg .. "\n\n" .. renderOptions.usage())
		else
			if positionalSamples then
				error("unexpected positional argument: " .. arg .. "\n\n" .. renderOptions.usage())
			end

			samples = parsePositiveInteger(arg, "spp")
			positionalSamples = true
		end

		index += 1
	end

	if height and aspectExplicit then
		error("use either --height or --aspect, not both")
	end

	local targetAspectRatio = resolveTargetAspectRatio(requestedAspectRatio, scene, metadataByScene)
	local resolvedWidth = width
	if not widthExplicit and not height then
		resolvedWidth = defaultWidthForAspectRatio(targetAspectRatio)
	end

	local resolvedHeight: number
	if height then
		resolvedHeight = height
	else
		resolvedHeight = math.max(1, math.floor(resolvedWidth / targetAspectRatio))
	end

	local resolvedAspectRatio = resolvedWidth / resolvedHeight

	return {
		help = false,
		options = {
			width = resolvedWidth,
			height = resolvedHeight,
			samples = samples,
			depth = depth,
			sceneSeed = sceneSeed,
			rngSeed = rngSeed,
			aspectRatio = resolvedAspectRatio,
			scene = scene,
			threads = threads,
			outputBase = outputBase,
			outputFormat = outputFormat,
			denoise = denoiseEnabled,
			aovs = aovsEnabled,
			preview = outputFormat == "pfm",
		},
	}
end

return renderOptions
