-- test-perf-meter-anchors.lua: damage refreshes preserve anchors until their text metrics or layout inputs change.
local M = dofile("Tools/regression/meters_env.lua")
local env, K, ns = M.New({ game = function(e) e._group = { raid = false, size = 2 } end })
env._session = { combatSources = {
	{ name = "Tester", classFilename = "WARRIOR", totalAmount = 2840, amountPerSecond = 28.4, sourceDisplayType = 1, isLocalPlayer = false },
}, maxAmount = 2840, totalAmount = 2840, durationSeconds = 30 }
M.Enable(env, K)
local count, list = 0, ns.Damage.list
for _, row in ipairs(list.rows) do
	for _, region in ipairs({ row.frame, row.name, row.value, row.percent, row.dot }) do
		local original = region.SetPoint
		region.SetPoint = function(self, ...)
			count = count + 1
			return original(self, ...)
		end
	end
end
env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
env.RunTimers()
assert(count == 0, "P10: anchor meter rows only when their layout or text metrics change")
dofile("Tools/regression/instruction_budget.lua")(function()
	env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	env.RunTimers()
end, 8000, "P10: retain meter anchors, title and aside until their inputs change")
K.Options.Write("Meters", "damage.percent", false)
assert(count > 0, "P10: a column change must still re-anchor meter text")
list:SetRest(env.Secret("12 dps"))
list:SetRest("13 dps")
assert(list.rest == "13 dps", "P10: a readable rate must replace a formerly secret rate without comparing it")
assert(#env._errors == 0 and K.ErrorCount() == 0, "meter caching must preserve the refresh")
print("perf meter anchors ok")
