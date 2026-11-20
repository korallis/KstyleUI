-- test-rails-composed.lua: story cards share their foot and eight-unit gutter, and a quest can continue under the viewport's lower fade.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local G = dofile("Tools/regression/geometry.lua")
for _, framing in ipairs({ "classic", "ring", "medallion" }) do
for _, screen in ipairs({ { width = 1920, height = 1080 }, { width = 5120, height = 1440 }, { width = 3456, height = 2234 } }) do
	screen.frame = framing
	local R = Boot(screen)
	local env, K, ns = R.env, R.K, R.ns
	R.quests[2].objectives[1].text = string.rep("Find the lost travelers near the lake. ", 2)
	R.log.Fire("QUEST_LOG_UPDATE")
	R.settle()
	local root = K.Scale.Root()
	local function Rect(frame) return assert(G.ScaledRect(frame, env.UIParent, root)) end
	local quest = ns.QuestCard.Frame()
	local guide = K.Skin.Parts(R.rxp.RXPFrame).backdrop
	local q, g = Rect(quest), Rect(guide)
	local pixel = K.Scale.Pixel(1) + 0.01
	local composed = ns.QuestCard.Parts()
	assert(composed.cap:IsShown() and ns.QuestCard.Rows()[2]:IsShown(), "lay quests out again at the composed height, with the cap and next quest visible")
	assert(math.abs(q.bottom - g.bottom) <= pixel, "side-by-side story cards share the taller card's foot")
	assert(math.abs(g.left - q.right - 8) <= pixel, "the tall quest column stands left of the guide with one eight-unit gutter")
	K.Options.Write("Skins", "restedXP.compose", false)
	R.settle()
	local oldQuest, oldGuide = Rect(quest), Rect(guide)
	assert(math.abs(oldGuide.left - oldQuest.right - K.Setup.Layouts.STORY_GAP) <= pixel, "turning story alignment off restores the previous gutter")
	K.Options.Write("Skins", "restedXP.compose", true)
	R.settle()
	ns.QuestCard.Place(root, q.left, q.top, q.right - q.left, 125)
	ns.QuestCard.Render()
	local parts = ns.QuestCard.Parts()
	local clipped = false
	for _, row in ipairs(ns.QuestCard.Rows()) do clipped = clipped or row:IsShown() and row.clipped end
	assert(clipped and parts.fade:IsShown() and parts.cap:IsShown(), "keep the cap and bind the partial quest under the lower fade")
	assert(parts.more:GetText():find("more, scroll down", 1, true), "the footer explains how to read the remaining quests")
	K.Options.Write("Skins", "quests.continuation", false)
	assert(not parts.fade:IsShown(), "turning quest continuation off restores complete-row pages without a fade")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
end
print("composed story rail ok: Classic continuation and all three minimap frames")

do
	local R = Boot({ width = 1920, height = 1080 })
	local chrome = R.ns.RestedXP.Chrome
	local refit, calls = chrome.Refit, 0
	chrome.Refit = function(...)
		calls = calls + 1
		return refit(...)
	end
	R.env.SetCombat(true)
	R.K.Options.Write("Skins", "restedXP.compose", false)
	assert(calls == 0, "story alignment changes must defer guide movement during combat")
	R.env.SetCombat(false)
	R.settle()
	assert(calls > 0, "story alignment applies when combat ends")
	local guide = R.K.Skin.Parts(R.rxp.RXPFrame).backdrop
	local previousHeight = guide:GetHeight()
	R.K.Store.CopyProfile(R.K.Store.ProfileName(), "Previous finish")
	R.K.Options.Write("Skins", "restedXP.compose", true)
	R.settle()
	R.K.Store.SetProfile("Previous finish")
	R.settle()
	assert(math.abs(guide:GetHeight() - previousHeight) < 0.01, "profile changes must restore the previous guide height")
end

for _, count in ipairs({ 1, 4, 8 }) do
	local R = Boot({ width = 1920, height = 1080 })
	for i = 8, count + 1, -1 do R.log.Untrack(R.quests[i].id) end
	R.settle()
	assert(R.ns.QuestData.Count() == count and R.rxp.RXPFrame:IsVisible(), "one, four and eight quests keep the guide visible")
	assert(R.ns.Quests.Rows()[1]:IsShown(), "one, four and eight quests keep a first row")
	assert(#R.env._errors == 0 and R.K.ErrorCount() == 0, tostring(R.env._errors[1]))
end
