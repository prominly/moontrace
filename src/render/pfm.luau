--!strict
--!optimize 2
--!native

local fs = require("@std/fs")

-- https://www.pauldebevec.com/Research/HDR/PFM
local pfm = {}

function pfm.writeFile(path: string, width: number, height: number, pixels: { vector })
	local pixelCount = width * height
	if #pixels ~= pixelCount then
		error(string.format("PFM pixel count mismatch: got %d, expected %d", #pixels, pixelCount))
	end

	local data = buffer.create(pixelCount * 12)
	local offset = 0

	-- scanlines from bottom to top
	for y = height - 1, 0, -1 do
		local row = y * width

		for x = 1, width do
			local pixel = pixels[row + x]

			buffer.writef32(data, offset, pixel.x)
			buffer.writef32(data, offset + 4, pixel.y)
			buffer.writef32(data, offset + 8, pixel.z)
			offset += 12
		end
	end

	local file = fs.open(path, "w+")

	fs.write(file, string.format("PF\n%d %d\n-1.0\n", width, height))
	fs.write(file, buffer.tostring(data))
	fs.close(file)
end

return pfm
