local Solid = require("@self/solid")
local Image = require("@self/image")
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
	loadOrDefault = loadOrDefault,
}
