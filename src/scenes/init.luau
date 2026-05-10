--!strict
--!optimize 2
--!native

local types = require("@self/types")
local default = require("@self/default")
local showcase = require("@self/showcase")
local prism = require("@self/prism")

local scenes: { [string]: types.Builder } = {
	["default"] = default.build,
	["showcase"] = showcase.build,
	["prism"] = prism.build,
}

return scenes
