-- test-property-pixels.lua: at random screens and Interface sizes, the pixel-perfect helpers agree with the screen: a pixel is one physical pixel, Scale.Snap, Layout's Align and SnapSize and Widgets.Snap land on whole physical pixels and snap a snapped value to itself, a positive size never snaps below one pixel, and the size steps (Scale.Nearest) are whole steps that snap to themselves inside the allowed range.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Property = dofile("Tools/regression/property_lib.lua")

local EPS = 1e-6
local screen = { 1920, 1080 }
local env, K = CoreEnv.New({
	width = 1920, height = 1080, uiScale = 768 / 1080, size = "auto", fit = true,
	setup = function(e)
		e.GetPhysicalScreenSize = function()
			return screen[1], screen[2]
		end
	end,
})
CoreEnv.Boot(env)
local Scale, Widgets, G = K.Scale, K.Widgets, K.Layout.Geometry
local frame = env.CreateFrame("Frame", nil, Scale.Root())

local function Whole(v)
	return math.abs(v - math.floor(v + 0.5)) < EPS
end

local function Generate(g)
	local height = g:int(600, 2160)
	local values = {}
	for i = 1, 12 do
		values[i] = g:bool(0.25) and g:float(-2, 2) or g:float(-3000, 3000)
	end
	values[#values + 1] = g:float(0, 0.5) * 1e-3
	return {
		width = math.min(7680, math.max(800, math.floor(height * g:float(4 / 3, 32 / 9) + 0.5))), height = height,
		size = (not g:bool(0.3)) and g:float(0.5, 1.6) or nil, frameScale = g:float(0.5, 2), maximum = g:float(0.4, 1.6),
		values = values,
	}
end

local function Holds(c)
	local out = {}
	local function Fail(text, ...)
		out[#out + 1] = string.format(text, ...)
	end
	screen[1], screen[2] = c.width, c.height
	Scale.SetAuto(c.size == nil)
	if c.size then
		Scale.SetUserScale(c.size)
	end
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	frame:SetScale(c.frameScale)
	local pixel = Scale.Pixel(1)
	local physical = pixel * Scale.Root():GetEffectiveScale() * c.height / 768
	if math.abs(physical - 1) > EPS then
		Fail("Scale.Pixel(1) is %.9f physical pixels, not 1", physical)
	end
	if pixel <= 0 or Scale.Snap(pixel) ~= pixel or Scale.Border() ~= pixel then
		Fail("one pixel (%.9g units) does not snap to itself or the border differs: Snap %.9g, Border %.9g", pixel, Scale.Snap(pixel), Scale.Border())
	end
	local f = Widgets.ScaleFactor(frame)
	local small = Widgets.Snap(frame, pixel / f)
	if small <= 0 or not Whole(small * f / pixel) then
		Fail("Widgets.Snap of one pixel on a frame at scale %.4f gives %.9g units, %.6f px", f, small, small * f / pixel)
	end
	if Scale.TextFloor() < 1 then
		Fail("the text floor is %s, below 1", tostring(Scale.TextFloor()))
	end
	for _, v in ipairs(c.values) do
		local s = Scale.Snap(v)
		if Scale.Snap(s) ~= s or not Whole(s / pixel) or math.abs(s - v) > pixel / 2 + EPS then
			Fail("Scale.Snap(%.9g) = %.9g: not a whole pixel, not stable or more than half a pixel away", v, s)
		end
		local a = G.Align(v, pixel)
		if G.Align(a, pixel) ~= a or not Whole(a / pixel) then
			Fail("Geometry.Align(%.9g) = %.9g is not a stable whole pixel", v, a)
		end
		local w = Widgets.Snap(frame, v)
		if math.abs(Widgets.Snap(frame, w) - w) > EPS * pixel or not Whole(w * f / pixel) then
			Fail("Widgets.Snap(%.9g) at frame scale %.4f = %.9g is not a stable whole pixel", v, f, w)
		end
		local size = math.abs(v)
		if size > 0 then
			local z = G.SnapSize(size, f, pixel)
			if z * f / pixel < 1 - EPS or not Whole(z * f / pixel) or math.abs(G.SnapSize(z, f, pixel) - z) > EPS * pixel then
				Fail("Geometry.SnapSize(%.9g) at frame scale %.4f = %.9g: below one pixel, not whole or not stable", size, f, z)
			end
		end
	end
	local step = Scale.Step()
	local applied = Scale.AppliedUserScale()
	if not Whole(applied / step) then
		Fail("the applied size %.9g is %.6f steps of %.9g", applied, applied / step, step)
	end
	for _, request in ipairs({ c.size or 1, c.values[1] / 1000 + 1 }) do
		local n = Scale.Nearest(request, c.height, c.maximum)
		local low = math.ceil(Scale.MIN_USER_SCALE / step - 1e-9) * step
		if not Whole(n / step) or Scale.Nearest(n, c.height, c.maximum) ~= n then
			Fail("Scale.Nearest(%.9g) = %.9g is not a stable whole step of %.9g", request, n, step)
		elseif n < low - EPS or (n > c.maximum + EPS and n > low + EPS) then
			Fail("Scale.Nearest(%.9g) = %.9g is outside %.9g to the maximum %.9g", request, n, low, c.maximum)
		end
	end
	if #env._errors > 0 then
		Fail("raised: %s", tostring(env._errors[1]))
	end
	return #out == 0, out
end

Property.Check({
	name = "pixel scale",
	script = "Tools/regression/test-property-pixels.lua",
	iterations = 100,
	generate = Generate,
	show = function(c)
		return string.format("%dx%d, size %s, frame scale %.4f, maximum %.4f, values %s", c.width, c.height, c.size and string.format("%.4f", c.size) or "automatic",
			c.frameScale, c.maximum, Property.Describe(c.values))
	end,
	property = Holds,
})
