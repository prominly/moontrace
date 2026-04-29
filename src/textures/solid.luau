local types = require("./types")

local Solid = {}
Solid.__index = Solid

export type Solid = typeof(setmetatable({} :: { color: vector }, Solid))

function Solid.new(color: vector): types.Texture
	return setmetatable({ color = color }, Solid) :: any
end

function Solid.value(self: Solid, _u: number, _v: number, _p: vector): vector
	return self.color
end

return Solid
