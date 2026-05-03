--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")

local Point = {}
Point.__index = Point

export type Point = typeof(setmetatable(
	{} :: { position: Vec3.Point3, color: Vec3.Vec3, intensity: number, radius: number },
	Point
))

export type LightSample = { dir: Vec3.Vec3, distance: number, emitted: vector, probability: number }

function Point.new(position: Vec3.Point3, color: Vec3.Vec3, intensity: number, radius: number?): Point
	return setmetatable({
		position = position,
		color = color,
		intensity = intensity,
		radius = radius or 0,
	}, Point)
end

function Point.sample(self: Point, origin: Vec3.Point3): LightSample
	if self.radius <= 0 then
		local diff = self.position - origin
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

	local toPoint = origin - self.position
	local distToCenter = vector.magnitude(toPoint)

	if distToCenter <= self.radius then
		return { dir = vector.create(0, 1, 0), distance = 0, emitted = vector.zero, probability = 1 }
	end

	local localZ = toPoint / distToCenter
	local helper = if math.abs(localZ.x) > 0.9 then vector.create(0, 1, 0) else vector.create(1, 0, 0)
	local localY = vector.normalize(vector.cross(localZ, helper))
	local localX = vector.cross(localZ, localY)

	local z = math.random()
	local phi = 2 * math.pi * math.random()
	local sinTheta = math.sqrt(1 - z * z)
	local outwardNormal = sinTheta * math.cos(phi) * localX + sinTheta * math.sin(phi) * localY + z * localZ
	local sampledPoint = self.position + self.radius * outwardNormal

	local toLight = sampledPoint - origin
	local distance = vector.magnitude(toLight)
	local dir = toLight / distance
	local cosThetaY = -vector.dot(outwardNormal, dir)

	if cosThetaY <= 0 then
		return { dir = dir, distance = distance, emitted = vector.zero, probability = 1 }
	end

	local areaProbability = 1 / (2 * math.pi * self.radius * self.radius)
	local probability = areaProbability * distance * distance / cosThetaY

	return {
		dir = dir,
		distance = distance,
		emitted = self.color * self.intensity,
		probability = probability,
	}
end

return Point
