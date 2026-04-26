local Point = require("@self/point")
local Directional = require("@self/directional")

export type LightSample = { dir: vector, distance: number, emitted: vector, probability: number }

export type Light = {
	sample: (any, p: vector) -> LightSample,
}

return {
	Point = Point,
	Directional = Directional,
}
