local task = require("@std/task")
local vm = require("@lute/vm")
local system = require("@lute/system")
local process = require("@std/process")
local fs = require("@std/fs")
local ppm = require("./render/ppm")

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

local samplesPerPixel = tonumber(process.args[2])
if not samplesPerPixel or samplesPerPixel < 1 or samplesPerPixel % 1 ~= 0 then
	samplesPerPixel = SAMPLES
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

-- write
local tWriteStart = os.clock()
ppm.writePpm("image.ppm", WIDTH, HEIGHT, results)
local tWrite = os.clock() - tWriteStart

-- stats
print(
	string.format(
		"spawn: %.3fs  render: %.3fs  write: %.3fs  total: %.3fs",
		tSpawn,
		tRender,
		tWrite,
		tSpawn + tRender + tWrite
	)
)
