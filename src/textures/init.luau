--!strict
--!optimize 2
--!native

local Solid = require("@self/solid")
local Image = require("@self/image")
local Noise = require("@self/perlin")
local types = require("@self/types")

local function loadOrDefault(path: string, fallback: vector): types.Texture
	if Image.hasCached(path) then
		return Image.new(path)
	end

	return Solid.new(fallback)
end

return {
	Solid = Solid,
	Image = Image,
	Noise = Noise,
	loadOrDefault = loadOrDefault,
}
