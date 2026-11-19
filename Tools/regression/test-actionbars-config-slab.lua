-- test-actionbars-config-slab.lua: unequal slab sides keep the hub gap and the experience strip inside the slab.
local AB = dofile("Tools/regression/actionbars_env.lua")
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = AB.New({ width = screen[1], height = screen[2] })
	AB.Enable(env, K)
	K.Options.Write("HudStyle", "style", "medallions")
	local strip = env.CreateFrame("Frame", nil, K.Scale.Root())
	K.Layout.Register(strip, "databars.xp", K.Setup.Layouts.Default("databars.xp"), { resizable = true })
	for _, size in ipairs({ 16, 40, 64 }) do
		K.Options.Write("ActionBars", "bar1.size", size)
		K.Options.Write("ActionBars", "bar1.buttons", 6)
		K.Options.Write("ActionBars", "bar2.buttons", 9)
		K.Layout.Restore("databars.xp")
		local pixel = 2 * K.Scale.Pixel(1) / K.Widgets.ScaleFactor(ns.bars.bar1.header)
		local gap = ns.bars.bar2.holder:GetLeft() - ns.bars.bar1.holder:GetRight()
		assert(math.abs(gap - K.Setup.Layouts.MEDALLIONS_HUB_GAP) <= pixel, "configured slab sides preserve the hub gap")
		assert(strip:GetLeft() >= ns.Slab.frame:GetLeft() - pixel and strip:GetRight() <= ns.Slab.frame:GetRight() + pixel, "the experience strip fits asymmetric slab sides")
		assert(ns.Slab.frame:IsShown() and ns.Slab.hub:IsShown(), "configured slab and hub remain connected")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end
print("ok configurable slab and experience strip")
