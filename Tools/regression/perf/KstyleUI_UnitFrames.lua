-- KstyleUI_UnitFrames.lua: the unit frames' combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local U = dofile("Tools/regression/unitframes_env.lua")

local WOLF = {
	name = "Wolf", level = 12, health = 50, healthMax = 200, power = 10, powerMax = 100,
	powerType = 1, powerToken = "RAGE", reaction = 2, canAttack = true,
}

local function Target()
	local env = U.New()
	U.SetUnit(env, "target", WOLF)
	env.SetTarget(true)
	return env
end

return {
	{
		name = "UnitFrames UNIT_HEALTH",
		budget = 30,
		setup = function()
			local env = Target()
			return env, Perf.Event(env, "UNIT_HEALTH", "target")
		end,
	},
	{
		name = "UnitFrames UNIT_POWER_UPDATE",
		budget = 15,
		setup = function()
			local env = Target()
			return env, Perf.Event(env, "UNIT_POWER_UPDATE", "player", "MANA")
		end,
	},
	{
		name = "UnitFrames UNIT_FLAGS",
		budget = 50,
		setup = function()
			local env = Target()
			return env, Perf.Event(env, "UNIT_FLAGS", "target")
		end,
	},
	{
		name = "UnitFrames UNIT_THREAT_LIST_UPDATE",
		budget = 15,
		setup = function()
			local env = Target()
			env._units.target.threatOn = 3
			env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
			return env, Perf.Event(env, "UNIT_THREAT_LIST_UPDATE", "target")
		end,
	},
	{
		name = "UnitFrames UNIT_THREAT_LIST_UPDATE for another unit",
		budget = 10,
		setup = function()
			local env = Target()
			return env, Perf.Event(env, "UNIT_THREAT_LIST_UPDATE", "nameplate7")
		end,
	},
	{
		name = "UnitFrames UNIT_SPELLCAST_START",
		budget = 80,
		setup = function()
			local env = Target()
			env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
			return env, Perf.Event(env, "UNIT_SPELLCAST_START", "player", "Cast-1", 116)
		end,
	},
}
