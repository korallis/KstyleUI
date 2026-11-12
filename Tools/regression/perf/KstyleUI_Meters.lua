-- KstyleUI_Meters.lua: the meters' combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local M = dofile("Tools/regression/meters_env.lua")

return {
	{
		name = "Meters threat Update",
		budget = 300,
		setup = function()
			local env, K = M.New()
			env._group = { raid = false, size = 3 }
			env._units.party1 = { name = "Kragar", class = "WARRIOR" }
			env._units.party2 = { name = "Sylaen", class = "PRIEST" }
			env._units.target = { name = "Magmatus", hostile = true }
			env._threat.player = { false, 1, 60, 50, 600000 }
			env._threat.party1 = { true, 3, 100, 100, 1000000 }
			env._threat.party2 = { false, 0, 30, 25, 300000 }
			M.Enable(env, K)
			env.FireEvent("PLAYER_TARGET_CHANGED")
			env.RunTimers()
			local fire = Perf.Event(env, "UNIT_THREAT_LIST_UPDATE", "target")
			return env, function()
				fire()
				env.RunTimers()
			end
		end,
	},
	{
		name = "Meters damage refresh, raid of twenty",
		budget = 2000,
		setup = function()
			local env, K = M.New()
			env._group = { raid = true, size = 20 }
			env._units.player.guid = "Player-14"
			local sources = {}
			for i = 1, 20 do
				sources[i] = {
					name = "Raider" .. i, classFilename = "WARRIOR", totalAmount = 4000 - i * 100, amountPerSecond = 400 - i * 10,
					sourceGUID = "Player-" .. i, sourceDisplayType = 1, isLocalPlayer = i == 14, deathRecapID = 0, deathTimeSeconds = 0,
				}
			end
			env._session = { combatSources = sources, maxAmount = 3900, totalAmount = 50000, durationSeconds = 30 }
			M.Enable(env, K)
			env.RunTimers()
			local fire = Perf.Event(env, "DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 4)
			return env, function()
				fire()
				env.RunTimers()
			end
		end,
	},
}
