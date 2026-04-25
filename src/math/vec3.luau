local Vec3 = {}

export type Vec3 = vector
export type Point3 = vector

Vec3.new = vector.create
Vec3.length = vector.magnitude
Vec3.dot = vector.dot
Vec3.cross = vector.cross
Vec3.unitVector = vector.normalize

function Vec3.lengthSquared(v: vector): number
	return vector.dot(v, v)
end

function Vec3.nearZero(v: vector): boolean
	local s = 1e-8

	return math.abs(v.x) < s and math.abs(v.y) < s and math.abs(v.z) < s
end

function Vec3.reflect(v: vector, n: vector): vector
	return v - 2 * vector.dot(v, n) * n
end

function Vec3.refract(uv: vector, n: vector, etaiOverEtat: number): vector
	local cosTheta = math.min(vector.dot(-uv, n), 1.0)
	local rOutPerp = etaiOverEtat * (uv + cosTheta * n)
	local rOutParallel = -math.sqrt(math.abs(1.0 - vector.dot(rOutPerp, rOutPerp))) * n

	return rOutPerp + rOutParallel
end

function Vec3.random(): vector
	return vector.create(math.random(), math.random(), math.random())
end

function Vec3.randomRange(min: number, max: number): vector
	local r = max - min

	return vector.create(min + math.random() * r, min + math.random() * r, min + math.random() * r)
end

function Vec3.randomInUnitDisk(): vector
	while true do
		local p = vector.create(math.random() * 2 - 1, math.random() * 2 - 1, 0)

		if vector.dot(p, p) < 1 then
			return p
		end
	end
end

function Vec3.randomInUnitSphere(): vector
	while true do
		local p = vector.create(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)

		if vector.dot(p, p) < 1 then
			return p
		end
	end
end

function Vec3.randomUnitVector(): vector
	return vector.normalize(Vec3.randomInUnitSphere())
end

return Vec3
