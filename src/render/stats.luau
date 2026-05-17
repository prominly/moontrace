--!strict
--!optimize 2
--!native

local Vec3 = require("../math/vec3")

local stats = {}

export type Options = {
	clampDirect: number,
	clampIndirect: number,
}

export type Stats = {
	maxDirectLuminance: number,
	maxDirectX: number,
	maxDirectY: number,
	maxDirectSample: number,
	maxDirectDepth: number,
	maxIndirectLuminance: number,
	maxIndirectX: number,
	maxIndirectY: number,
	maxIndirectSample: number,
	maxIndirectDepth: number,
	maxSampleLuminance: number,
	maxSampleX: number,
	maxSampleY: number,
	maxSampleSample: number,
	directClamped: number,
	indirectClamped: number,
	directTests: number,
	indirectTests: number,
}

export type Context = {
	pixelX: number,
	pixelY: number,
	sampleIndex: number,
}

function stats.new(): Stats
	return {
		maxDirectLuminance = 0,
		maxDirectX = -1,
		maxDirectY = -1,
		maxDirectSample = 0,
		maxDirectDepth = 0,
		maxIndirectLuminance = 0,
		maxIndirectX = -1,
		maxIndirectY = -1,
		maxIndirectSample = 0,
		maxIndirectDepth = 0,
		maxSampleLuminance = 0,
		maxSampleX = -1,
		maxSampleY = -1,
		maxSampleSample = 0,
		directClamped = 0,
		indirectClamped = 0,
		directTests = 0,
		indirectTests = 0,
	}
end

local function clampLuminanceWithY(v: vector, limit: number, y: number): (vector, boolean)
	if y <= limit or y <= 0 then
		return v, false
	end

	return v * (limit / y), true
end

function stats.recordDirectContribution(
	v: vector,
	limit: number,
	stats: Stats?,
	context: Context?,
	depth: number
): vector
	if not stats and limit <= 0 then
		return v
	end

	local y = Vec3.luminance(v)

	if stats then
		stats.directTests += 1

		if y > stats.maxDirectLuminance then
			stats.maxDirectLuminance = y
			stats.maxDirectDepth = depth

			if context then
				stats.maxDirectX = context.pixelX
				stats.maxDirectY = context.pixelY
				stats.maxDirectSample = context.sampleIndex
			end
		end
	end

	if limit <= 0 then
		return v
	end

	local clamped
	v, clamped = clampLuminanceWithY(v, limit, y)

	if stats and clamped then
		stats.directClamped += 1
	end

	return v
end

function stats.recordIndirectContribution(
	v: vector,
	limit: number,
	stats: Stats?,
	context: Context?,
	depth: number
): vector
	if not stats and limit <= 0 then
		return v
	end

	local y = Vec3.luminance(v)

	if stats then
		stats.indirectTests += 1

		if y > stats.maxIndirectLuminance then
			stats.maxIndirectLuminance = y
			stats.maxIndirectDepth = depth

			if context then
				stats.maxIndirectX = context.pixelX
				stats.maxIndirectY = context.pixelY
				stats.maxIndirectSample = context.sampleIndex
			end
		end
	end

	if limit <= 0 then
		return v
	end

	local clamped
	v, clamped = clampLuminanceWithY(v, limit, y)

	if stats and clamped then
		stats.indirectClamped += 1
	end

	return v
end

function stats.recordFinalSample(stats: Stats, color: vector, pixelX: number, pixelY: number, sampleIndex: number)
	local y = Vec3.luminance(color)

	if y > stats.maxSampleLuminance then
		stats.maxSampleLuminance = y
		stats.maxSampleX = pixelX
		stats.maxSampleY = pixelY
		stats.maxSampleSample = sampleIndex
	end
end

function stats.merge(target: Stats, source: Stats)
	target.directClamped += source.directClamped
	target.indirectClamped += source.indirectClamped
	target.directTests += source.directTests
	target.indirectTests += source.indirectTests

	if source.maxDirectLuminance > target.maxDirectLuminance then
		target.maxDirectLuminance = source.maxDirectLuminance
		target.maxDirectX = source.maxDirectX
		target.maxDirectY = source.maxDirectY
		target.maxDirectSample = source.maxDirectSample
		target.maxDirectDepth = source.maxDirectDepth
	end

	if source.maxIndirectLuminance > target.maxIndirectLuminance then
		target.maxIndirectLuminance = source.maxIndirectLuminance
		target.maxIndirectX = source.maxIndirectX
		target.maxIndirectY = source.maxIndirectY
		target.maxIndirectSample = source.maxIndirectSample
		target.maxIndirectDepth = source.maxIndirectDepth
	end

	if source.maxSampleLuminance > target.maxSampleLuminance then
		target.maxSampleLuminance = source.maxSampleLuminance
		target.maxSampleX = source.maxSampleX
		target.maxSampleY = source.maxSampleY
		target.maxSampleSample = source.maxSampleSample
	end
end

function stats.percent(count: number, total: number): number
	if total <= 0 then
		return 0
	end

	return count * 100 / total
end

function stats.formatContributionMax(
	luminance: number,
	x: number,
	y: number,
	sampleIndex: number,
	depth: number
): string
	if x < 0 or y < 0 then
		return string.format("%.3f", luminance)
	end

	return string.format("%.3f at (%d, %d), sample %d, depth %d", luminance, x, y, sampleIndex, depth)
end

function stats.formatSampleMax(luminance: number, x: number, y: number, sampleIndex: number): string
	if x < 0 or y < 0 then
		return string.format("%.3f", luminance)
	end

	return string.format("%.3f at (%d, %d), sample %d", luminance, x, y, sampleIndex)
end

return stats
