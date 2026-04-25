local fs = require("@std/fs")
local gamma = require("./gamma")

local ppm = {}

function ppm.formatPixel(pixel: vector): string
	return string.format(
		"%d %d %d\n",
		gamma.channelToByte(pixel.x),
		gamma.channelToByte(pixel.y),
		gamma.channelToByte(pixel.z)
	)
end

function ppm.writePpm(path: string, width: number, height: number, tiles: { string })
	local chunks = { string.format("P3\n%d %d\n255\n", width, height) }

	for i = 1, #tiles do
		chunks[#chunks + 1] = tiles[i]
	end

	local file = fs.open(path, "w+")

	fs.write(file, table.concat(chunks))
	fs.close(file)
end

return ppm
