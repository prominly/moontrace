--!strict
--!optimize 2
--!native

local Point = require("@self/point")
local Directional = require("@self/directional")

export type LightSample = { dir: vector, distance: number, emitted: vector, probability: number, delta: boolean? }

export type Light = {
	sample: (any, p: vector) -> LightSample,
	probabilityValue: ((any, origin: vector, direction: vector) -> number)?,
	hitEmission: ((any, origin: vector, direction: vector) -> (vector, number, number))?,
}

return {
	Point = Point,
	Directional = Directional,
}
