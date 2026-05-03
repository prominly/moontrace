--!strict
--!optimize 2
--!native

local ONB = {}
ONB.__index = ONB

export type ONB = typeof(setmetatable({} :: { u: vector, v: vector, w: vector }, ONB))

function ONB.new(n: vector): ONB
	local w = vector.normalize(n)
	local a = if math.abs(w.x) > 0.9 then vector.create(0, 1, 0) else vector.create(1, 0, 0)
	local v = vector.normalize(vector.cross(w, a))
	local u = vector.cross(w, v)

	return setmetatable({ u = u, v = v, w = w }, ONB)
end

function ONB.transform(self: ONB, localDir: vector): vector
	return localDir.x * self.u + localDir.y * self.v + localDir.z * self.w
end

return ONB
