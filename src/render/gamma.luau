--!strict
--!optimize 2
--!native

local gamma = {}

local function linearToGamma(x: number): number
	return if x > 0 then math.sqrt(x) else 0
end

function gamma.channelToByte(x: number): number
	-- clamp to [0, 0.999] so floor(256 * g) never overflows to 256
	return math.floor(256 * math.clamp(linearToGamma(x), 0.0, 0.999))
end

gamma.linearToGamma = linearToGamma

return gamma
