-- minimap_plaque.lua: the Medallions minimap at its default screen edge with the full ring and both plaques.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local M = dofile("Tools/regression/minimap_env.lua")

return Common.Run(function()
	local env, K = M.New(Common.ScreenOpts({
		enabled = true, zone = "Riverglades",
		setup = function(e) Common.ForceScreen(e) end,
	}))
	K.Options.Write("HudStyle", "style", "medallions")
	M.Settle(env)
	local _, note = Hud.Terrain(env)
	local scene = Common.Scene.Build(env)
	scene.log[#scene.log + 1] = note
	local err = Common.Errors(env, K)
	if err then scene.log[#scene.log + 1] = err end
	return scene
end)
