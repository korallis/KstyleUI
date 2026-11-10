-- KstyleUI_Skins.lua: the quest card's combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local S = dofile("Tools/regression/skins_env.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")

-- Card(items) -> env, run: the quest card with 25 tracked quests, its throttled QUEST_LOG_UPDATE read and redraw as
-- one call; 100 calls a round keep the allocation trace inside the file's 20 s. items puts a quest item on the first
-- quest, so the rows hold still while its secure button shows. The card runs at the shipped Interface size (16/19),
-- as the game does: the picture's right rail (LEE-20) leaves the story slot room for the rows only at that size.
local function Card(items)
	local log
	local env, K = S.New({
		saved = { version = 12, profiles = { Default = { Appearance = { uiScale = 16 / 19 } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = function(env)
			local list = Quests.List(25)
			if items then
				list[1].item = { link = "|cffffffff|Hitem:5179::::::::|h[Moss-Twined Heart]|h|r", icon = 134339 }
			end
			log = Quests.Install(env, list)
			log.super = 307
		end,
		before = function(env)
			Quests.Tracker(env, S.Blizzard(env))
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	local fire = Perf.Event(env, "QUEST_LOG_UPDATE")
	return env, function()
		fire()
		env.RunTimers()
	end
end

return {
	{
		name = "Skins quest card QUEST_LOG_UPDATE, 25 quests",
		budget = 4500,
		calls = 100,
		setup = function()
			return Card(false)
		end,
	},
	{
		name = "Skins quest card QUEST_LOG_UPDATE, 25 quests, an item button up",
		budget = 2600,
		calls = 100,
		setup = function()
			return Card(true)
		end,
	},
}
