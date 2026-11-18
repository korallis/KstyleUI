-- test-medallions-client-paint.lua: repainting preserves the client texture alpha and keeps dormant hub effects hidden.
local AB = dofile("Tools/regression/actionbars_env.lua")
local env, K, ns = AB.New({ class = "WARLOCK" })
K.Store.Module("ActionBars").hubAlpha = true
AB.Enable(env, K)
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
local hub = ns.Slab.hub
local function check()
	assert(hub.shock:GetAlpha() == 0 and hub.flash:GetAlpha() == 0, "preserve dormant shock and flash alpha while recoloring")
	assert(math.abs(hub.glyphs:GetAlpha() - 0.35) < 1e-6, "preserve the glyphs' designed opacity")
	assert(math.abs(hub.runes:GetAlpha() - 0.25) < 1e-6, "preserve the runes' designed opacity")
	for _, particle in ipairs(hub.particles) do assert(particle:GetAlpha() == 0, "recoloring must not revive resting particles") end
	for _, sweep in ipairs(ns.Slab.frame.sweeps) do assert(sweep:GetAlpha() == 0, "recoloring must not revive resting sweeps") end
end
check()
ns.Slab.Refresh()
check()
assert(#env._errors == 0, tostring(env._errors[1]))
print("Medallions client paint preserves alpha")
