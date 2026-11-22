-- test-skins-questcard-combat.lua: an eight-quest card keeps its header, first quest and overflow footer above its material through combat calm and quest progress updates, with and without a secure quest item.
local S = dofile("Tools/regression/skins_env.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local RestedXP = dofile("Tools/regression/restedxp_fake.lua")
local Scene = dofile("Tools/render/scene.lua")

local function Drawable(scene, object)
	for i, item in ipairs(scene.items) do
		if item.object == object then
			return item, i
		end
	end
	error("the quest card lost a drawable: " .. tostring(object:GetText()))
end

for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 } }) do
	for _, itemOn in ipairs({ false, true }) do
		local log
		local quests = Quests.List(8, 1)
		quests[1].title = "A Putrid Task"
		quests[1].objectives = { { text = "Putrid Claw: 0/7", finished = false } }
		if itemOn then
			quests[1].item = { link = "item:5179", icon = 134339 }
		end
		local env, K, ns = S.New({
			width = screen[1], height = screen[2],
			saved = {
				version = 12, profiles = { Default = { } },
				characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
			},
			setup = function(env)
				log = Quests.Install(env, quests)
				RestedXP.Install(env, {})
				env._textWidth = function(text, path, size)
					return Scene.TextWidth(text, size, path)
				end
			end,
			before = function(env)
				Quests.Tracker(env, S.Blizzard(env))
			end,
		})
		K.Modules.Enable("Skins")
		S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
		env.RunTimers()
		S.W.Settle(env)
		K.Options.Write("Skins", "quests.shown", 1)
		env.RunTimers()
		S.W.Settle(env)
		local card, parts = ns.Quests.Card(), ns.Quests.Parts()
		local holder = ns.Quests.Holder()
		ns.QuestCard.Place(holder, 0, holder:GetHeight(), holder:GetWidth(), 200)
		ns.QuestCard.Render()
		local row = ns.Quests.Rows()[1]
		local function Check(count)
			local scene = Scene.Build(env)
			local _, glass = Drawable(scene, parts.glass.chrome.fill[5])
			local cap, capIndex = Drawable(scene, parts.cap.label)
			local title, titleIndex = Drawable(scene, row.title)
			local progress, progressIndex = Drawable(scene, row.lines[1].count)
			local footer, footerIndex = Drawable(scene, parts.more)
			assert(cap.text == "QUESTS" and Drawable(scene, parts.cap.count).text == "8", "the header keeps the tracked count")
			assert(title.text == "[6] A Putrid Task" and progress.text == count, "the first quest keeps its current progress")
			assert(footer.text == "7 more, scroll down", "the footer advertises the other seven quests")
			for _, index in ipairs({ capIndex, titleIndex, progressIndex, footerIndex }) do
				assert(index > glass, "all quest content draws above the card's material")
			end
			assert(cap.alpha >= 0.89 and title.alpha >= 0.89 and progress.alpha >= 0.89 and footer.alpha >= 0.89, "combat calm keeps all quest content legible")
			assert(parts.cap:IsVisible() and parts.view:IsVisible() and row:IsVisible(), "the header and quest view stay visible")
			assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
		end
		Check("0/7")
		local top, height = select(5, card:GetPoint(1)), card:GetHeight()
		env.SetCombat(true)
		S.W.Settle(env)
		Check("0/7")
		quests[1].objectives[1].text = "Putrid Claw: 1/7"
		log.Fire("QUEST_LOG_UPDATE")
		env.RunTimers()
		S.W.Settle(env)
		Check("1/7")
		assert(card:GetHeight() == height and select(5, card:GetPoint(1)) == top, "a combat progress update does not move or resize the card")
		env.SetCombat(false)
		env.RunTimers()
		S.W.Settle(env)
		Check("1/7")
	end
end

print("test-skins-questcard-combat: ok")
