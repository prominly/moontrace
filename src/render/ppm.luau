--!strict
--!optimize 2
--!native

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

function ppm.writeLinearPpm(path: string, width: number, height: number, pixels: { vector })
	local chunks = table.create(#pixels + 1)
	chunks[1] = string.format("P3\n%d %d\n255\n", width, height)

	for i = 1, #pixels do
		chunks[i + 1] = ppm.formatPixel(pixels[i])
	end

	local file = fs.open(path, "w+")

	fs.write(file, table.concat(chunks))
	fs.close(file)
end

return ppm
