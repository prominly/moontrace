--!strict
--!optimize 2
--!native

type SceneMetadata = {
	aspectRatio: number?,
}

local metadata: { [string]: SceneMetadata } = {
	["cornell"] = {
		aspectRatio = 1,
	},
	["cornell-box"] = {
		aspectRatio = 1,
	},
	["cornell_box"] = {
		aspectRatio = 1,
	},
}

return metadata
