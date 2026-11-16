-- test-skins-questcard-partial.lua: cached rows follow current watches through missing titles, withheld IDs and cache loads.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")

local function New()
	local R = Boot({ width = 5120, height = 1440 })
	local holder = R.ns.Quests.Holder()
	R.ns.QuestCard.SetShownCount(8)
	R.ns.QuestCard.Place(holder, 0, 1000, holder:GetWidth(), 1000)
	R.ns.QuestCard.Render()
	return R
end

local function Progress(R)
	for _, quest in ipairs(R.quests) do quest.objectives[1].text = "Objective: 5/7" end
	R.log.Fire("QUEST_LOG_UPDATE")
	R.settle()
end

local function Rows(R, count, missing, previous)
	assert(R.ns.QuestData.Count() == count, "the card contains only the current readable or retained watches")
	for i = 1, count do
		local entry, row = R.ns.QuestData.Get(i), R.ns.Quests.Rows()[i]
		local wanted = entry.id == missing and previous or "5/7"
		assert(row:IsShown() and row.questID == entry.id, "each current watch has its own visible row")
		assert(row.lines[1].count:GetText() == wanted, "a missing quest title must not freeze other quests' progress")
	end
	assert(#R.env._errors == 0 and R.K.ErrorCount() == 0, tostring(R.env._errors[1]))
end

local cases = {
	{ "one unavailable title", function()
		local R = New()
		local missing = R.quests[5].id
		local previous = R.ns.QuestData.Get(5).objectives[1].count
		local title = R.env.C_QuestLog.GetTitleForQuestID
		R.env.C_QuestLog.GetTitleForQuestID = function(id) if id ~= missing then return title(id) end end
		Progress(R)
		Rows(R, 8, missing, previous)
	end },
	{ "untracked quest with another title unavailable", function()
		local R = New()
		local missing = R.quests[5].id
		local previous = R.ns.QuestData.Get(5).objectives[1].count
		local title = R.env.C_QuestLog.GetTitleForQuestID
		R.env.C_QuestLog.GetTitleForQuestID = function(id) if id ~= missing then return title(id) end end
		R.log.Untrack(R.quests[2].id)
		Progress(R)
		Rows(R, 7, missing, previous)
	end },
	{ "unavailable watch ID", function()
		local R = New()
		local watch = R.env.C_QuestLog.GetQuestIDForQuestWatchIndex
		R.env.C_QuestLog.GetQuestIDForQuestWatchIndex = function(i) if i ~= 4 then return watch(i) end end
		Progress(R)
		Rows(R, 7)
		for i = 1, 7 do assert(R.ns.QuestData.Get(i).id ~= R.quests[4].id, "a nil watch ID is skipped") end
	end },
	{ "new uncached quest retries on data load", function()
		local R = New()
		local quest = { id = 999, title = "A newly cached quest", level = 10, objectives = { { text = "Objective: 5/7" } } }
		local title = R.env.C_QuestLog.GetTitleForQuestID
		local cached = false
		R.env.C_QuestLog.GetTitleForQuestID = function(id) if id ~= quest.id or cached then return title(id) end end
		R.log.Untrack(R.quests[8].id)
		R.log.Track(quest)
		Progress(R)
		Rows(R, 7)
		cached = true
		R.log.Fire("QUEST_DATA_LOAD_RESULT", quest.id, true)
		R.settle()
		Rows(R, 8)
		assert(R.ns.Quests.Rows()[8].questID == quest.id, "the newly loaded quest appears without an unrelated quest event")
	end },
	{ "untracked quest while every title is unavailable", function()
		for _, combat in ipairs({ false, true }) do
			local R = New()
			local previous = {}
			for _, row in ipairs(R.ns.Quests.Rows()) do
				previous[row.questID] = { title = row.title:GetText(), progress = row.lines[1].count:GetText() }
			end
			local abandoned = R.quests[3].id
			if combat then R.env.SetCombat(true) end
			R.env.C_QuestLog.GetTitleForQuestID = function() return nil end
			R.log.Untrack(abandoned)
			Progress(R)
			assert(R.ns.QuestData.Count() == 7, "an untracked quest must leave even when every watched title is unavailable")
			for i = 1, 7 do
				local row = R.ns.Quests.Rows()[i]
				assert(row:IsVisible() and row.questID ~= abandoned, "only still-watched quests keep their visible rows")
				local wanted = previous[row.questID]
				assert(row.title:GetText() == wanted.title and row.lines[1].count:GetText() == wanted.progress, "still-watched quests retain their cached title and progress")
			end
			assert(#R.env._errors == 0 and R.K.ErrorCount() == 0, tostring(R.env._errors[1]))
		end
	end },
	{ "withheld watch IDs retain rows and retry after combat", function()
		for _, all in ipairs({ false, true }) do
			local R = New()
			local previous = {}
			for i, row in ipairs(R.ns.Quests.Rows()) do
				previous[i] = { id = row.questID, title = row.title:GetText(), progress = row.lines[1].count:GetText() }
			end
			local watch = R.env.C_QuestLog.GetQuestIDForQuestWatchIndex
			R.env.C_QuestLog.GetQuestIDForQuestWatchIndex = function(i)
				if all or i == 1 then return R.env.Secret(watch(i)) end
				return watch(i)
			end
			R.env.SetCombat(true)
			R.quests[1].title = "Recovered watch"
			Progress(R)
			assert(R.ns.QuestData.Count() == 8, "withheld watch IDs must not remove cached quests or clear the card")
			for i, wanted in ipairs(previous) do
				local row = R.ns.Quests.Rows()[i]
				assert(row:IsVisible() and row.questID == wanted.id and row.title:GetText() == wanted.title
					and row.lines[1].count:GetText() == wanted.progress, "an unreadable watch list keeps its previous visible rows")
			end
			R.env.C_QuestLog.GetQuestIDForQuestWatchIndex = watch
			R.env.SetCombat(false)
			R.settle()
			Rows(R, 8)
			assert(R.ns.Quests.Rows()[1].title:GetText() == "[6] Recovered watch", "the after-combat retry repaints recovered watches without another quest event")
		end
	end },
	{ "whole read unavailable", function()
		for _, kind in ipairs({ "nil count", "secret count", "all titles" }) do
			local R = New()
			if kind == "all titles" then
				R.env.C_QuestLog.GetTitleForQuestID = function() return nil end
			else
				R.env.C_QuestLog.GetNumQuestWatches = function() return kind == "secret count" and R.env.Secret(8) or nil end
			end
			local previous = {}
			for i = 1, 8 do previous[i] = R.ns.Quests.Rows()[i].lines[1].count:GetText() end
			Progress(R)
			assert(R.ns.QuestData.Count() == 8, "a wholly unavailable read retains the complete list")
			for i = 1, 8 do assert(R.ns.Quests.Rows()[i].lines[1].count:GetText() == previous[i], "a wholly unavailable read preserves the visible rows") end
		end
	end },
}

local failed = 0
for _, case in ipairs(cases) do
	local ok, err = pcall(case[2])
	print(case[1] .. ": " .. (ok and "ok" or tostring(err)))
	if not ok then failed = failed + 1 end
end
assert(failed == 0, failed .. " partial quest read cases failed")
print("test-skins-questcard-partial: ok")
