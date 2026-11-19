-- hud_reach.lua: the reach regression's complete live HUD, with forty raid members and every module enabled.
local Common = dofile("Tools/render/scenes/_common.lua")
local Reach = dofile("Tools/regression/hud_reach_lib.lua")

return Common.Run(function()
	local screen = Common.DEFAULT_SCREEN
	local env, K = Reach.New(screen.width, screen.height, (os.getenv("RENDER_HUD_STYLE") or "Frames"):lower(), os.getenv("RENDER_LAYOUT") or "DPS")
	K.Options.Write("Layout", "arrangement", os.getenv("RENDER_ARRANGEMENT") or "centred")
	K.Options.Write("Meters", "threat.shown", true)
	if os.getenv("RENDER_GROUP")=="party" then
		local Group=dofile("Tools/regression/group_env.lua")
		Group.SetRoster(env,"party",Group.Members(4),env._units.player,true)
		env.FireEvent("GROUP_ROSTER_UPDATE")
	end
	env.RunTimers()
	Reach.Populate(env)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	return Common.Scene.Build(env)
end)
