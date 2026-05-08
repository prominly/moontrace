--!strict
--!optimize 2
--!native

local task = require("@std/task")
local vm = require("@lute/vm")
local system = require("@lute/system")
local process = require("@std/process")
local fs = require("@std/fs")
local ppm = require("./render/ppm")
local denoise = require("./render/denoise")

local WIDTH = 1200
local HEIGHT = math.max(1, math.floor(WIDTH / (16 / 9)))
local SAMPLES = 1
local DEPTH = 50
local SCENE_SEED = 1
local SCENE = "showcase"
local THREADS = system.threadCount()
local TILE_HEIGHT = 8

local TEXTURE_PATHS = {
	"assets/textures/moon_texture.ppm",
	"assets/textures/earth_texture.ppm",
}

-- args
local samplesPerPixel = tonumber(process.args[2])
if not samplesPerPixel or samplesPerPixel < 1 or samplesPerPixel % 1 ~= 0 then
	samplesPerPixel = SAMPLES
end

local denoiseEnabled = false
for _, arg in process.args do
	if arg == "--denoise" then
		denoiseEnabled = true
		break
	end
end

-- spawn
local tSpawnStart = os.clock()

local loaded: { { path: string, data: string } } = {}
for _, path in TEXTURE_PATHS do
	if fs.exists(path) then
		local h = fs.open(path, "r")
		loaded[#loaded + 1] = { path = path, data = fs.read(h) }
		fs.close(h)
	else
		print("[WARNING]: " .. path .. " not found; falling back to solid color")
	end
end

local workers = {}
for i = 1, THREADS do
	workers[i] = vm.create("./worker")
	for _, t in loaded do
		workers[i].preloadTexture(t.path, t.data)
	end
end
local tSpawn = os.clock() - tSpawnStart

-- render
local tRenderStart = os.clock()

local tiles = {}
for yStart = 0, HEIGHT - 1, TILE_HEIGHT do
	tiles[#tiles + 1] = { yStart = yStart, yEnd = math.min(yStart + TILE_HEIGHT, HEIGHT) }
end
local tileCount = #tiles

local results = {}
local nextTile = 1
local tilesDone = 0

for w = 1, THREADS do
	local workerIndex = w
	task.spawn(function()
		while nextTile <= tileCount do
			local currentTile = nextTile
			nextTile += 1

			local tile = tiles[currentTile]
			results[currentTile] = workers[workerIndex].renderTile({
				width = WIDTH,
				samples = samplesPerPixel,
				depth = DEPTH,
				yStart = tile.yStart,
				yEnd = tile.yEnd,
				sceneSeed = SCENE_SEED,
				rngSeed = currentTile + 100,
				aspectRatio = 16 / 9,
				scene = SCENE,
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
local pixelCount = WIDTH * HEIGHT
local color = table.create(pixelCount)
local albedo = table.create(pixelCount)
local normal = table.create(pixelCount)

local cursor = 1
for t = 1, tileCount do
	local r = results[t]
	local offset = 0
	local cb = buffer.fromstring(r.color)
	local ab = buffer.fromstring(r.albedo)
	local nb = buffer.fromstring(r.normal)
	local tilePixels = buffer.len(cb) // 12

	for _ = 1, tilePixels do
		color[cursor] =
			vector.create(buffer.readf32(cb, offset), buffer.readf32(cb, offset + 4), buffer.readf32(cb, offset + 8))
		albedo[cursor] =
			vector.create(buffer.readf32(ab, offset), buffer.readf32(ab, offset + 4), buffer.readf32(ab, offset + 8))
		normal[cursor] =
			vector.create(buffer.readf32(nb, offset), buffer.readf32(nb, offset + 4), buffer.readf32(nb, offset + 8))

		offset += 12
		cursor += 1
	end
end

-- write
local tWriteStart = os.clock()
ppm.writeLinearPpm("image.ppm", WIDTH, HEIGHT, color)
local tWrite = os.clock() - tWriteStart

-- denoise
local tDenoise = 0
if denoiseEnabled then
	local tDenoiseStart = os.clock()
	local denoised = denoise.atrous(color, albedo, normal, WIDTH, HEIGHT)
	tDenoise = os.clock() - tDenoiseStart

	ppm.writeLinearPpm("image_denoised.ppm", WIDTH, HEIGHT, denoised)
end

-- stats
if denoiseEnabled then
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
