-- test-skins-questcard-guide.lua: the open Medallions guide keeps quest rows through combat updates and unavailable titles.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")

for _, screen in ipairs({ { width = 5120, height = 1440 }, { width = 3456, height = 2234 } }) do
	for _, item in ipairs({ false, true }) do
		local R = Boot(screen, item)
		local env, K, ns, rxp = R.env, R.K, R.ns, R.rxp
		local function Check()
			assert(rxp.RXPFrame:IsShown() and ns.RestedXP.Rail.Placed(), "the guide is open on its rail")
			assert(ns.QuestData.Count() == 8 and ns.Quests.Rows()[1]:IsVisible(), "combat guide updates keep all tracked quests and a visible first row")
			assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
		end
		Check()
		env.SetCombat(true)
		R.quests[1].objectives[1].text = "Putrid Claw: 1/7"
		rxp.SetStep(6, 6)
		R.log.Fire("QUEST_LOG_UPDATE")
		R.settle()
		Check()
		assert(ns.Quests.Rows()[1].lines[1].count:GetText() == "1/7", "public progress still repaints in combat")
		rxp.RXPFrame:Hide()
		rxp.RXPFrame:Show()
		R.settle()
		Check()
		local title = env.C_QuestLog.GetTitleForQuestID
		env.C_QuestLog.GetTitleForQuestID = function() return nil end
		R.log.Fire("QUEST_LOG_UPDATE")
		R.settle()
		Check()
		env.C_QuestLog.GetTitleForQuestID = title
		local parts = ns.Quests.Parts()
		local rect = parts.view.GetRect
		parts.view.GetRect = function() error("restricted region measurement") end
		local before = #K.Store.Data().devlog
		ns.QuestCard.CheckDiagnostic()
		local recorded = false
		for i = before + 1, #K.Store.Data().devlog do
			local message = K.Store.Data().devlog[i].message
			if message:find("automatic=measurement-unavailable", 1, true) then recorded = true end
		end
		assert(recorded, "a restricted combat measurement records the unknown visibility and guide context")
		parts.view.GetRect = rect
		env.SetCombat(false)
		R.log.Fire("QUEST_LOG_UPDATE")
		R.settle()
		Check()
		R.log.quests = {}
		R.log.Fire("QUEST_WATCH_LIST_CHANGED")
		R.settle()
		assert(ns.QuestData.Count() == 0 and not ns.Quests.Card():IsShown(), "a genuinely empty watch list clears the card")
	end
end

print("test-skins-questcard-guide: ok")
