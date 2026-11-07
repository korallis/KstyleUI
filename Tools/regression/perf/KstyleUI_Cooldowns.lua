-- KstyleUI_Cooldowns.lua: the cooldown rows' combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local C = dofile("Tools/regression/cooldowns_env.lua")

local function Mirror()
	local env, K = C.New({ setup = C.Game })
	local cdm = env._cdm
	cdm.auras[3001] = { auraInstanceID = 71 }
	cdm.stacks[71] = "3"
	cdm.auras[4001] = { auraInstanceID = 81 }
	K.Options.Write("Cooldowns", "path", "mirror")
	C.Enable(env, K)
	env.RunTimers()
	return env
end

return {
	{
		name = "Cooldowns UNIT_AURA",
		budget = 160,
		setup = function()
			local env = Mirror()
			local fire = Perf.Event(env, "UNIT_AURA", "player", { isFullUpdate = false, updatedAuraInstanceIDs = { 71 } })
			return env, function()
				fire()
				env.RunTimers()
			end
		end,
	},
	{
		name = "Cooldowns SPELL_UPDATE_COOLDOWN",
		budget = 80,
		setup = function()
			local env = Mirror()
			return env, Perf.Event(env, "SPELL_UPDATE_COOLDOWN")
		end,
	},
}
