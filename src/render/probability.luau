local Vec3 = require("../math/vec3")
local ONB = require("../math/onb")

-- cosine
local Cosine = {}
Cosine.__index = Cosine
export type Cosine = typeof(setmetatable({} :: { uvw: ONB.ONB }, Cosine))

function Cosine.new(normal: vector): Cosine
	return setmetatable({ uvw = ONB.new(normal) }, Cosine)
end

function Cosine.value(self: Cosine, direction: vector): number
	local cosTheta = vector.dot(vector.normalize(direction), self.uvw.w)

	return math.max(0, cosTheta / math.pi)
end

function Cosine.generate(self: Cosine): vector
	return self.uvw:transform(Vec3.randomCosineDirection())
end

-- sphere
local Sphere = {}
Sphere.__index = Sphere
export type Sphere = typeof(setmetatable({} :: {}, Sphere))

local SPHERE_SINGLETON: Sphere = setmetatable({}, Sphere) :: any

function Sphere.new(): Sphere
	return SPHERE_SINGLETON
end

function Sphere.value(_self: Sphere, _direction: vector): number
	return 1 / (4 * math.pi)
end

function Sphere.generate(_self: Sphere): vector
	return Vec3.randomUnitVector()
end

-- hittable
local Hittable = {}
Hittable.__index = Hittable
export type Hittable = typeof(setmetatable({} :: { object: any, origin: vector }, Hittable))

function Hittable.new(object: any, origin: vector): Hittable
	return setmetatable({ object = object, origin = origin }, Hittable)
end

function Hittable.value(self: Hittable, direction: vector): number
	return self.object:probabilityValue(self.origin, direction)
end

function Hittable.generate(self: Hittable): vector
	return self.object:random(self.origin)
end

-- mixture
local Mixture = {}
Mixture.__index = Mixture
export type Mixture = typeof(setmetatable({} :: { p0: any, p1: any }, Mixture))

function Mixture.new(p0: any, p1: any): Mixture
	return setmetatable({ p0 = p0, p1 = p1 }, Mixture)
end

function Mixture.value(self: Mixture, direction: vector): number
	return 0.5 * self.p0:value(direction) + 0.5 * self.p1:value(direction)
end

function Mixture.generate(self: Mixture): vector
	if math.random() < 0.5 then
		return self.p0:generate()
	end

	return self.p1:generate()
end

-- APIs
return {
	Cosine = Cosine,
	Sphere = Sphere,
	Hittable = Hittable,
	Mixture = Mixture,
}
