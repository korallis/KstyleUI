-- minimap_plaque.lua: the Medallions minimap at the owner's saved screen-corner position with the full ring and both plaques.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local M = dofile("Tools/regression/minimap_env.lua")

return Common.Run(function()
	local env, K = M.New(Common.ScreenOpts({
		enabled = true, zone = "Tirisfal Glades", position = { 0.616, 0.579 },
		setup = function(e)
			e.KstyleUIDB.profiles.Default.HudStyle = { style = "medallions" }
			e.KstyleUIDB.layouts.Default = { ["minimap.main"] = { anchor = "TOPRIGHT", x = -0.00008, y = -6.4 } }
			Common.ForceScreen(e)
		end,
	}))
	M.Settle(env)
	local _, note = Hud.Terrain(env)
	local scene = Common.Scene.Build(env)
	scene.log[#scene.log + 1] = note
	local err = Common.Errors(env, K)
	if err then scene.log[#scene.log + 1] = err end
	return scene
end)
