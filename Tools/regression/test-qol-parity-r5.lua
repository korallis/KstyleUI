-- test-qol-parity-r5.lua: Hide item transforms: a v0.2.8 profile keeps it off and listens for nothing, on it takes off only the listed costume, food and toy transforms, only out of combat while auras are readable, retries when combat ends or the restriction lifts, does no aura scan for unrelated events, takes the safe path when an answer is secret or an API is missing, and off stops at once.
local Q = dofile("Tools/regression/qol_env.lua")

local BAT, WISP, DELIGHT, GORDOK, INTELLECT = 24732, 24740, 8213, 22736, 1459

local function stand(env)
	env._buffs, env._secretAuras = {}, false
	env.C_Secrets = { ShouldAurasBeSecret = function() if env._secretAuras == "secret" then return env.Secret(true) end return env._secretAuras end }
	env.C_UnitAuras = { GetBuffDataByIndex = Q.Recorder(env, "GetBuffDataByIndex", function(unit, i) if unit == "player" then return env._buffs[i] end end) }
	env.CancelUnitBuff = Q.Recorder(env, "CancelUnitBuff", function(unit, i, filter)
		assert(not env.InCombatLockdown(), "ADDON_ACTION_BLOCKED: CancelUnitBuff()")
		assert(unit == "player" and filter == "HELPFUL" and env._buffs[i], "cancels a player buff by its index")
		table.remove(env._buffs, i)
	end)
end

local function boot(settings)
	local saved = { version = 42, profiles = { Default = { QoL = settings or { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = Q.New({ saved = saved, setup = stand })
	if not K.Modules.IsRunning("QoL") then Q.Enable(env, K) end
	env.RunTimers()
	return env, K, ns
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function wear(env, ...)
	local added = {}
	for _, id in ipairs({ ... }) do
		local aura = { spellId = id, auraInstanceID = #env._buffs + 100 }
		env._buffs[#env._buffs + 1] = aura
		added[#added + 1] = aura
	end
	env.FireEvent("UNIT_AURA", "player", { addedAuras = added })
end

local function ids(env)
	local out = {}
	for _, aura in ipairs(env._buffs) do out[#out + 1] = aura.spellId end
	return table.concat(out, ",")
end

-- Defaults: a v0.2.8 profile keeps the switch off, reads no aura and cancels nothing.
do
	local env, K, ns = boot({ enabled = true, autoOpen = true })
	assert(ns.Get("hideTransforms") == false, "off by default")
	wear(env, BAT)
	env.SetCombat(true)
	env.SetCombat(false)
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	assert(#Q.Calls(env, "GetBuffDataByIndex") == 0 and #Q.Calls(env, "CancelUnitBuff") == 0 and ids(env) == tostring(BAT), "nothing read or cancelled while off")
	clean(env, K)
end

-- On, with every other switch off: turning it on takes off a costume already worn, from the last index down, and leaves other buffs and disguises.
do
	local env, K = boot()
	env._buffs = { { spellId = INTELLECT }, { spellId = BAT }, { spellId = GORDOK }, { spellId = DELIGHT } }
	Q.Write(env, K, "hideTransforms", true)
	assert(ids(env) == INTELLECT .. "," .. GORDOK, "the costume and the food go, the buff and the Gordok disguise stay: " .. ids(env))
	local cancels = Q.Calls(env, "CancelUnitBuff")
	assert(#cancels == 2 and cancels[1][2] == 4 and cancels[2][2] == 2, "cancelled by index from the end")
	clean(env, K)
end

-- Events: a costume that lands comes off at once; an unrelated aura, a refresh or a combat end with nothing waiting reads no aura.
do
	local env, K = boot()
	Q.Write(env, K, "hideTransforms", true)
	Q.Reset(env)
	wear(env, INTELLECT)
	env.FireEvent("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 1 } })
	env.FireEvent("UNIT_AURA", "target", { addedAuras = { { spellId = BAT } } })
	env.SetCombat(true)
	env.SetCombat(false)
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(#Q.Calls(env, "GetBuffDataByIndex") == 0, "no scan for an unrelated aura, another unit or a combat end with nothing waiting")
	wear(env, WISP)
	assert(ids(env) == tostring(INTELLECT) and #Q.Calls(env, "CancelUnitBuff") == 1, "the wisp costume comes off as it lands")
	env._buffs[#env._buffs + 1] = { spellId = BAT }
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
	assert(ids(env) == tostring(INTELLECT), "a full update sweeps")
	clean(env, K)
end

-- Combat: a costume that lands in combat stays until combat ends, then comes off.
do
	local env, K = boot()
	Q.Write(env, K, "hideTransforms", true)
	env.SetCombat(true)
	wear(env, BAT)
	assert(ids(env) == tostring(BAT) and #Q.Calls(env, "CancelUnitBuff") == 0, "never cancelled in combat")
	env.SetCombat(false)
	assert(ids(env) == "", "taken off when combat ends")
	clean(env, K)
end

-- Restricted auras: while the game keeps auras secret, or its answer is secret, nothing is read; it comes off when the restriction lifts.
do
	local env, K = boot()
	Q.Write(env, K, "hideTransforms", true)
	Q.Reset(env)
	for _, state in ipairs({ true, "secret" }) do
		env._secretAuras = state
		wear(env, BAT)
		assert(#Q.Calls(env, "GetBuffDataByIndex") == 0 and ids(env) == tostring(BAT), "no aura read while auras are secret")
		env._secretAuras = false
		env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
		assert(ids(env) == "", "taken off when the restriction lifts")
		Q.Reset(env)
	end
	env._buffs = { { spellId = BAT } }
	env.FireEvent("UNIT_AURA", "player", { addedAuras = { { spellId = env.Secret(BAT) } } })
	assert(ids(env) == "", "a secret spell in the payload counts as a possible costume")
	env._buffs = { { spellId = env.Secret(BAT) } }
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
	assert(#env._buffs == 1, "a secret spell on the player is never cancelled")
	clean(env, K)
end

-- Missing APIs take the safe path: no secrecy answer, no aura reader or no cancel call cancels nothing and raises nothing.
do
	for _, missing in ipairs({ "C_Secrets", "C_UnitAuras", "CancelUnitBuff" }) do
		local env, K = boot()
		env[missing] = nil
		Q.Write(env, K, "hideTransforms", true)
		wear(env, BAT)
		env.SetCombat(true)
		env.SetCombat(false)
		assert(ids(env) == tostring(BAT), "nothing cancelled without " .. missing)
		clean(env, K)
	end
end

-- Off: turning the switch off, or QoL off, stops at once; a costume worn after stays, and a pending one is dropped.
do
	local env, K = boot()
	Q.Write(env, K, "hideTransforms", true)
	env.SetCombat(true)
	wear(env, BAT)
	Q.Write(env, K, "hideTransforms", false)
	env.SetCombat(false)
	wear(env, WISP)
	assert(ids(env) == BAT .. "," .. WISP, "both stay once off")
	Q.Write(env, K, "hideTransforms", true)
	assert(ids(env) == "", "on again sweeps")
	Q.Disable(env, K)
	wear(env, BAT)
	assert(ids(env) == tostring(BAT), "QoL off cancels nothing")
	clean(env, K)
end

-- The page: the row writes and waits on the module switch.
do
	local env, K, ns = boot()
	local row
	for _, r in ipairs(ns.Schema()) do if r.key == "hideTransforms" then row = r end end
	assert(row and row.type == "toggle" and row.disableWhen({ enabled = false }) and not row.disableWhen({ enabled = true }), "a toggle that needs QoL on")
	Q.Write(env, K, "hideTransforms", true)
	assert(K.Options.Read("QoL", "hideTransforms") == true, "writes")
	clean(env, K)
end

print("qol parity round 5 ok")
