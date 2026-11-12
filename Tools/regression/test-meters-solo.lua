-- test-meters-solo.lua: the damage meter shows by default when you play alone, in either style. "Only in a group" stays a setting, a player who never set it now sees the meter solo, and the restyled Blizzard window gets the game's damageMeterEnabled CVar on while KstyleUI shows it, with the player's own value back when it stops.
local M = dofile("Tools/regression/meters_env.lua")

local CVAR = "damageMeterEnabled"

local function Saved(damage)
	return {
		version = 4,
		profiles = { Default = { Meters = { enabled = true, damage = damage } } },
		characters = {},
	}
end

local function WithCVar(value)
	return function(env)
		env._cvars = { [CVAR] = value }
		env._cvarWrites = {}
		env.C_CVar = {
			GetCVar = function(name)
				return env._cvars[name]
			end,
			GetCVarInfo = function(name)
				local current = env._cvars[name]
				if current then return current, "0", false, false, false, false, false end
			end,
			SetCVar = function(name, v)
				assert(not env.InCombatLockdown(), "a CVar write in combat: " .. tostring(name))
				env._cvarWrites[#env._cvarWrites + 1] = { name = name, value = v }
				env._cvars[name] = v
				env.FireEvent("CVAR_UPDATE", name, v)
				return true
			end,
		}
	end
end

-- KstyleUI's own window, alone, with the defaults: the meter shows.
do
	local env, K, ns = M.New()
	M.Enable(env, K)
	assert(ns.Get("damage.group") == false, "the damage meter shows alone by default")
	assert(ns.Damage.Mode() == "window", "a readable client uses KstyleUI's window")
	env._group = { raid = false, size = 0 }
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.RunTimers()
	assert(ns.Damage.list.panel:IsShown() and ns.Damage.holder:IsShown(), "alone, the window shows")

	M.Write(env, K, "damage.group", true)
	assert(not ns.Damage.list.panel:IsShown(), "Only in a group still hides it alone")
	env._group = { raid = false, size = 2 }
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.RunTimers()
	assert(ns.Damage.list.panel:IsShown(), "and shows it in a group")
	assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))
end

-- A profile saved before this change never stored the old default, so the new one reaches it.
do
	local env, K, ns = M.New({ saved = Saved({ shown = true }) })
	M.Enable(env, K)
	assert(ns.Get("damage.group") == false, "a player who never set Only in a group sees the meter alone")
	assert(ns.Damage.list.panel:IsShown(), "and the window is on screen")
end
do
	local env, K, ns = M.New({ saved = Saved({ group = true }) })
	M.Enable(env, K)
	assert(ns.Get("damage.group") == true, "a stored choice is kept")
	assert(not ns.Damage.list.panel:IsShown(), "so that player's meter still waits for a group")
end

-- Blizzard's window restyled (a client without C_DamageMeter, or by choice): the game draws it only with
-- damageMeterEnabled on, which is off on a fresh account.
do
	local env, K, ns = M.New({ noMeter = true, game = WithCVar("0") })
	M.Enable(env, K)
	assert(ns.Damage.Mode() == "skin", "no C_DamageMeter: Blizzard's window restyled")
	assert(not K.Safe.IsHidden(env.DamageMeter), "alone, Blizzard's restyled window is not held hidden")
	assert(env._cvars[CVAR] == "1", "the game's damage meter is switched on so the window draws")

	M.Write(env, K, "damage.shown", false)
	assert(env._cvars[CVAR] == "0", "switching the meter off gives the player's value back")
	M.Write(env, K, "damage.shown", true)
	assert(env._cvars[CVAR] == "1", "and on again")

	env.SetCombat(true)
	M.Write(env, K, "damage.shown", false)
	assert(env._cvars[CVAR] == "1", "nothing is written in combat")
	env.SetCombat(false)
	env.FireEvent("PLAYER_REGEN_ENABLED")
	env.RunTimers()
	assert(env._cvars[CVAR] == "0", "the write waits for the end of combat")
	M.Write(env, K, "damage.shown", true)

	M.Disable(env, K)
	assert(env._cvars[CVAR] == "0", "switching the module off gives the player's value back")
	assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))
end

-- A player who already had the game's meter on keeps it on when KstyleUI stops.
do
	local env, K = M.New({ restricted = true, game = WithCVar("1") })
	M.Enable(env, K)
	assert(#env._cvarWrites == 0, "nothing to write when the game's meter is already on")
	M.Disable(env, K)
	assert(env._cvars[CVAR] == "1", "and it stays on after KstyleUI stops")
end

-- The window style never touches the CVar: KstyleUI draws its own window and hides Blizzard's.
do
	local env, K = M.New({ game = WithCVar("0") })
	M.Enable(env, K)
	assert(#env._cvarWrites == 0, "KstyleUI's own window needs no game CVar")
end

print("meters solo: ok")
