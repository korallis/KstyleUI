-- KstyleUI_GroupFrames.lua: the group frames' combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local G = dofile("Tools/regression/group_env.lua")

local function Party()
	local env, K = G.New()
	G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", leader = true, threat = 3, incoming = 30, absorb = 12, health = 80, maxHealth = 100 },
		{ name = "Sylaen", class = "DRUID", role = "HEALER", marker = 8, health = 80, maxHealth = 100 },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", threat = 0, health = 80, maxHealth = 100 },
	})
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	return env
end

return {
	{
		name = "GroupFrames raid40 prediction events",
		budget = 10000,
		calls = 20,
		setup = function()
			local env, K = G.New()
			G.SetRoster(env, "raid", G.Members(40, function(_, m)
				m.incoming, m.absorb, m.healAbsorb = 12, 9, 7
			end))
			K.Modules.Enable("GroupFrames")
			env.RunTimers()
			local health, heals, absorbs = {}, {}, {}
			for i = 1, 40 do
				local unit = "raid" .. i
				health[i] = Perf.Event(env, "UNIT_HEALTH", unit)
				heals[i] = Perf.Event(env, "UNIT_HEAL_PREDICTION", unit)
				absorbs[i] = Perf.Event(env, "UNIT_ABSORB_AMOUNT_CHANGED", unit)
			end
			return env, function()
				for i = 1, 40 do
					health[i]()
					health[i]()
					heals[i]()
					if i <= 10 then
						absorbs[i]()
					end
				end
			end
		end,
	},
	{
		name = "GroupFrames UNIT_HEALTH",
		budget = 90,
		setup = function()
			local env = Party()
			return env, Perf.Event(env, "UNIT_HEALTH", "party1")
		end,
	},
	{
		name = "GroupFrames UNIT_FLAGS",
		budget = 55,
		setup = function()
			local env = Party()
			return env, Perf.Event(env, "UNIT_FLAGS", "party1")
		end,
	},
}
