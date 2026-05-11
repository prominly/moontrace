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

export type LightSample = { dir: Vec3.Vec3, distance: number, emitted: vector, probability: number, delta: boolean? }

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
			delta = true,
		}
	end

	local toPoint = origin - self.position
	local distToCenter = vector.magnitude(toPoint)

	if distToCenter <= self.radius then
		return { dir = vector.create(0, 1, 0), distance = 0, emitted = vector.zero, probability = 1, delta = true }
	end

	local localZ = toPoint / distToCenter
	local helper = vector.create(1, 0, 0)
	if math.abs(localZ.x) > 0.9 then
		helper = vector.create(0, 1, 0)
	end

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
		delta = false,
	}
end

function Point.hitEmission(self: Point, origin: Vec3.Point3, direction: Vec3.Vec3): (vector, number, number)
	if self.radius <= 0 then
		return vector.zero, math.huge, 0
	end

	local oc = origin - self.position
	local a = Vec3.lengthSquared(direction)
	local halfB = Vec3.dot(oc, direction)
	local c = Vec3.lengthSquared(oc) - self.radius * self.radius
	local discriminant = halfB * halfB - a * c

	if discriminant < 0 then
		return vector.zero, math.huge, 0
	end

	local sqrtd = math.sqrt(discriminant)
	local root = (-halfB - sqrtd) / a

	if root <= 0.001 then
		root = (-halfB + sqrtd) / a

		if root <= 0.001 then
			return vector.zero, math.huge, 0
		end
	end

	local rayLength = vector.magnitude(direction)
	local dir = direction / rayLength
	local distance = root * rayLength
	local p = origin + root * direction
	local outwardNormal = (p - self.position) / self.radius
	local cosThetaY = -Vec3.dot(outwardNormal, dir)

	if cosThetaY <= 0 then
		return vector.zero, math.huge, 0
	end

	local areaProbability = 1 / (2 * math.pi * self.radius * self.radius)
	local probability = areaProbability * distance * distance / cosThetaY

	return self.color * self.intensity, distance, probability
end

function Point.probabilityValue(self: Point, origin: Vec3.Point3, direction: Vec3.Vec3): number
	local _emitted, _distance, probability = self:hitEmission(origin, direction)

	return probability
end

return Point
