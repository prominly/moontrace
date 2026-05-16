--!strict
--!optimize 2
--!native

local task = require("@std/task")
local vm = require("@lute/vm")
local system = require("@lute/system")
local process = require("@std/process")
local fs = require("@std/fs")
local ppm = require("./render/ppm")
local pfm = require("./render/pfm")
local denoise = require("./render/denoise")
local paths = require("./cli/paths")
local renderOptions = require("./cli/render_options")
local sceneMetadata = require("./scenes/metadata")

local TILE_HEIGHT = 8

local TEXTURE_PATHS = {
	"assets/textures/moon_texture.ppm",
	"assets/textures/earth_texture.ppm",
}

type OutputFormat = "ppm" | "pfm"

local function writeColorImage(
	pathBase: string,
	format: OutputFormat,
	width: number,
	height: number,
	pixels: { vector }
)
	if format == "pfm" then
		local path = pathBase .. ".pfm"
		paths.ensureParentDirectory(path)
		pfm.writeFile(path, width, height, pixels)
	else
		local path = pathBase .. ".ppm"
		paths.ensureParentDirectory(path)
		ppm.writeFile(path, width, height, pixels)
	end
end

local function writePreviewImage(pathBase: string, width: number, height: number, pixels: { vector })
	local path = pathBase .. ".ppm"
	paths.ensureParentDirectory(path)
	ppm.writeFile(path, width, height, pixels)
end

local parsed = renderOptions.parse(process.args, system.threadCount(), sceneMetadata)
if parsed.help then
	print(renderOptions.usage())
	process.exit(0)
end

local options = parsed.options
if not options then
	error("render options missing")
end

if not sceneMetadata[options.scene] then
	error("unknown scene: " .. options.scene)
end

local collectAovs = options.aovs or options.denoise

local settingsBody = string.format(
	[[settings:
  scene:   %s
  size:    %dx%d
  aspect:  %.3f
  spp:     %d
  depth:   %d
  threads: %d
  format:  %s
  out:     %s
  preview: %s
  aovs:    %s
  denoise: %s
  ]],
	options.scene,
	options.width,
	options.height,
	options.aspectRatio,
	options.samples,
	options.depth,
	options.threads,
	options.outputFormat,
	options.outputBase,
	tostring(options.preview),
	tostring(options.aovs),
	tostring(options.denoise)
)

print(settingsBody)

-- spawn
local tSpawnStart = os.clock()

local projectRoot = paths.projectRootFromScript(process.args[1])
local loaded: { { path: string, data: string } } = {}
for _, path in TEXTURE_PATHS do
	local sourcePath = paths.resolveProjectPath(projectRoot, path)
	if fs.exists(sourcePath) then
		local h = fs.open(sourcePath, "r")
		loaded[#loaded + 1] = { path = path, data = fs.read(h) }
		fs.close(h)
	else
		print("[WARNING]: " .. sourcePath .. " not found; falling back to solid color")
	end
end

local workers = {}
for i = 1, options.threads do
	workers[i] = vm.create("./worker")
	for _, t in loaded do
		workers[i].preloadTexture(t.path, t.data)
	end
end
local tSpawn = os.clock() - tSpawnStart

-- render
local tRenderStart = os.clock()

local tiles = {}
for yStart = 0, options.height - 1, TILE_HEIGHT do
	tiles[#tiles + 1] = { yStart = yStart, yEnd = math.min(yStart + TILE_HEIGHT, options.height) }
end
local tileCount = #tiles

local results = {}
local nextTile = 1
local tilesDone = 0

for w = 1, options.threads do
	local workerIndex = w
	task.spawn(function()
		while nextTile <= tileCount do
			local currentTile = nextTile
			nextTile += 1

			local tile = tiles[currentTile]
			results[currentTile] = workers[workerIndex].renderTile({
				width = options.width,
				samples = options.samples,
				depth = options.depth,
				yStart = tile.yStart,
				yEnd = tile.yEnd,
				sceneSeed = options.sceneSeed,
				rngSeed = options.rngSeed + currentTile,
				aspectRatio = options.aspectRatio,
				scene = options.scene,
				aovs = collectAovs,
			})
			tilesDone += 1
		end
	end)
end

while tilesDone < tileCount do
	task.wait()
end

local tRender = os.clock() - tRenderStart

-- assembly
local pixelCount = options.width * options.height
local color = table.create(pixelCount) :: { vector }
local albedo = (if collectAovs then table.create(pixelCount) else {}) :: { vector }
local normal = (if collectAovs then table.create(pixelCount) else {}) :: { vector }

local cursor = 1
for t = 1, tileCount do
	local r = results[t]
	local offset = 0
	local cb = buffer.fromstring(r.color)
	local ab: buffer? = if collectAovs then buffer.fromstring(r.albedo) else nil
	local nb: buffer? = if collectAovs then buffer.fromstring(r.normal) else nil
	local tilePixels = buffer.len(cb) // 12

	for _ = 1, tilePixels do
		color[cursor] =
			vector.create(buffer.readf32(cb, offset), buffer.readf32(cb, offset + 4), buffer.readf32(cb, offset + 8))

		if collectAovs then
			local albedoBuf = ab :: buffer
			local normalBuf = nb :: buffer

			albedo[cursor] = vector.create(
				buffer.readf32(albedoBuf, offset),
				buffer.readf32(albedoBuf, offset + 4),
				buffer.readf32(albedoBuf, offset + 8)
			)
			normal[cursor] = vector.create(
				buffer.readf32(normalBuf, offset),
				buffer.readf32(normalBuf, offset + 4),
				buffer.readf32(normalBuf, offset + 8)
			)
		end

		offset += 12
		cursor += 1
	end
end

-- write
local tWriteStart = os.clock()
writeColorImage(options.outputBase, options.outputFormat, options.width, options.height, color)
if options.preview then
	writePreviewImage(options.outputBase .. "_preview", options.width, options.height, color)
end
if options.aovs then
	writeColorImage(paths.siblingPath(options.outputBase, "albedo"), "pfm", options.width, options.height, albedo)
	writeColorImage(paths.siblingPath(options.outputBase, "normal"), "pfm", options.width, options.height, normal)
end
local tWrite = os.clock() - tWriteStart

-- denoise
local tDenoise = 0
if options.denoise then
	local tDenoiseStart = os.clock()
	local denoised = denoise.atrous(color, albedo, normal, options.width, options.height)
	tDenoise = os.clock() - tDenoiseStart

	writeColorImage(options.outputBase .. "_denoised", options.outputFormat, options.width, options.height, denoised)
end

-- stats
if options.denoise then
	print(
		string.format(
			"spawn: %.3fs  render: %.3fs  write: %.3fs  denoise: %.3fs  total: %.3fs",
			tSpawn,
			tRender,
			tWrite,
			tDenoise,
			tSpawn + tRender + tWrite + tDenoise
		)
	)
else
	print(
		string.format(
			"spawn: %.3fs  render: %.3fs  write: %.3fs  total: %.3fs",
			tSpawn,
			tRender,
			tWrite,
			tSpawn + tRender + tWrite
		)
	)
end
