-- test-api-cooldown-contracts.lua: cooldown readiness trusts isOnGCD only in its documented event, and unreadable viewer layouts never remove a buff from both displays.
local N = dofile("Tools/regression/nameplates_env.lua")
local A = dofile("Tools/regression/auras_env.lua")

do
	local env, _, ns = N.New({ playerClass = "WARRIOR", known = { [6552] = true } })
	env._cooldowns[6552] = { isActive = true, isOnGCD = true }
	ns.Interrupt.Resolve()
	assert(ns.Interrupt.ready == false, "a resolution outside SPELL_UPDATE_COOLDOWN cannot treat an active cooldown as only GCD")
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(ns.Interrupt.ready == true, "inside SPELL_UPDATE_COOLDOWN the documented GCD flag is trustworthy")
	env.FireEvent("SPELLS_CHANGED")
	assert(ns.Interrupt.ready == false, "SPELLS_CHANGED must not reuse the event-only GCD field")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, ns = A.New()
	env._tracked[501] = { spellID = 1001 }
	env._cdmLayout = { [501] = false }
	K.Modules.Enable("Auras")
	assert(ns.Tracked.Set() == nil, "the customized layout hides the default buff")
	env._cdmDirty = true
	assert(ns.Tracked.Set() == nil, "a dirty layout must not fall back to a default that the player hid")
	env.CooldownViewerSettings = nil
	assert(ns.Tracked.Set() == nil, "an unavailable layout cannot prove a buff has another display")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, _, ns = A.New()
	env._tracked[501] = { spellID = 1001 }
	assert(ns.Tracked.Set(), "a clean readable layout can exclude a tracked buff")
	env.BuffIconCooldownViewer = nil
	assert(ns.Tracked.Set() == nil, "without the viewer's visibility setting no other display is proven")
end

print("API cooldown contracts ok")
