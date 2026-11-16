-- questcard_guide.lua: the Medallions quest card, open RestedXP guide and docked boxes in one environment.
local Common = dofile("Tools/render/scenes/_common.lua")
local Boot = dofile("Tools/regression/questcard_guide_env.lua")

return Common.Run(function()
	local R = Boot(Common.SCREEN, os.getenv("RENDER_QUEST_ITEM") == "1")
	if os.getenv("RENDER_COMBAT") == "1" then
		R.env.SetCombat(true)
		R.rxp.SetStep()
		R.log.Fire("QUEST_LOG_UPDATE")
		R.settle()
	end
	local scene = Common.Scene.Build(R.env, { iconDirs = Common.IconDirs() })
	local err = Common.Errors(R.env, R.K)
	assert(not err, err)
	scene.log[#scene.log + 1] = "Medallions warlock: quest card and open guide share one environment; combat=" .. tostring(R.env.InCombatLockdown())
	return scene
end)
