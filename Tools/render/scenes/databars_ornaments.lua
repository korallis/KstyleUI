-- databars_ornaments.lua: the experience and reputation bars in the state RENDER_STATE names, for the ornament before and after pairs: empty (level 38 at 0%), partial (32%), rested (32% with rested experience), full (99%), rep (the level cap with Stormwind watched, so the experience bar hides and the reputation bar shows), cap (the level cap with no faction watched, both bars hidden) and hover (partial, with the pointer over the reputation bar). The default is rested; a test sets the global RENDER_STATE instead.
local Common = dofile("Tools/render/scenes/_common.lua")

local STATES = {
	empty = { xp = 0, rested = 0, level = 38, faction = false },
	partial = { xp = 16000, rested = 0, level = 38, faction = false },
	rested = { xp = 16000, rested = 9000, level = 38, faction = false },
	full = { xp = 49500, rested = 0, level = 38, faction = false },
	rep = { xp = 0, rested = 0, level = 60 },
	cap = { xp = 0, rested = 0, level = 60, faction = false },
	hover = { xp = 16000, rested = 0, level = 38 },
}

return Common.Run(function()
	local name = rawget(_G, "RENDER_STATE") or os.getenv("RENDER_STATE") or "rested"
	local state = assert(STATES[name], "RENDER_STATE must be one of empty, partial, rested, full, rep, cap, hover, not " .. name)
	local D = dofile("Tools/regression/databars_env.lua")
	local game = { xpMax = 50000, maxLevel = 60 }
	for k, v in pairs(state) do game[k] = v end
	local env, K, ns = D.New({
		saved = {
			version = 2,
			profiles = { Default = { DataBars = { enabled = true } } },
			characters = {},
			layouts = {},
			account = { setupSeen = true },
			devlog = {},
		},
		game = game,
		setup = function(env)
			Common.ForceScreen(env)
			env.RAID_CLASS_COLORS = env.RAID_CLASS_COLORS or {}
			env.RAID_CLASS_COLORS.WARRIOR = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3] }
			env.UnitClass = function(unit)
				if unit == "player" or unit == nil then
					return "Warrior", "WARRIOR", 1
				end
			end
		end,
	})
	K.Options.Write("DataBars", "strip.slot4", "durability")
	env.RunTimers()
	D.W.Settle(env)
	if name == "hover" then
		local rep = ns.Bars.views.rep
		rep.holder:GetScript("OnEnter")(rep.holder)
		D.W.Settle(env)
	end
	local scene = Common.Scene.Build(env)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "databars_ornaments error: " .. err
	end
	return scene
end)
