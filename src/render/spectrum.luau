--!strict
--!optimize 2
--!native

local spectrum = {}

-- visible spectrum (nm)
-- http://www.midnightkite.com/color.html
local LAMBDA_MIN = 380
local LAMBDA_MAX = 780
local LAMBDA_RANGE = LAMBDA_MAX - LAMBDA_MIN

-- Bruton's piecewise band edges (nm)
local VIOLET_BLUE = 440
local BLUE_CYAN = 490
local CYAN_GREEN = 510
local GREEN_YELLOW = 580
local YELLOW_RED = 645

-- eye-sensitivity envelope
local FADE_IN_END = 420
local FADE_OUT_START = 700
local EDGE_INTENSITY = 0.3

local function rawRgb(lam: number): (number, number, number)
	local r, g, b

	if lam < VIOLET_BLUE then
		r = (VIOLET_BLUE - lam) / (VIOLET_BLUE - LAMBDA_MIN)
		g = 0
		b = 1
	elseif lam < BLUE_CYAN then
		r = 0
		g = (lam - VIOLET_BLUE) / (BLUE_CYAN - VIOLET_BLUE)
		b = 1
	elseif lam < CYAN_GREEN then
		r = 0
		g = 1
		b = (CYAN_GREEN - lam) / (CYAN_GREEN - BLUE_CYAN)
	elseif lam < GREEN_YELLOW then
		r = (lam - CYAN_GREEN) / (GREEN_YELLOW - CYAN_GREEN)
		g = 1
		b = 0
	elseif lam < YELLOW_RED then
		r = 1
		g = (YELLOW_RED - lam) / (YELLOW_RED - GREEN_YELLOW)
		b = 0
	else
		r = 1
		g = 0
		b = 0
	end

	local intensity
	if lam < FADE_IN_END then
		intensity = EDGE_INTENSITY + (1 - EDGE_INTENSITY) * (lam - LAMBDA_MIN) / (FADE_IN_END - LAMBDA_MIN)
	elseif lam < FADE_OUT_START then
		intensity = 1
	else
		intensity = EDGE_INTENSITY + (1 - EDGE_INTENSITY) * (LAMBDA_MAX - lam) / (LAMBDA_MAX - FADE_OUT_START)
	end

	return r * intensity, g * intensity, b * intensity
end

-- normalize so uniform sampling over the visible range averages to vector.one
-- (1 nm steps over [LAMBDA_MIN, LAMBDA_MAX] inclusive)
local NORMALIZE: vector
do
	local samples = LAMBDA_RANGE + 1
	local sumR, sumG, sumB = 0, 0, 0

	for i = 0, samples - 1 do
		local lam = LAMBDA_MIN + i
		local r, g, b = rawRgb(lam)

		sumR += r
		sumG += g
		sumB += b
	end

	NORMALIZE = vector.create(samples / sumR, samples / sumG, samples / sumB)
end

function spectrum.sampleWavelength(u: number?): number
	return LAMBDA_MIN + (u or math.random()) * LAMBDA_RANGE
end

function spectrum.wavelengthToRgb(lam: number): vector
	local r, g, b = rawRgb(lam)

	return vector.create(r, g, b) * NORMALIZE
end

-- Cauchy's equation
local NM_TO_UM = 1e-3

function spectrum.cauchyIor(wavelengthNm: number, baseN: number, dispersionB: number): number
	local lamUm = wavelengthNm * NM_TO_UM

	return baseN + dispersionB / (lamUm * lamUm)
end

return spectrum
