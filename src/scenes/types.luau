local Camera = require("../render/camera")
local background = require("../render/background")
local hittable = require("../core/hittable")

export type Scene = {
	objects: { hittable.Hittable },
	camera: Camera.SceneConfig,
	sky: background.Background?,
}

export type Builder = () -> Scene

return {}
