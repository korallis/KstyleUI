-- test-rails-composed.lua: story cards share their foot and eight-unit gutter, and a quest can continue under the viewport's lower fade.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local G = dofile("Tools/regression/geometry.lua")
for _, screen in ipairs({ { width = 1920, height = 1080 }, { width = 5120, height = 1440 }, { width = 3456, height = 2234 } }) do
	local R = Boot(screen)
	local env, K, ns = R.env, R.K, R.ns
	local root = K.Scale.Root()
	local function Rect(frame) return assert(G.ScaledRect(frame, env.UIParent, root)) end
	local quest = ns.QuestCard.Frame()
	local guide = K.Skin.Parts(R.rxp.RXPFrame).backdrop
	local q, g = Rect(quest), Rect(guide)
	local pixel = K.Scale.Pixel(1) + 0.01
	assert(math.abs(q.bottom - g.bottom) <= pixel, "side-by-side story cards share the taller card's foot")
	assert(math.abs(q.left - g.right - 8) <= pixel, "side-by-side story cards share one eight-unit gutter: " .. q.left .. " - " .. g.right)
	K.Options.Write("Skins", "restedXP.compose", false)
	R.settle()
	local oldQuest, oldGuide = Rect(quest), Rect(guide)
	assert(math.abs(oldQuest.left - oldGuide.right - K.Setup.Layouts.STORY_GAP) <= pixel, "turning story alignment off restores the previous gutter")
	K.Options.Write("Skins", "restedXP.compose", true)
	R.settle()
	ns.QuestCard.Place(root, q.left, q.top, q.right - q.left, 125)
	ns.QuestCard.Render()
	local parts = ns.QuestCard.Parts()
	local clipped = false
	for _, row in ipairs(ns.QuestCard.Rows()) do clipped = clipped or row:IsShown() and row.clipped end
	assert(clipped and parts.fade:IsShown() and parts.cap.row:IsShown(), "keep the cap and bind the partial quest under the lower fade")
	assert(parts.more:GetText():find("more, scroll down", 1, true), "the footer explains how to read the remaining quests")
	K.Options.Write("Skins", "quests.continuation", false)
	assert(not parts.fade:IsShown(), "turning quest continuation off restores complete-row pages without a fade")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
print("composed story rail ok")

for _, count in ipairs({ 1, 4, 8 }) do
	local R = Boot({ width = 1920, height = 1080 })
	for i = 8, count + 1, -1 do R.log.Untrack(R.quests[i].id) end
	R.settle()
	assert(R.ns.QuestData.Count() == count and R.rxp.RXPFrame:IsVisible(), "one, four and eight quests keep the guide visible")
	assert(R.ns.Quests.Rows()[1]:IsShown(), "one, four and eight quests keep a first row")
	assert(#R.env._errors == 0 and R.K.ErrorCount() == 0, tostring(R.env._errors[1]))
end
