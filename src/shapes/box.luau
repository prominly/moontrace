--!strict
--!optimize 2
--!native

local Quad = require("./quad")
local HittableList = require("../core/hittable_list")
local hittable = require("../core/hittable")

local Box = {}

function Box.new(a: vector, b: vector, material: hittable.Material): hittable.Hittable
	local sides = HittableList.new()

	local mn = vector.create(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z))
	local mx = vector.create(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))

	local dx = vector.create(mx.x - mn.x, 0, 0)
	local dy = vector.create(0, mx.y - mn.y, 0)
	local dz = vector.create(0, 0, mx.z - mn.z)

	sides:add(Quad.new(vector.create(mn.x, mn.y, mx.z), dx, dy, material)) -- front
	sides:add(Quad.new(vector.create(mx.x, mn.y, mx.z), -dz, dy, material)) -- right
	sides:add(Quad.new(vector.create(mx.x, mn.y, mn.z), -dx, dy, material)) -- back
	sides:add(Quad.new(vector.create(mn.x, mn.y, mn.z), dz, dy, material)) -- left
	sides:add(Quad.new(vector.create(mn.x, mx.y, mx.z), dx, -dz, material)) -- top
	sides:add(Quad.new(vector.create(mn.x, mn.y, mn.z), dx, dz, material)) -- bottom

	return sides :: any
end

return Box
