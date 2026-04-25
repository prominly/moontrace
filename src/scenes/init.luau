local types = require("@self/types")
local default = require("@self/default")
local showcase = require("@self/showcase")

local scenes: { [string]: types.Builder } = {
	["default"] = default.build,
	["showcase"] = showcase.build,
}

return scenes
