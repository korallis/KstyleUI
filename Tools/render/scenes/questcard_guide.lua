-- questcard_guide.lua: the Medallions quest card, open RestedXP guide and docked boxes in one environment; RENDER_QUEST_COLLAPSED=1 clicks the card's header to fold it; RENDER_COMBAT=1 RENDER_COMBAT_STEP=1 grows the guide's step to five lines in combat.
local Common = dofile("Tools/render/scenes/_common.lua")
local Boot = dofile("Tools/regression/questcard_guide_env.lua")

return Common.Run(function()
	local R = Boot(Common.SCREEN, os.getenv("RENDER_QUEST_ITEM") == "1", Common.PreviousFinish())
	local style = (os.getenv("RENDER_HUD_STYLE") or "Medallions"):lower()
	R.K.Options.Write("HudStyle", "style", style)
	local guideScale = tonumber(os.getenv("RENDER_GUIDE_SCALE"))
	if guideScale then R.rxp.RXPFrame:SetScale(R.rxp.RXPFrame:GetScale() * guideScale) end
	R.settle()
	for _ = 1, tonumber(os.getenv("RENDER_QUEST_SCROLL")) or 0 do
		local card = R.ns.Quests.Card()
		card:GetScript("OnMouseWheel")(card, -1)
	end
	R.rxp.activeItemFrame.buttonList[1].icon:SetTexture(132794)
	R.rxp.targeting.activeTargetFrame.enemyTargetButtons[1].icon:SetTexture(136188)
	if os.getenv("RENDER_COMBAT") == "1" then
		R.env.SetCombat(true)
		if os.getenv("RENDER_COMBAT_STEP") == "1" then
			R.rxp.fake.guide({ { index = 12, elements = {
				{ text = "Talk to |cRXP_FRIENDLY_Gina Lang|r on the second floor", textOnly = true },
				{ text = "Turn in Gloom Weed" }, { text = "Accept Doom Weed" }, { text = "Train your spells", textOnly = true }, { text = "Vendor Trash", textOnly = true },
			} } })
			R.rxp.SetStep(1)
		end
		R.rxp.SetStep()
		R.log.Fire("QUEST_LOG_UPDATE")
		R.settle()
	end
	if os.getenv("RENDER_QUEST_TITLES") == "unavailable" then
		R.env.C_QuestLog.GetTitleForQuestID = function() return nil end
		R.log.Fire("QUEST_LOG_UPDATE")
		R.settle()
	end
	if os.getenv("RENDER_STORY_SHRINK") == "1" then
		for i = #R.quests, 2, -1 do R.log.Untrack(R.quests[i].id) end
		R.rxp.fake.guide({ { index = 12, elements = { { text = "Talk to Joshua", textOnly = true } } } })
		R.rxp.SetStep()
		R.settle()
	end
	if os.getenv("RENDER_QUEST_PARTY") then
		local Party = dofile("Tools/regression/party_quests_fake.lua")
		local p = Party.Install(R.env, R.log)
		R.quests[1].title = "Bloodscalp Headhunters"
		R.quests[1].objectives = { { text = "Bloodscalp Headhunters: 1/8" }, { text = "Canvas Scraps: 0/3" } }
		R.log.Fire("QUEST_LOG_UPDATE")
		R.settle()
		p.Hover(R.ns, os.getenv("RENDER_QUEST_PARTY") == "before")
		R.settle()
	end
	if os.getenv("RENDER_QUEST_COLLAPSED") == "1" then
		local toggle = R.ns.Quests.Parts().toggle
		toggle:GetScript("OnClick")(toggle, "LeftButton")
		R.settle()
	end
	local scene = Common.Scene.Build(R.env, { iconDirs = Common.IconDirs() })
	local err = Common.Errors(R.env, R.K)
	assert(not err, err)
	scene.log[#scene.log + 1] = style .. " warlock: quest card and open guide share one environment; combat=" .. tostring(R.env.InCombatLockdown())
	scene.log[#scene.log + 1] = "quest rows=" .. R.ns.QuestData.Count() .. " read=" .. tostring(R.ns.QuestData.status)
	return scene
end)
