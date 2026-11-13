-- test-actionbars-split.lua: bar 2 as two groups of six: the Split in two setting (with the Orbs HUD style, always or never), the gap between the halves, the holder that grows by it, and the live switch.
local AB = dofile("Tools/regression/actionbars_env.lua")

local function near(a, b, eps)
	return math.abs(a - b) < (eps or 2)
end

local function x(button)
	local _, _, _, left = button:GetPoint(1)
	return left
end

-- Split(bar) -> the gap between buttons 6 and 7 less the pitch between buttons 5 and 6; 0 when the row is whole.
local function Split(bar)
	local pitch = x(bar.buttons[6]) - x(bar.buttons[5])
	return x(bar.buttons[7]) - x(bar.buttons[6]) - pitch
end

local function Style(K, style)
	K.Options.Write("HudStyle", "style", style)
	assert(K.HudStyle.Current() == style, "the HUD style is " .. style)
end

do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	local bar1, bar2 = ns.bars.bar1, ns.bars.bar2
	assert(ns.Config("bar2").split == "auto" and ns.Config("bar1").split == "off", "bar 2 splits with the Orbs style, bar 1 never")
	local whole = bar2.holder:GetWidth()
	assert(ns.Tray.card and ns.Tray.card:IsShown(), "under Frames the Frames tray stands behind bars 1 and 2")
	assert(near(Split(bar2), 0), "under Frames bar 2 is one row of twelve, got " .. Split(bar2))
	Style(K, "orbs")
	local gap = K.Widgets.Snap(bar2.header, K.Setup.Layouts.SPLIT_GAP)
	assert(near(Split(bar2), gap), "under Orbs bar 2 parts into two groups of six, got " .. Split(bar2))
	assert(near(bar2.holder:GetWidth(), whole + gap), "the holder grows by the gap: " .. bar2.holder:GetWidth() .. " vs " .. whole .. " + " .. gap)
	assert(near(Split(bar1), 0), "bar 1 stays one row")
	assert(not ns.Tray.card:IsShown(), "under Orbs the Frames tray is hidden; the forged tray takes its place")
	assert(near(x(bar2.buttons[1]), 0) and x(bar2.buttons[12]) > x(bar2.buttons[7]), "each half keeps its order")
	local settings = K.Layout.Get("actionbars.bar2")
	local orbs = K.Setup.Layouts.Style("orbs", "DPS", "actionbars.bar2")
	assert(near(settings.scale, orbs.scale) and near(settings.y, orbs.y), "bar 2 stands at its Orbs place and scale")
	K.Options.Write("ActionBars", "bar2.split", "off")
	assert(near(Split(bar2), 0) and near(bar2.holder:GetWidth(), whole), "Never keeps the row whole under Orbs")
	K.Options.Write("ActionBars", "bar2.split", "auto")
	Style(K, "frames")
	assert(near(Split(bar2), 0) and near(bar2.holder:GetWidth(), whole), "back to Frames, bar 2 is whole again")
	K.Options.Write("ActionBars", "bar1.split", "on")
	assert(near(Split(bar1), K.Widgets.Snap(bar1.header, K.Setup.Layouts.SPLIT_GAP)), "Always splits under Frames too")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- In combat the switch waits: the bars keep their layout until combat ends, then split.
do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	local bar2 = ns.bars.bar2
	env.SetCombat(true)
	K.Options.Write("HudStyle", "style", "orbs")
	assert(K.HudStyle.Current() == "frames", "the style waits for combat to end")
	assert(near(Split(bar2), 0), "bar 2 is not re-laid in combat")
	env.SetCombat(false)
	assert(K.HudStyle.Current() == "orbs" and Split(bar2) > 100, "after combat bar 2 splits")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A login under Orbs lays bar 2 out at its Orbs scale, as the live switch does: the same holder, the same button
-- places, every button on whole physical pixels.
do
	local function Shape(K, bar)
		local f, pixel = K.Widgets.ScaleFactor(bar.header), K.Scale.Pixel(1)
		local out = { width = bar.holder:GetWidth(), scale = bar.holder:GetScale() }
		for i = 1, 12 do
			local left = x(bar.buttons[i])
			out[i] = left
			local steps = left * f / pixel
			assert(math.abs(steps - math.floor(steps + 0.5)) < 1e-6, "button " .. i .. " of bar 2 starts on a whole pixel, at " .. steps)
		end
		local steps = out.width * f / pixel
		assert(math.abs(steps - math.floor(steps + 0.5)) < 1e-6, "bar 2 is a whole number of pixels wide, got " .. steps)
		return out
	end
	local liveEnv, liveK, liveNs = AB.New({ width = 5120, height = 1440 })
	AB.Enable(liveEnv, liveK)
	Style(liveK, "orbs")
	liveEnv.RunTimers()
	local env, K, ns = AB.New({ width = 5120, height = 1440 })
	Style(K, "orbs")
	AB.Enable(env, K)
	local login = Shape(K, ns.bars.bar2)
	local live = Shape(liveK, liveNs.bars.bar2)
	assert(near(login.scale, live.scale, 1e-6) and login.scale < 0.85, "bar 2 takes its Orbs scale both ways")
	assert(near(login.width, live.width, 1e-6), "a login lays bar 2 as wide as a live switch: " .. login.width .. " vs " .. live.width)
	for i = 1, 12 do
		assert(near(login[i], live[i], 1e-6), "button " .. i .. " stands where the live switch puts it: " .. login[i] .. " vs " .. live[i])
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
	assert(#liveEnv._errors == 0 and liveK.ErrorCount() == 0, AB.Errors(liveEnv))
end

print("ok actionbars split")
