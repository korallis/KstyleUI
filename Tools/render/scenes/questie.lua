-- questie.lua: Questie's independent tracker over the real quest card and RestedXP guide; RENDER_QUESTIE=absent proves the unchanged card.
local Common = dofile("Tools/render/scenes/_common.lua")
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Questie = dofile("Tools/regression/questie_fake.lua")

return Common.Run(function()
	local R = Boot(Common.SCREEN, nil, nil, true, os.getenv("RENDER_QUESTIE") ~= "absent" and Questie.Install or nil)
	if R.questie then
		local card, frame = R.ns.Quests.Card(), R.questie.frame
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
	end
	local scene = Common.Scene.Build(R.env, { iconDirs = Common.IconDirs() })
	local err = Common.Errors(R.env, R.K)
	assert(not err, err)
	scene.log[#scene.log + 1] = "Questie public API fixture: independent tracker and Forever native watch hooks; Medallions with RestedXP"
	return scene
end)
