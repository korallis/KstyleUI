local AB = dofile("Tools/regression/actionbars_env.lua")
local env, K, ns = AB.New({ class = "WARLOCK" })
AB.Enable(env, K)
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
local hub = ns.Slab.hub
assert(hub.shock:GetAlpha() == 0, "recoloring must not revive the dormant shock ring")
assert(hub.flash:GetAlpha() == 0, "recoloring must not revive the dormant square flash")
assert(hub.glyphs:GetAlpha() == 0.6, "glyph recoloring keeps its resting opacity")
ns.Slab.Refresh()
assert(hub.shock:GetAlpha() == 0 and hub.flash:GetAlpha() == 0, "refresh preserves dormant effects")
for _, sweep in ipairs(ns.Slab.frame.sweeps) do
	assert(sweep:GetAlpha() == 0, "recoloring preserves the dormant combat sweep")
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("Medallions client paint passed")
