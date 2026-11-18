local AB = dofile("Tools/regression/actionbars_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local env, K, ns = AB.New({ class = "WARLOCK" })
AB.Enable(env, K)
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
local hub = ns.Slab.hub
for _, region in ipairs({ hub.glow, hub.bloom, hub.glyphs, hub.runes, hub.shock, hub.flash, unpack(hub.particles) }) do
	assert(select(4, region:GetVertexColor()) == 1, "paint RGB with vertex alpha one so animation alpha is applied once")
end
for _, sweep in ipairs(ns.Slab.frame.sweeps) do
	assert(select(4, sweep:GetVertexColor()) == 1, "a dormant sweep must retain vertex alpha one so its animation can show")
end
assert(hub.shock:GetAlpha() == 0, "recoloring must not revive the dormant shock ring")
assert(hub.flash:GetAlpha() == 0, "recoloring must not revive the dormant square flash")
assert(math.abs(hub.glyphs:GetAlpha() - 0.35) < 1e-6, "glyph recoloring keeps the rune line's resting opacity")
assert(math.abs(hub.runes:GetAlpha() - 0.25) < 1e-6, "rune recoloring keeps the turning runes' resting opacity")
ns.Slab.Refresh()
assert(hub.shock:GetAlpha() == 0 and hub.flash:GetAlpha() == 0, "refresh preserves dormant effects")
for _, sweep in ipairs(ns.Slab.frame.sweeps) do
	assert(sweep:GetAlpha() == 0, "recoloring preserves the dormant combat sweep")
end
local found
for _, item in ipairs(Scene.Build(env).items) do
	if item.object == hub.glyphs then
		found = true
		assert(math.abs(item.alpha * item.vertex[4] - 0.35) < 1e-6, "the truthful harness draws glyphs at 0.35, not alpha squared")
	end
end
assert(found, "the hub glyphs draw")
ns.Slab.SetCombat(true)
local sweep = ns.Slab.frame.sweeps[1]
local drawn
for _, item in ipairs(Scene.Build(env, { time = sweep.anim._playedAt + Scene.AnimationPeak(sweep.anim) }).items) do
	if item.object == sweep then drawn = item.alpha * item.vertex[4] end
end
assert(drawn and drawn > 0, "a combat sweep must draw at its animation peak after being painted dormant")
K.Options.Write("ActionBars", "hubAlpha", false)
assert(math.abs(select(4, hub.glyphs:GetVertexColor()) - hub.glyphs:GetAlpha()) < 1e-6, "turning full-strength effects off restores the earlier multiplied alpha")
assert(#env._errors == 0, tostring(env._errors[1]))
print("Medallions client paint passed")
