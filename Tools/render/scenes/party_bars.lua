-- party_bars.lua: live party health after a health update, keeping the fill-end treatment visible.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

return Common.Run(function()
	local scene = Hud.Module("groupframes", {
		party = {
			{ "Thaldren", "WARRIOR", 72, "TANK" },
			{ "Sylaen", "DRUID", 87, "HEALER" },
			{ "Lunara", "MAGE", 64, "DAMAGER" },
		},
	})
	local env = Hud.envs[scene]
	env._roster.units.party1.health = 71
	env.FireEvent("UNIT_HEALTH", "party1")
	local result = Common.Scene.Build(env)
	result.log = scene.log
	return result
end)
