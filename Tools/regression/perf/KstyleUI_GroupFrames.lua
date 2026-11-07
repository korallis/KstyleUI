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
		name = "GroupFrames UNIT_HEALTH",
		budget = 40,
		setup = function()
			local env = Party()
			return env, Perf.Event(env, "UNIT_HEALTH", "party1")
		end,
	},
	{
		name = "GroupFrames UNIT_FLAGS",
		budget = 40,
		setup = function()
			local env = Party()
			return env, Perf.Event(env, "UNIT_FLAGS", "party1")
		end,
	},
}
