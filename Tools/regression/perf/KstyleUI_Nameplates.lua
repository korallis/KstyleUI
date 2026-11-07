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
}
