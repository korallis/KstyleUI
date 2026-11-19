-- questie_fake.lua: Questie's public tracker API, independent frame and Forever watch hooks (Questie/Questie 58f8a2c, Modules/Tracker/QuestieTracker.lua and Modules/QuestieCompat.lua).
local Fake = {}

function Fake.Install(env, log, enabled, started)
	env._loaded.Questie = true
	local frame = env.CreateFrame("Frame", "Questie_BaseFrame", env.UIParent)
	frame:SetSize(290, 370)
	frame:SetPoint("TOPRIGHT", env.UIParent, "TOPRIGHT", -35, -240)
	local profile = { trackerEnabled = enabled ~= false }
	env.Questie = { db = { profile = profile } }
	local tracker = { started = started ~= false, calls = 0, watched = {}, frame = frame }
	local watches = {}
	for i, quest in ipairs(log.quests) do
		tracker.watched[quest.id] = true
		if i < #log.quests then watches[#watches + 1] = quest.id end
	end
	local api = env.C_QuestLog
	api.GetNumQuestWatches = function() return #watches end
	api.GetQuestIDForQuestWatchIndex = function(i) return watches[i] end
	api.GetNumQuestLogEntries = function() return #log.quests, #log.quests end
	api.GetInfo = function(i) return log.quests[i] and { questID = log.quests[i].id } end
	api.AddQuestWatch = function(id)
		for _, watched in ipairs(watches) do if watched == id then return true end end
		watches[#watches + 1] = id
		env.FireEvent("QUEST_WATCH_LIST_CHANGED", id, true)
		return true
	end
	api.RemoveQuestWatch = function(id)
		for i, watched in ipairs(watches) do
			if watched == id then table.remove(watches, i); break end
		end
		env.FireEvent("QUEST_WATCH_LIST_CHANGED", id, false)
	end
	env.hooksecurefunc(api, "AddQuestWatch", function(id)
		if profile.trackerEnabled then tracker.watched[id] = true end
	end)
	env.hooksecurefunc(api, "RemoveQuestWatch", function(id)
		if profile.trackerEnabled then tracker.watched[id] = nil end
	end)
	function tracker.IsTrackedByQuestie(id) return tracker.watched[id] == true end
	function tracker:Update()
		if not self.started or env.InCombatLockdown() then return end
		env.C_Timer.After(0.1, function()
			local was = frame:IsShown()
			frame:SetShown(profile.trackerEnabled)
			if was and not profile.trackerEnabled then
				local hide = frame:GetScript("OnHide")
				if hide then hide(frame) end
			end
		end)
	end
	function tracker:Toggle()
		assert(not env.InCombatLockdown(), "Questie's option must wait for combat to end")
		self.calls = self.calls + 1
		profile.trackerEnabled = not profile.trackerEnabled
		self:Update()
	end
	function tracker:Enable()
		profile.trackerEnabled = true
		self.reloaded = true
	end
	local compat = {}
	function compat.HideWatchFrame()
		tracker.suppressed = true
		env.ObjectiveTrackerFrame:SetAlpha(0)
	end
	function compat.ShowWatchFrame()
		if tracker.suppressed then
			tracker.suppressed = false
			env.ObjectiveTrackerFrame:SetAlpha(1)
			env.ObjectiveTrackerFrame:Show()
		end
	end
	env.QuestieLoader = { ImportModule = function(_, name)
		if name == "QuestieTracker" then return tracker end
		assert(name == "QuestieCompat", "only Questie's public tracker and compatibility APIs are needed")
		return compat
	end }
	tracker.compat = compat
	if profile.trackerEnabled then compat.HideWatchFrame() end
	frame:SetShown(profile.trackerEnabled and tracker.started)
	local parent = frame
	local function Text(value, y, size)
		local text = parent:CreateFontString(nil, "OVERLAY")
		text:SetFont("Fonts\\FRIZQT__.TTF", size, "")
		text:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
		text:SetText(value)
	end
	Text("Questie Tracker: 8/40", 0, 13)
	for i, quest in ipairs(log.quests) do
		Text(i == 1 and "Cooking" or i == 3 and "Riverglades" or "", -i * 38 + 10, 12)
		Text("[" .. quest.level .. "] " .. quest.title, -i * 38 - 3, 12)
		Text(quest.objectives[1].text, -i * 38 - 17, 11)
	end
	return tracker
end

return Fake
