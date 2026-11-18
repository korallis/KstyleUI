-- test-unitframes-target-cast-wiring.lua: changing targets never detaches the live health ornament from its cast bar, including across HUD styles.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
K.Options.Write("HudStyle", "style", "medallions")
local view = ns.Frames.Get("target").views[1]
local function target(name)
	U.SetUnit(env, "target", { name = name, level = 10, health = 80, healthMax = 100, reaction = 2, canAttack = true })
	env.SetTarget(true)
	U.W.Tick(env, 0.06)
	U.W.Tick(env, 0.06)
end
target("Wolf")
target("Boar")
local function wired()
	local cb, block = view.castbar, view.health.ornament
	assert(cb.ornament.card == block.card, "E5: the target cast card must remain linked to the live slab after changing targets")
	local text, timer = false, false
	for _, region in ipairs(block.texts) do
		text = text or region == cb.text
		timer = timer or region == cb.timer
	end
	assert(text and timer and block.reserve[cb.text] and block.reserve[cb.timer], "E5: the live ornament must reserve both cast labels")
end
wired()
for _, style in ipairs({ "frames", "orbs", "medallions" }) do
	U.SetUnit(env, "target", { name = style, level = 10, health = 50, healthMax = 100, reaction = 2 })
	env.SetTarget(true)
	K.Options.Write("HudStyle", "style", style)
	U.W.Tick(env, 0.12)
	assert(view.body:GetAlpha() == 1, "E5: a HUD style switch settles any pending target fade")
	wired()
	env._units.target.cast = { name = "Fear", texture = 136183, start = 0, finish = 4000, spellID = 5782 }
	env.FireEvent("UNIT_SPELLCAST_START", "target")
	local cb = view.castbar.active and view.castbar or ns.CastBars.Get("target")[1]
	assert(cb.active and cb.frame:IsShown() and U.Shown(env, cb.text):upper() == "FEAR", "E5: target casting still updates after changing targets and switching to " .. style)
	env._units.target.cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "target")
end
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("target cast wiring ok")
