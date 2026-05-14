--!strict
--!optimize 2
--!native

type SceneMetadata = {
	aspectRatio: number?,
	defaultDepth: number?,
	defaultSceneSeed: number?,
}

local DEFAULT_DEPTH = 50
local DEFAULT_SCENE_SEED = 1
local WIDESCREEN_ASPECT_RATIO = 16 / 9

local metadata: { [string]: SceneMetadata } = {
	["default"] = {
		aspectRatio = WIDESCREEN_ASPECT_RATIO,
		defaultDepth = DEFAULT_DEPTH,
		defaultSceneSeed = DEFAULT_SCENE_SEED,
	},
	["showcase"] = {
		aspectRatio = WIDESCREEN_ASPECT_RATIO,
		defaultDepth = DEFAULT_DEPTH,
		defaultSceneSeed = DEFAULT_SCENE_SEED,
	},
	["cornell-box"] = {
		aspectRatio = 1,
		defaultDepth = DEFAULT_DEPTH,
		defaultSceneSeed = DEFAULT_SCENE_SEED,
	},
	["prism"] = {
		aspectRatio = WIDESCREEN_ASPECT_RATIO,
		defaultDepth = DEFAULT_DEPTH,
		defaultSceneSeed = DEFAULT_SCENE_SEED,
	},
}

return metadata
