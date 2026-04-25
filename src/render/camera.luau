local Vec3 = require("../math/vec3")
local Ray = require("../core/ray")

local Camera = {}
Camera.__index = Camera

export type SceneConfig = {
	vfov: number,
	lookfrom: Vec3.Point3,
	lookat: Vec3.Point3,
	vup: Vec3.Vec3,
	defocusAngle: number,
	focusDist: number,
}

export type RenderConfig = {
	aspectRatio: number,
	imageWidth: number,
	samplesPerPixel: number,
	maxDepth: number,
}

export type Camera = typeof(setmetatable(
	{} :: {
		-- public config
		aspectRatio: number,
		imageWidth: number,
		samplesPerPixel: number,
		maxDepth: number,
		vfov: number,
		lookfrom: Vec3.Point3,
		lookat: Vec3.Point3,
		vup: Vec3.Vec3,
		defocusAngle: number,
		focusDist: number,

		-- derived
		imageHeight: number,
		pixelSamplesScale: number,
		center: Vec3.Point3,
		pixel00Loc: Vec3.Point3,
		pixelDeltaU: Vec3.Vec3,
		pixelDeltaV: Vec3.Vec3,
		u: Vec3.Vec3,
		v: Vec3.Vec3,
		w: Vec3.Vec3,
		defocusDiskU: Vec3.Vec3,
		defocusDiskV: Vec3.Vec3,
	},
	Camera
))

local function initialize(self: Camera)
	self.imageHeight = math.max(1, math.floor(self.imageWidth / self.aspectRatio))
	self.pixelSamplesScale = 1.0 / self.samplesPerPixel
	self.center = self.lookfrom

	local h = math.tan(math.rad(self.vfov) / 2)
	local viewportHeight = 2 * h * self.focusDist
	local viewportWidth = viewportHeight * (self.imageWidth / self.imageHeight)

	self.w = Vec3.unitVector(self.lookfrom - self.lookat)
	self.u = Vec3.unitVector(Vec3.cross(self.vup, self.w))
	self.v = Vec3.cross(self.w, self.u)

	local viewportU = viewportWidth * self.u
	local viewportV = viewportHeight * -self.v

	self.pixelDeltaU = viewportU / self.imageWidth
	self.pixelDeltaV = viewportV / self.imageHeight

	local viewportUpperLeft = self.center - self.focusDist * self.w - viewportU / 2 - viewportV / 2
	self.pixel00Loc = viewportUpperLeft + 0.5 * (self.pixelDeltaU + self.pixelDeltaV)

	local defocusRadius = self.focusDist * math.tan(math.rad(self.defocusAngle / 2))
	self.defocusDiskU = self.u * defocusRadius
	self.defocusDiskV = self.v * defocusRadius
end

function Camera.new(scene: SceneConfig, render: RenderConfig): Camera
	local self = setmetatable({
		vfov = scene.vfov,
		lookfrom = scene.lookfrom,
		lookat = scene.lookat,
		vup = scene.vup,
		defocusAngle = scene.defocusAngle,
		focusDist = scene.focusDist,
		aspectRatio = render.aspectRatio,
		imageWidth = render.imageWidth,
		samplesPerPixel = render.samplesPerPixel,
		maxDepth = render.maxDepth,
		imageHeight = 0,
		pixelSamplesScale = 0,
		center = Vec3.new(0, 0, 0),
		pixel00Loc = Vec3.new(0, 0, 0),
		pixelDeltaU = Vec3.new(0, 0, 0),
		pixelDeltaV = Vec3.new(0, 0, 0),
		u = Vec3.new(0, 0, 0),
		v = Vec3.new(0, 0, 0),
		w = Vec3.new(0, 0, 0),
		defocusDiskU = Vec3.new(0, 0, 0),
		defocusDiskV = Vec3.new(0, 0, 0),
	}, Camera)

	initialize(self)

	return self
end

function Camera.sampleSquare(): Vec3.Vec3
	return Vec3.new(math.random() - 0.5, math.random() - 0.5, 0)
end

function Camera.defocusDiskSample(self: Camera): Vec3.Point3
	local p = Vec3.randomInUnitDisk()

	return self.center + p.x * self.defocusDiskU + p.y * self.defocusDiskV
end

function Camera.getRay(self: Camera, i: number, j: number): Ray.Ray
	local offset = Camera.sampleSquare()
	local pixelSample = self.pixel00Loc + ((i + offset.x) * self.pixelDeltaU) + ((j + offset.y) * self.pixelDeltaV)
	local origin = if self.defocusAngle <= 0 then self.center else self:defocusDiskSample()

	return Ray.new(origin, pixelSample - origin)
end

return Camera
