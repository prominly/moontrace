--!strict
--!optimize 2
--!native

local types = require("@self/types")
local default = require("@self/default")
local showcase = require("@self/showcase")
local cornellBox = require("@self/cornell_box")
local prism = require("@self/prism")
local checker = require("@self/checker")

local scenes: { [string]: types.Builder } = {
	["default"] = default.build,
	["showcase"] = showcase.build,
	["cornell-box"] = cornellBox.build,
	["prism"] = prism.build,
	["checker"] = checker.build,
}

return scenes
