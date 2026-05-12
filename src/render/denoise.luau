-- Edge-Avoiding À-Trous Wavelet Transform for fast Global Illumination Filtering
-- https://jo.dreggn.org/home/2010_atrous.pdf

local denoise = {}

local KERNEL = { 1 / 16, 4 / 16, 6 / 16, 4 / 16, 1 / 16 }
local ITERATIONS = 5
local SIGMA_C_SQ = 0.225 * 0.225 -- 0.45 * 0.45
local SIGMA_N_SQ = 0.175 * 0.175 -- 0.35 * 0.35
local SIGMA_A_SQ = 0.100 * 0.100 -- 0.2 * 0.2

local ALBEDO_EPS = 0.01

local function clampedAlbedo(al: vector): vector
	return vector.create(math.max(al.x, ALBEDO_EPS), math.max(al.y, ALBEDO_EPS), math.max(al.z, ALBEDO_EPS))
end

local function clamp(v: number, lo: number, hi: number): number
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end

	return v
end

local function pass(
	input: { vector },
	albedo: { vector },
	normal: { vector },
	output: { vector },
	width: number,
	height: number,
	stepSize: number
)
	for j = 0, height - 1 do
		local rowBase = j * width
		for i = 0, width - 1 do
			local center = rowBase + i + 1
			local cp = input[center]
			local np = normal[center]
			local ap = albedo[center]

			local sum = vector.zero
			local weight = 0

			for dv = -2, 2 do
				local jq = clamp(j + dv * stepSize, 0, height - 1)
				local rowQ = jq * width
				local kv = KERNEL[dv + 3]

				for du = -2, 2 do
					local iq = clamp(i + du * stepSize, 0, width - 1)
					local q = rowQ + iq + 1

					local cq = input[q]
					local nq = normal[q]
					local aq = albedo[q]

					local dc = cp - cq
					local dn = np - nq
					local da = ap - aq

					local wc = math.exp(-vector.dot(dc, dc) / SIGMA_C_SQ)
					local wn = math.exp(-vector.dot(dn, dn) / SIGMA_N_SQ)
					local wa = math.exp(-vector.dot(da, da) / SIGMA_A_SQ)

					local w = KERNEL[du + 3] * kv * wc * wn * wa
					sum += cq * w
					weight += w
				end
			end

			output[center] = if weight > 0 then sum / weight else cp
		end
	end
end

function denoise.atrous(
	color: { vector },
	albedo: { vector },
	normal: { vector },
	width: number,
	height: number
): { vector }
	local pixelCount = width * height
	local a = table.create(pixelCount) :: { vector }
	local b = table.create(pixelCount) :: { vector }

	for i = 1, pixelCount do
		a[i] = color[i] / clampedAlbedo(albedo[i])
	end

	local input: { vector } = a
	local output: { vector } = b
	for k = 0, ITERATIONS - 1 do
		local stepSize = 2 ^ k

		pass(input, albedo, normal, output, width, height, stepSize)
		input, output = output, input
	end

	for i = 1, pixelCount do
		input[i] = input[i] * clampedAlbedo(albedo[i])
	end

	return input
end

return denoise
