--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")

local Directional = {}
Directional.__index = Directional

export type Directional = typeof(setmetatable(
	{} :: { toLight: Vec3.Vec3, color: Vec3.Vec3, intensity: number },
	Directional
))

export type LightSample = { dir: Vec3.Vec3, distance: number, emitted: vector, probability: number, delta: boolean? }

function Directional.new(toLight: Vec3.Vec3, color: Vec3.Vec3, intensity: number): Directional
	return setmetatable({ toLight = Vec3.unitVector(toLight), color = color, intensity = intensity }, Directional)
end

function Directional.sample(self: Directional, _p: Vec3.Point3): LightSample
	return {
		dir = self.toLight,
		distance = math.huge,
		emitted = self.color * self.intensity,
		probability = 1,
		delta = true,
	}
end

function Directional.probabilityValue(_self: Directional, _origin: Vec3.Point3, _direction: Vec3.Vec3): number
	return 0
end

return Directional
