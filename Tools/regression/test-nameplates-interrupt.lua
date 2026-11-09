-- test-nameplates-interrupt.lua: cast bars colour by what the player can do about the cast: interruptible with the interrupt ready, interruptible while it recharges, or uninterruptible.
local N = dofile("Tools/regression/nameplates_env.lua")
local Last, SameColor = N.Last, N.SameColor

local function barIs(bar, r, g, b)
	local br, bg, bb = bar:GetStatusBarColor()
	return SameColor(br, bg, bb, r, g, b)
end

local function setting(ns, key)
	local c = ns.Settings.Get(key)
	return c.r, c.g, c.b
end

local CAST = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
local PUMMEL, PUMMEL_2, SHIELD_BASH = 6552, 6554, 72

-- The pure rules: which spell is the player's interrupt, and whether it is ready ---------------------------

do
	local env, _, ns = N.New({ enable = false })
	local Logic = ns.Logic
	local function known(list)
		return function(id)
			return list[id] == true
		end
	end
	assert(Logic.InterruptSpell("WARRIOR", known({ [PUMMEL] = true })) == PUMMEL, "a warrior who knows Pummel interrupts with it")
	assert(Logic.InterruptSpell("WARRIOR", known({ [PUMMEL] = true, [PUMMEL_2] = true })) == PUMMEL_2, "the highest rank known comes first")
	assert(Logic.InterruptSpell("WARRIOR", known({ [SHIELD_BASH] = true })) == SHIELD_BASH, "Shield Bash when Pummel is not known")
	assert(Logic.InterruptSpell("WARRIOR", known({})) == nil, "no interrupt known yet")
	assert(Logic.InterruptSpell("HUNTER", known({ [PUMMEL] = true })) == nil, "a hunter has no interrupt on Forever")
	assert(Logic.InterruptSpell(nil, known({ [PUMMEL] = true })) == nil, "no class, no interrupt")
	for class, list in pairs(Logic.INTERRUPTS) do
		assert(type(class) == "string" and #list > 0, "every class in the table lists spell IDs")
		for _, id in ipairs(list) do
			assert(type(id) == "number" and id == math.floor(id) and id > 0, class .. " lists whole spell IDs")
		end
	end

	assert(Logic.InterruptReady({ isActive = false, isOnGCD = false }) == true, "no cooldown running: ready")
	assert(Logic.InterruptReady({ isActive = true, isOnGCD = false }) == false, "a cooldown running: not ready")
	assert(Logic.InterruptReady({ isActive = true, isOnGCD = true }) == true, "the global cooldown alone does not count")
	assert(Logic.InterruptReady({ isActive = env.Secret(true), isOnGCD = false }) == nil, "a secret state decides nothing")
	assert(Logic.InterruptReady(nil) == nil, "no cooldown info decides nothing")
	assert(Logic.InterruptReady(env.Secret({ isActive = true })) == nil, "a secret table decides nothing")
end

-- A warrior's plates: the bar turns the wait colour while Pummel recharges -------------------------------

do
	local env, K, ns = N.New({ playerClass = "WARRIOR", known = { [PUMMEL] = true } })
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	N.Cast(env, "nameplate1", CAST)
	local bar = plate.castBar
	local ar, ag, ab = K.Theme.Accent()
	assert(barIs(bar, ar, ag, ab), "Pummel ready: an interruptible cast takes the accent")
	assert(ns.Interrupt.spell == PUMMEL, "the module found Pummel")

	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(barIs(bar, setting(ns, "cast.waitColor")), "Pummel recharging: the running cast turns the wait colour")
	assert(plate.castShield:GetAlpha() == 0, "no shield: the cast can still be interrupted, just not by you yet")

	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = true }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(barIs(bar, ar, ag, ab), "only the global cooldown: the accent again")

	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	env.FireEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "nameplate1")
	assert(barIs(bar, setting(ns, "cast.shieldColor")), "an uninterruptible cast is the shield colour whatever the interrupt is doing")
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "nameplate1")
	assert(barIs(bar, setting(ns, "cast.waitColor")), "interruptible again while Pummel recharges: the wait colour")

	-- A cast that starts while the interrupt recharges is the wait colour from its first frame.
	N.Add(env, "nameplate2")
	N.Cast(env, "nameplate2", CAST)
	assert(barIs(ns.Plates.Get("nameplate2").castBar, setting(ns, "cast.waitColor")), "a new cast reads the current state")

	-- A secret flag goes to the engine with the wait colour as the interruptible colour.
	N.Add(env, "nameplate3")
	N.Cast(env, "nameplate3", { name = "Shadow Bolt", text = "Shadow Bolt", texture = 136197, notInterruptible = false, secret = true })
	local tint = Last(ns.Plates.Get("nameplate3").castBar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
	assert(tint and env.issecretvalue(tint[1]), "a secret flag is coloured by the engine")
	local wr, wg, wb = setting(ns, "cast.waitColor")
	assert(SameColor(tint[3].r, tint[3].g, tint[3].b, wr, wg, wb), "with the wait colour for the interruptible case")
	env._cooldowns[PUMMEL] = { isActive = false, isOnGCD = false }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	tint = Last(ns.Plates.Get("nameplate3").castBar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
	assert(SameColor(tint[3].r, tint[3].g, tint[3].b, ar, ag, ab), "and the accent once Pummel is ready")

	-- A secret cooldown state never decides: the bar stays as the player can act.
	env._cooldowns[PUMMEL] = { isActive = env.Secret(true), isOnGCD = false }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(barIs(bar, ar, ag, ab), "a secret cooldown counts as ready")

	-- The wait colour is a setting.
	K.Options.Write("Nameplates", "cast.waitColor", { r = 0.5, g = 0.1, b = 0.9 })
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(barIs(bar, 0.5, 0.1, 0.9), "the wait colour follows the setting")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- The player names the spell: Shield Bash instead of Pummel; learning a spell re-resolves -----------------

do
	local env, K, ns = N.New({ playerClass = "WARRIOR", known = { [PUMMEL] = true, [SHIELD_BASH] = true } })
	env._spellIDs["Shield Bash"] = SHIELD_BASH
	assert(ns.Interrupt.spell == PUMMEL, "Pummel comes before Shield Bash")
	K.Options.Write("Nameplates", "cast.interruptSpell", "Shield Bash")
	assert(ns.Interrupt.spell == SHIELD_BASH, "a named spell wins")
	K.Options.Write("Nameplates", "cast.interruptSpell", "Spell Nobody Knows")
	assert(ns.Interrupt.spell == "Spell Nobody Knows", "an unresolved name is still handed to the cooldown API as it is")
	K.Options.Write("Nameplates", "cast.interruptSpell", "")
	assert(ns.Interrupt.spell == PUMMEL, "blank: back to the class table")

	-- Another profile names another spell; switching profiles finds it.
	K.Store.CreateProfile("Bash")
	K.Store.SetProfile("Bash")
	K.Modules.Enable("Nameplates")
	K.Options.Write("Nameplates", "cast.interruptSpell", "Shield Bash")
	assert(ns.Interrupt.spell == SHIELD_BASH, "the Bash profile names Shield Bash")
	K.Store.SetProfile("Default")
	assert(K.Modules.IsEnabled("Nameplates"), "the default profile runs the module too")
	assert(ns.Interrupt.spell == PUMMEL, "back on the default profile, Pummel again")

	local env2, _, ns2 = N.New({ playerClass = "WARRIOR", known = {} })
	assert(ns2.Interrupt.spell == nil, "a warrior who has not learned an interrupt yet has none")
	env2._known[PUMMEL] = true
	env2.FireEvent("SPELLS_CHANGED")
	assert(ns2.Interrupt.spell == PUMMEL, "SPELLS_CHANGED finds the spell once learned")
end

-- A hunter has no interrupt: every interruptible cast takes the accent, and the cooldown event is cheap ------

do
	local env, K, ns = N.New()
	assert(ns.Interrupt.spell == nil, "no interrupt for a hunter")
	N.Add(env, "nameplate1")
	N.Cast(env, "nameplate1", CAST)
	env._cooldowns[PUMMEL] = { isActive = true, isOnGCD = false }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	local ar, ag, ab = K.Theme.Accent()
	assert(barIs(ns.Plates.Get("nameplate1").castBar, ar, ag, ab), "without an interrupt, interruptible casts take the accent")
end

print("nameplates interrupt ok")
