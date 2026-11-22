-- test-actionbars-split.lua: bar 2 as two groups of six: the Split in two setting off the Medallions slab, the gap between the halves, the holder that grows by it, the slab that keeps both bars whole, and the Frames tray.
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

do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	local bar1, bar2 = ns.bars.bar1, ns.bars.bar2
	assert(ns.Config("bar2").split == "off" and ns.Config("bar1").split == "off", "both bars start unsplit")
	assert(near(Split(bar2), 0) and near(Split(bar1), 0), "on the slab both bars are one row of twelve")
	K.Options.Write("ActionBars", "bar2.split", "on")
	assert(near(Split(bar2), 0), "the slab keeps bar 2 whole even when Always is chosen")
	K.Options.Write("ActionBars", "slab", false)
	local gap = K.Widgets.Snap(bar2.header, K.Setup.Layouts.SPLIT_GAP)
	assert(near(Split(bar2), gap), "off the slab, Always parts bar 2 into two groups of six, got " .. Split(bar2))
	assert(near(Split(bar1), 0), "bar 1 stays one row")
	assert(near(x(bar2.buttons[1]), 0) and x(bar2.buttons[12]) > x(bar2.buttons[7]), "each half keeps its order")
	local split = bar2.holder:GetWidth()
	K.Options.Write("ActionBars", "bar2.split", "off")
	local whole = bar2.holder:GetWidth()
	assert(near(Split(bar2), 0), "Never keeps the row whole")
	assert(near(split, whole + gap), "the holder grows by the gap: " .. split .. " vs " .. whole .. " + " .. gap)
	K.Options.Write("ActionBars", "bar1.split", "on")
	assert(near(Split(bar1), K.Widgets.Snap(bar1.header, K.Setup.Layouts.SPLIT_GAP)), "Always splits bar 1 too")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	K.Options.Write("HudStyle", "style", "frames")
	K.Options.Write("ActionBars", "trayColumn", false)
	local bar2 = ns.bars.bar2
	assert(ns.Tray.card and ns.Tray.card:IsShown(), "under Frames the tray stands behind bars 1 and 2")
	assert(near(Split(bar2), 0), "under Frames bar 2 is one row of twelve, got " .. Split(bar2))
	K.Options.Write("ActionBars", "bar2.split", "on")
	assert(near(Split(bar2), K.Widgets.Snap(bar2.header, K.Setup.Layouts.SPLIT_GAP)), "Always parts bar 2 under Frames, got " .. Split(bar2))
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("ok actionbars split")
