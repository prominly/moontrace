local task = require("@std/task")
local vm = require("@lute/vm")
local system = require("@lute/system")
local ppm = require("./render/ppm")

local WIDTH = 1200
local HEIGHT = math.max(1, math.floor(WIDTH / (16 / 9)))
local SAMPLES = 4
local DEPTH = 50
local SCENE_SEED = 1
local SCENE = "showcase"
local THREADS = system.threadCount()

-- spawn
local tSpawnStart = os.clock()
local workers = {}
for i = 1, THREADS do
	workers[i] = vm.create("./worker")
end
local tSpawn = os.clock() - tSpawnStart

-- render
local tRenderStart = os.clock()

local bandHeight = math.ceil(HEIGHT / THREADS)
local results = {}
local done = 0

for i = 1, THREADS do
	local index = i
	local yStart = (index - 1) * bandHeight
	local yEnd = math.min(index * bandHeight, HEIGHT)
	task.spawn(function()
		local _, tile = workers[index].renderTile({
			width = WIDTH,
			samples = SAMPLES,
			depth = DEPTH,
			yStart = yStart,
			yEnd = yEnd,
			sceneSeed = SCENE_SEED,
			rngSeed = 100 + index,
			aspectRatio = 16 / 9,
			scene = SCENE,
		})
		results[index] = tile
		done += 1
	end)
end

while done < THREADS do
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
