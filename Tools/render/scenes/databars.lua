-- databars.lua: the experience bar and the data strip in the mockup's state: level 38 at 32% with no rested
-- experience and no watched faction, 144 fps, 34 ms, 143g 82s 17c, 96% durability and 14:32.
local Common = dofile("Tools/render/scenes/_common.lua")

return Common.Run(function()
	local D = dofile("Tools/regression/databars_env.lua")
	local env, K = D.New({
		saved = {
			version = 2,
			profiles = { Default = { DataBars = { enabled = true } } },
			characters = {},
			layouts = {},
			account = { setupSeen = true },
			devlog = {},
		},
		game = { xp = 16000, xpMax = 50000, rested = 0, level = 38, faction = false },
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
	env.RunTimers()
	D.W.Settle(env)
	local scene = Common.Scene.Build(env)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "databars error: " .. err
	end
	return scene
end)
