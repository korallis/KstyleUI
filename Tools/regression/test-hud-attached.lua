-- test-hud-attached.lua: cooldowns use attached defaults, retain custom positions and offer the previous placement.
local C = dofile("Tools/regression/cooldowns_env.lua")
local env, K, ns = C.New({ cooldowns = C.Sample() })
C.Enable(env, K)
assert(K.Store.Module("Cooldowns").attached == true, "Cooldowns needs an attached placement setting, on by default")
for _, style in ipairs({ "frames", "orbs", "medallions" }) do
	K.Options.Write("HudStyle", "style", style)
	env.RunTimers()
	local L = K.Setup.Layouts
	for _, count in ipairs({1,3,6,12}) do
		local p = L.Place("DPS", style, K.Scale.Aspect(), "cooldowns.essential")
		local cast = L.Place("DPS", style, K.Scale.Aspect(), "unitframes.castbar.player")
		assert(math.abs(p.y - cast.y) < 100, style .. ": attach essential cooldowns to the cast area")
		local cfg = ns.Settings.current.essential
		assert(ns.Grid.Capacity(cfg) >= count, "default essential grid must accommodate twelve icons")
		local x1 = ns.Grid.Offset(1, count, cfg)
		local xn = ns.Grid.Offset(math.min(count, cfg.columns), count, cfg)
		local width = ns.Grid.Size(cfg)
		assert(math.abs((x1 + xn + cfg.size) / 2 - width / 2) < 0.01, "short rows grow from a fixed centre")
	end
end
K.Options.Write("HudStyle", "style", "medallions")
K.Layout.Update("cooldowns.essential", {anchor="BOTTOM", x=-470, y=260}, true)
K.Options.Write("Cooldowns", "attached", false)
env.RunTimers()
assert(K.Layout.Get("cooldowns.essential").x == -470, "the placement toggle preserves a custom position")
K.Layout.Reset("cooldowns.essential")
assert(math.abs(K.Layout.Get("cooldowns.essential").y - K.Setup.Layouts.Default("cooldowns.essential").y) < 1, "off restores today's placement")
assert(#env._errors == 0, tostring(env._errors[1]))
print("attached cooldown defaults, 1/3/6/12 icons, legacy option and custom positions ok")
