-- KstyleUI_Nameplates.lua: the nameplates' combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local N = dofile("Tools/regression/nameplates_env.lua")

local function Plate()
	local env = N.New()
	N.Add(env, "nameplate1")
	return env
end

return {
	{
		name = "Nameplates UNIT_HEALTH",
		budget = 15,
		setup = function()
			local env = Plate()
			return env, Perf.Event(env, "UNIT_HEALTH", "nameplate1")
		end,
	},
	{
		name = "Nameplates UNIT_SPELLCAST_START",
		budget = 50,
		setup = function()
			local env = Plate()
			env._units.nameplate1.cast = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
			return env, Perf.Event(env, "UNIT_SPELLCAST_START", "nameplate1")
		end,
	},
	{
		name = "Nameplates SPELL_UPDATE_COOLDOWN while casting",
		budget = 20,
		setup = function()
			local env = N.New({ playerClass = "WARRIOR", known = { [6552] = true } })
			N.Add(env, "nameplate1")
			env._units.nameplate1.cast = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
			env.FireEvent("UNIT_SPELLCAST_START", "nameplate1")
			return env, Perf.Event(env, "SPELL_UPDATE_COOLDOWN")
		end,
	},
	{
		-- Three bars recolour (one fill call each) plus one cooldown read: 6.5 us here; the CI runner measured
		-- 5.3 times this path's local time, so 80 is the README's 15x calibration with room for that runner.
		name = "Nameplates interrupt readiness flipping under three casts",
		budget = 80,
		setup = function()
			local env = N.New({ playerClass = "WARRIOR", known = { [6552] = true } })
			local cast = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
			for i = 1, 3 do
				N.Add(env, "nameplate" .. i)
				env._units["nameplate" .. i].cast = cast
				env.FireEvent("UNIT_SPELLCAST_START", "nameplate" .. i)
			end
			local busy, idle = { isActive = true, isOnGCD = false }, { isActive = false, isOnGCD = false }
			local fire = Perf.Event(env, "SPELL_UPDATE_COOLDOWN")
			local flip = false
			return env, function()
				flip = not flip
				env._cooldowns[6552] = flip and busy or idle
				fire()
			end
		end,
	},
	{
		name = "Nameplates UNIT_AURA with eight debuffs",
		budget = 20,
		setup = function()
			local env = Plate()
			N.Debuffs(env, "nameplate1", 8)
			return env, Perf.Event(env, "UNIT_AURA", "nameplate1")
		end,
	},
	{
		name = "Nameplates QUEST_LOG_UPDATE with a plate",
		budget = 20,
		setup = function()
			local env = Plate()
			return env, Perf.Event(env, "QUEST_LOG_UPDATE")
		end,
	},
	{
		name = "Nameplates UNIT_FLAGS while casting",
		budget = 30,
		setup = function()
			local env = Plate()
			env._units.nameplate1.cast = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
			env.FireEvent("UNIT_SPELLCAST_START", "nameplate1")
			return env, Perf.Event(env, "UNIT_FLAGS", "nameplate1")
		end,
	},
}
