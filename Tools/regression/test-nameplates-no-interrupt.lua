-- test-nameplates-no-interrupt.lua: no known interrupt retains normal cast ink, while a known spell with unavailable cooldown information waits.
local N = dofile("Tools/regression/nameplates_env.lua")
for _, class in ipairs({ "HUNTER", "PRIEST", "WARLOCK" }) do
	local env, _, ns = N.New({ playerClass = class, known = {} })
	N.Add(env, "nameplate1")
	N.Cast(env, "nameplate1", { name = "Bolt", text = "Bolt", notInterruptible = false })
	local plate = ns.Plates.Get("nameplate1")
	local function color(key)
		local c = ns.Settings.Get(key)
		local r, g, b = plate.castBar:GetStatusBarColor()
		assert(N.SameColor(r, g, b, c.r, c.g, c.b), class .. " cast should use " .. key)
	end
	assert(ns.Interrupt.spell == nil, class .. " has no known interrupt")
	color("cast.color")
	if class == "WARLOCK" then
		env._known[19647] = true
		env._cooldowns[19647] = { isActive = env.Secret(true), isOnGCD = false }
		env.FireEvent("SPELLS_CHANGED")
		assert(ns.Interrupt.spell == 19647 and ns.Interrupt.ready == nil, "Spell Lock is known but its cooldown is secret")
		color("cast.waitColor")
		env._known[19647] = nil
		env.FireEvent("SPELLS_CHANGED")
		assert(ns.Interrupt.spell == nil and ns.Interrupt.ready == nil, "losing the pet keeps unknown readiness")
		color("cast.color")
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("nameplates no interrupt ok")
