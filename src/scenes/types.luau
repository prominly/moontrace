--!strict
--!optimize 2
--!native

local Camera = require("../render/camera")
local background = require("../render/background")
local environment = require("../render/environment")
local hittable = require("../core/hittable")
local lights = require("../lights")

export type Scene = {
	objects: { hittable.Hittable },
	camera: Camera.SceneConfig,
	sky: background.Background?,
	environment: environment.Environment?,
	lights: { lights.Light }?,
	samplers: hittable.Hittable?,
}

export type Builder = () -> Scene

return {}
