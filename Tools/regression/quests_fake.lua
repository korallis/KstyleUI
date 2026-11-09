-- quests_fake.lua: Forever's quest log, super tracking and objective tracker as the quest card reads them, for a
-- Skins stub environment.
--
--   local Quests = dofile("Tools/regression/quests_fake.lua")
--   local log = Quests.Install(env, Quests.List(10))     -- in S.New's setup
--   local tracker = Quests.Tracker(env, S.Blizzard(env))  -- in S.New's before: ObjectiveTrackerFrame and its modules
--
-- Install puts C_QuestLog, C_SuperTrack, GetQuestLogSpecialItemInfo, GetQuestLogSpecialItemCooldown,
-- QuestMapFrame_OpenToQuestDetails, IsModifiedClick and MenuUtil on env, answering from log.quests in watch
-- order. Each quest is { id, title, level, objectives = { { text, finished } }, complete, failed, item = { link,
-- icon } }. log.Fire(event, ...) changes nothing but fires the event; log.Untrack(id) and log.Track(quest) edit the
-- watch list and fire QUEST_WATCH_LIST_CHANGED, as the game does; log.calls records each call the card made to an
-- action (RemoveQuestWatch, SetSuperTrackedQuestID, OpenToQuestDetails, CreateContextMenu).
--
-- The API shapes come from the forever branch of wow-ui-source: Blizzard_APIDocumentationGenerated/
-- QuestLogDocumentation.lua (GetQuestObjectives returns QuestObjectiveInfo tables: text, type, finished,
-- numFulfilled, numRequired) and Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerShared.lua (the legacy
-- GetQuestLogSpecialItemInfo returns link, icon, charges, showItemWhenComplete for a log index).
local Fake = {}

local OBJECTIVE_WORDS = { "Crocolisk Hide", "Taillasher Egg", "Bloodtalon Scythemaw", "Kul Tiras Sailor slain", "Canvas Scraps" }
local TITLES = {
	"Threat from Below", "Break a Few Eggs", "Encroachment", "The Admiral's Orders", "Dark Storms", "Crab Season",
	"Camping 101: First Aid", "Aid For The Refugees", "A Grand Adventure", "The Fate of a Loved One", "Call of Fire",
	"Unnerving Silence", "Riverglade Crocolisks", "The Lost Patrol", "Kuramaa's Mask", "Windsong Meat",
	"Echoes of the Tide", "A Hunter's Pact", "The Ashen Road", "Sunken Relics", "Marsh Lanterns", "The Hollow Crown",
	"Bones in the Reeds", "Stormwatch", "A Last Ember",
}

-- List(n, lines) -> n quests: ids 301 up, levels 6 up, one or two counted objectives each, or lines objectives each.
function Fake.List(n, lines)
	local out = {}
	for i = 1, n do
		local need = 2 + (i % 5)
		local objectives = { { text = OBJECTIVE_WORDS[(i % #OBJECTIVE_WORDS) + 1] .. ": " .. (i % need) .. "/" .. need, finished = false } }
		if i % 3 == 0 then
			objectives[2] = { text = "Speak to Ranger Kalanna", finished = false }
		end
		for k = #objectives + 1, lines or 0 do
			objectives[k] = { text = OBJECTIVE_WORDS[((i + k) % #OBJECTIVE_WORDS) + 1] .. ": 0/" .. k, finished = false }
		end
		out[i] = { id = 300 + i, title = TITLES[((i - 1) % #TITLES) + 1], level = 5 + i, objectives = objectives }
	end
	return out
end

local function Find(log, id)
	for index, quest in ipairs(log.quests) do
		if quest.id == id then
			return quest, index
		end
	end
end

local function Counts(text)
	local have, need = text:match("(%d+)%s*/%s*(%d+)")
	return tonumber(have) or 0, tonumber(need) or 1
end

function Fake.Install(env, quests)
	local log = { quests = quests or {}, super = 0, calls = {}, modified = {} }
	local function Call(name, ...)
		log.calls[#log.calls + 1] = { name = name, args = { ... } }
	end
	env.C_QuestLog = {
		GetNumQuestWatches = function()
			return #log.quests
		end,
		GetQuestIDForQuestWatchIndex = function(i)
			local quest = log.quests[i]
			return quest and quest.id
		end,
		GetLogIndexForQuestID = function(id)
			local _, index = Find(log, id)
			return index
		end,
		GetTitleForQuestID = function(id)
			local quest = Find(log, id)
			return quest and quest.title
		end,
		GetQuestDifficultyLevel = function(id)
			local quest = Find(log, id)
			return quest and quest.level or 0
		end,
		IsEliteQuest = function(id)
			local quest = Find(log, id)
			return quest ~= nil and quest.elite == true
		end,
		IsComplete = function(id)
			local quest = Find(log, id)
			return quest ~= nil and quest.complete == true
		end,
		IsFailed = function(id)
			local quest = Find(log, id)
			return quest ~= nil and quest.failed == true
		end,
		IsPushableQuest = function()
			return true
		end,
		GetQuestObjectives = function(id)
			local quest = Find(log, id)
			local out = {}
			for i, objective in ipairs(quest and quest.objectives or {}) do
				local have, need = Counts(objective.text)
				out[i] = { text = objective.text, type = "monster", finished = objective.finished == true, numFulfilled = have, numRequired = need }
			end
			return out
		end,
		RemoveQuestWatch = function(id)
			Call("RemoveQuestWatch", id)
			log.Untrack(id)
			return true
		end,
	}
	env.C_SuperTrack = {
		GetSuperTrackedQuestID = function()
			return log.super
		end,
		SetSuperTrackedQuestID = function(id)
			Call("SetSuperTrackedQuestID", id)
			log.super = id
			env.FireEvent("SUPER_TRACKING_CHANGED")
		end,
	}
	env.GetQuestLogSpecialItemInfo = function(index)
		local quest = log.quests[index]
		local item = quest and quest.item
		if not item then
			return nil
		end
		return item.link, item.icon, item.charges or 0, item.showWhenComplete == true
	end
	env.GetNumAutoQuestPopUps = function()
		return log.popups or 0
	end
	env.GetQuestLogSpecialItemCooldown = function()
		return 0, 0, 1
	end
	env.QUEST_WATCH_QUEST_READY = "Ready for turn-in"
	env.FAILED = "Failed"
	env.SUPER_TRACK_QUEST = "Focus"
	env.STOP_SUPER_TRACK_QUEST = "Stop focusing"
	env.OBJECTIVES_SHOW_QUEST_MAP = "Show on map"
	env.OBJECTIVES_STOP_TRACKING = "Stop tracking"
	env.SHARE_QUEST = "Share quest"
	env.QuestMapFrame_OpenToQuestDetails = function(id)
		Call("OpenToQuestDetails", id)
	end
	env.IsModifiedClick = function(action)
		return log.modified[action] == true
	end
	env.MenuUtil = {
		CreateContextMenu = function(owner, generator)
			Call("CreateContextMenu", owner)
			local entries = {}
			local description = {}
			function description.SetTag() end
			function description.CreateTitle(_, text)
				entries[#entries + 1] = { title = text }
			end
			function description.CreateButton(_, text, fn)
				entries[#entries + 1] = { text = text, fn = fn }
			end
			generator(owner, description)
			log.menu = entries
		end,
	}
	function log.Fire(event, ...)
		env.FireEvent(event, ...)
	end
	function log.Untrack(id)
		local _, index = Find(log, id)
		if index then
			table.remove(log.quests, index)
			env.FireEvent("QUEST_WATCH_LIST_CHANGED", id, false)
		end
	end
	function log.Track(quest)
		log.quests[#log.quests + 1] = quest
		env.FireEvent("QUEST_WATCH_LIST_CHANGED", quest.id, true)
	end
	function log.Called(name)
		local out = {}
		for _, call in ipairs(log.calls) do
			if call.name == name then
				out[#out + 1] = call
			end
		end
		return out
	end
	return log
end

-- Tracker(env, B) -> ObjectiveTrackerFrame, built as _tracker.lua builds it (the quest module laid out the way
-- Blizzard_ObjectiveTracker does), with the campaign and scenario modules beside it as Forever's
-- ObjectiveTrackerManager:Init adds them. tracker.scenario.contentsHeight > 0 is a scenario stage on show;
-- tracker:Update() runs the container's update, which ends in UpdateHeaderPosition as the game's does.
function Fake.Tracker(env, B)
	local StandIn = dofile("Tools/render/scenes/_tracker.lua")
	local tracker, quests = StandIn.StandIn(env, B, StandIn.QUESTS)
	local function Module(name)
		local module = B.frame("Frame", tracker, name)
		module.contentsHeight = 0
		function module.GetContentsHeight(self)
			return self.contentsHeight
		end
		function module.HasContents(self)
			return self.contentsHeight > 0
		end
		return module
	end
	env.QuestObjectiveTracker = quests
	local campaign = Module("CampaignQuestObjectiveTracker")
	local scenario = Module("ScenarioObjectiveTracker")
	tracker.scenario, tracker.campaign, tracker.quests = scenario, campaign, quests
	local order = { scenario, campaign, quests }
	function tracker.ForEachModule(_, fn)
		for _, module in ipairs(order) do
			fn(module)
		end
	end
	return tracker
end

return Fake
