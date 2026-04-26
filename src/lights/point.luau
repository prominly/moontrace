local Vec3 = require("../math/vec3")

local Point = {}
Point.__index = Point

export type Point = typeof(setmetatable({} :: { position: Vec3.Point3, color: Vec3.Vec3, intensity: number }, Point))

export type LightSample = { dir: Vec3.Vec3, distance: number, emitted: vector, probability: number }

function Point.new(position: Vec3.Point3, color: Vec3.Vec3, intensity: number): Point
	return setmetatable({ position = position, color = color, intensity = intensity }, Point)
end

function Point.sample(self: Point, p: Vec3.Point3): LightSample
	local diff = self.position - p
	local distance = vector.magnitude(diff)
	local dir = diff / distance
	local emitted = self.color * self.intensity / (distance * distance)

	return {
		dir = dir,
		distance = distance,
		emitted = emitted,
		probability = 1,
	}
end

return Point
