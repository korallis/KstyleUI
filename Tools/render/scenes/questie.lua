-- questie.lua: Questie's independent tracker over the real quest card and RestedXP guide; RENDER_QUESTIE=absent proves the unchanged card.
local Common = dofile("Tools/render/scenes/_common.lua")
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Questie = dofile("Tools/regression/questie_fake.lua")

return Common.Run(function()
	local choice = os.getenv("RENDER_QUESTIE")
	local R = Boot(Common.SCREEN, nil, nil, true, choice ~= "absent" and function(env, log)
		if choice == "plain" then env.KstyleUI.Store.Module("Skins").questie = { enabled = false } end
		return Questie.Install(env, log)
	end or nil)
	R.rxp.activeItemFrame.buttonList[1].icon:SetTexture(132794)
	R.rxp.targeting.activeTargetFrame.enemyTargetButtons[1].icon:SetTexture(136188)
	if R.questie then
		R.K.Options.Write("Integrations", "questTracker", "questie")
		R.settle()
		local card, frame = R.ns.RestedXP.Chrome.Path(R.rxp.RXPFrame).card, R.questie.frame
		frame:ClearAllPoints()
		frame:SetPoint("TOPRIGHT", card, "TOPLEFT", -32, 0)
	end
	local scene = Common.Scene.Build(R.env, { iconDirs = Common.IconDirs() })
	local err = Common.Errors(R.env, R.K)
	assert(not err, err)
	scene.log[#scene.log + 1] = "Questie public API fixture: independent tracker and Forever native watch hooks; Medallions with RestedXP"
	return scene
end)
