--!strict
--!optimize 2
--!native

local Solid = require("./solid")
local types = require("./types")

local Checker = {}
Checker.__index = Checker

export type Checker = typeof(setmetatable(
	{} :: {
		even: types.Texture,
		odd: types.Texture,
		frequency: number,
	},
	Checker
))

local function textureFrom(input: vector | types.Texture): types.Texture
	if typeof(input) == "vector" then
		return Solid.new(input :: vector)
	end

	return input :: types.Texture
end

function Checker.new(even: vector | types.Texture, odd: vector | types.Texture, frequency: number?): types.Texture
	return setmetatable({
		even = textureFrom(even),
		odd = textureFrom(odd),
		frequency = math.max(1, frequency or 8),
	}, Checker) :: any
end

function Checker.value(self: Checker, u: number, v: number, p: vector): vector
	local iu = math.floor(u * self.frequency)
	local iv = math.floor(v * self.frequency)

	if (iu + iv) % 2 == 0 then
		return self.even:value(u, v, p)
	end

	return self.odd:value(u, v, p)
end

return Checker
