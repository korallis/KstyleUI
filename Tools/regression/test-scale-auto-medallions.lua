-- test-scale-auto-medallions.lua: the automatic Interface size under the Medallions HUD style, at the same screens as test-scale-auto: one unit is a whole number of sixteenths of a pixel, the size is the step nearest the mock-ups' that fits, the border is one physical pixel, and every preset's Medallions layout, the slab's groups and the hub included, fits at its automatic size.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local UI_HEIGHT = 768

local function New(width, height)
	local env, K = CoreEnv.New({
		width = width, height = height, uiScale = 768 / 1080, size = "auto", fit = true,
		setup = function(e)
			e._physical = { width, height }
			e.GetPhysicalScreenSize = function()
				return e._physical[1], e._physical[2]
			end
		end,
	})
	CoreEnv.Boot(env)
	local profile = K.Store.Profile()
	for _, element in ipairs(K.Setup.Layouts.ELEMENTS) do
		profile[element.module] = profile[element.module] or {}
		profile[element.module].enabled = true
	end
	profile.ActionBars.consumables = { enabled = false }
	K.Callbacks.Fire("ModuleChanged")
	return env, K
end

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

local function whole(v)
	return near(v, math.floor(v + 0.5))
end

for _, frame in ipairs({ "medallion", "ring", "classic" }) do
for _, screen in ipairs({ { 5120, 1440 }, { 3440, 1440 }, { 3840, 1080 }, { 2560, 1440 }, { 1920, 1080 }, { 3840, 2160 }, { 1280, 720 }, { 2383, 1540 }, { 3456, 2234 }, { 1366, 768 } }) do
	local env, K = New(screen[1], screen[2])
	local Scale, Layouts = K.Scale, K.Setup.Layouts
	local label = screen[1] .. "x" .. screen[2] .. " medallions"
	local profile = K.Store.Profile()
	profile.Minimap.frame = frame
	env.RunTimers()
	local ppu = env._physical[2] * Scale.Root():GetEffectiveScale() / UI_HEIGHT
	local size, step, cap = Scale.AppliedUserScale(), Scale.Step(), Scale.MaxUserScale()
	assert(whole(ppu * Scale.STEPS_PER_PIXEL), label .. ": one unit is a whole number of sixteenths of a pixel, got " .. ppu)
	assert(size <= cap + 1e-9, label .. ": the automatic size fits the screen")
	assert(math.abs(size - Scale.MOCKUP_SIZE) <= step / 2 + 1e-9 or size + step > cap + 1e-9, label .. ": the step nearest the mock-ups' size that fits, got " .. size)
	assert(near(Scale.Border() * ppu, 1) and near(Scale.Pixel(1) * ppu, 1), label .. ": the border is exactly one physical pixel")
	local canvas = Scale.CanvasWidth(screen[1], screen[2])
	for _, preset in ipairs({ "DPS", "Tank", "Healer" }) do
		local enabled = Layouts.Enabled(preset, profile)
		local auto = Scale.Auto(screen[2], Layouts.ScaleLimit(canvas, screen[2], preset, enabled))
		assert(Layouts.Fits(preset, canvas, screen[2], auto, enabled, Layouts.Positions(preset, "medallions", Scale.AspectClass(canvas, screen[2]))), label .. " " .. preset .. ": the Medallions layout fits at its automatic size")
	end
	assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
end

end
print("scale auto medallions ok: all three minimap frames")
