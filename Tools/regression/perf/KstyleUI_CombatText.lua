-- KstyleUI_CombatText.lua: combat text's combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local CT = dofile("Tools/regression/combattext_env.lua")

return {
	{
		name = "CombatText UNIT_COMBAT",
		budget = 80,
		setup = function()
			local env, K = CT.New()
			CT.Enable(env, K)
			return env, Perf.Event(env, "UNIT_COMBAT", "player", "WOUND", "", env.Secret(1234), 4)
		end,
	},
}
