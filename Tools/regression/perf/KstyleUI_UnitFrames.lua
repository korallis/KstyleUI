-- KstyleUI_UnitFrames.lua: the unit frames' combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local U = dofile("Tools/regression/unitframes_env.lua")

local WOLF = {
	name = "Wolf", level = 12, health = 50, healthMax = 200, power = 10, powerMax = 100,
	powerType = 1, powerToken = "RAGE", reaction = 2, canAttack = true,
}

local function Orbs()
	return U.New({
		saved = {
			version = 2,
			profiles = { Default = { UnitFrames = { enabled = true }, HudStyle = { style = "orbs" } } },
			characters = {},
		},
		setup = function(env)
			env.Enum = env.Enum or {}
			env.Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
			env._restricted = true
		end,
	})
end

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
	{
		name = "UnitFrames target change at Full, rank changes",
		budget = 1000,
		calls = 50,
		setup = function()
			local env = Target()
			local elite = env._units.target
			elite.classification = "elite"
			local normal = { name = "Kobold Laborer", level = 11, health = 80, healthMax = 160, reaction = 2, canAttack = true, classification = "normal" }
			env.FireEvent("PLAYER_TARGET_CHANGED")
			env.RunTimers()
			local changed, flip = Perf.Event(env, "PLAYER_TARGET_CHANGED"), false
			return env, function()
				flip = not flip
				env._units.target = flip and normal or elite
				changed()
				env.RunTimers()
			end
		end,
	},
	{
		name = "UnitFrames Orbs UNIT_HEALTH",
		budget = 30,
		setup = function()
			local env = Orbs()
			return env, Perf.Event(env, "UNIT_HEALTH", "player")
		end,
	},
	{
		name = "UnitFrames Orbs UNIT_POWER_UPDATE",
		budget = 20,
		setup = function()
			local env = Orbs()
			return env, Perf.Event(env, "UNIT_POWER_UPDATE", "player", "MANA")
		end,
	},
}
