-- KstyleUI_ActionBars.lua: the action bars' combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local AB = dofile("Tools/regression/actionbars_env.lua")

local SLOTS = 12

return {
	{
		name = "ActionBars ACTIONBAR_UPDATE_COOLDOWN",
		budget = 80,
		setup = function()
			local env, K = AB.New()
			AB.Enable(env, K)
			for n = 1, SLOTS do
				AB.Slot(env, n, { texture = 135000 + n, type = "spell", id = 100 + n, cooldown = { name = "cd" .. n } })
			end
			AB.Slot(env, 2, {
				texture = 135002, type = "spell", id = 102, cooldown = { name = "cd2" }, count = "2",
				charges = { maxCharges = 2, currentCharges = 1, isActive = true }, chargeDuration = { name = "charge2" },
			})
			return env, Perf.Event(env, "ACTIONBAR_UPDATE_COOLDOWN")
		end,
	},
}
