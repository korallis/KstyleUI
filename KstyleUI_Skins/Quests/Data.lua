-- Data.lua: reads the tracked quests for the quest card from the game's own quest log, in the watch order Blizzard's tracker uses with the super-tracked quest first: each quest's title with Forever's level prefix, its objectives split into words and count, its complete and failed states and its item, into tables it reuses so a combat update allocates nothing.
local _, ns = ...

local Data = {}
ns.QuestData = Data

local COUNT_LEAD = "^(%d+%s*/%s*%d+)%s+(.-)%s*$"
local COUNT_TRAIL = "^(.-)%s*:?%s+(%d+%s*/%s*%d+)%s*$"
local MAX_OBJECTIVES = 6

local entries = {}
local total = 0

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Text(value)
	if IsSecret(value) or type(value) ~= "string" then
		return nil
	end
	return value
end

local function Number(value)
	if IsSecret(value) or type(value) ~= "number" then
		return nil
	end
	return value
end

local function Yes(value)
	return not IsSecret(value) and value == true
end

local function Fn(api, name)
	return type(api) == "table" and type(api[name]) == "function"
end

function Data.Available()
	local log = C_QuestLog
	return Fn(log, "GetNumQuestWatches") and Fn(log, "GetQuestIDForQuestWatchIndex") and Fn(log, "GetTitleForQuestID")
		and Fn(log, "GetQuestObjectives") and Fn(log, "IsComplete")
end

local function Entry(i)
	local entry = entries[i]
	if not entry then
		entry = { objectives = {}, count = 0 }
		entries[i] = entry
	end
	return entry
end

local function Objective(entry, i)
	local objective = entry.objectives[i]
	if not objective then
		objective = {}
		entry.objectives[i] = objective
	end
	return objective
end

local function Split(text)
	local count, words = text:match(COUNT_LEAD)
	if count then
		return words, count
	end
	words, count = text:match(COUNT_TRAIL)
	if count then
		return words, count
	end
	return text, nil
end

local function Skipped(log, id)
	if Fn(log, "IsQuestTask") and Yes(log.IsQuestTask(id)) then
		return true
	end
	return Fn(log, "IsQuestBounty") and Yes(log.IsQuestBounty(id))
end

local function Title(log, id, title)
	local level = Fn(log, "GetQuestDifficultyLevel") and Number(log.GetQuestDifficultyLevel(id))
	if not level or level <= 0 then
		return title
	end
	local elite = Fn(log, "IsEliteQuest") and Yes(log.IsEliteQuest(id))
	return "[" .. level .. (elite and "+" or "") .. "] " .. title
end

local function Objectives(log, entry, id)
	local list = log.GetQuestObjectives(id)
	local n = 0
	if type(list) == "table" then
		for i = 1, math.min(#list, MAX_OBJECTIVES) do
			local info = list[i]
			local text = type(info) == "table" and Text(info.text)
			if text and text ~= "" then
				n = n + 1
				local objective = Objective(entry, n)
				objective.text, objective.count = Split(text)
				objective.done = Yes(info.finished)
			end
		end
	end
	entry.count = n
end

local function Item(log, entry, id)
	entry.item, entry.icon = nil, nil
	local index = Fn(log, "GetLogIndexForQuestID") and Number(log.GetLogIndexForQuestID(id))
	entry.logIndex = index
	if not index or type(GetQuestLogSpecialItemInfo) ~= "function" then
		return
	end
	local link, icon, _, whenComplete = GetQuestLogSpecialItemInfo(index)
	link = Text(link)
	if not link or IsSecret(icon) or icon == nil then
		return
	end
	if entry.complete and not Yes(whenComplete) then
		return
	end
	entry.item, entry.icon = link, icon
end

local function Read(log, i, id)
	local title = Text(log.GetTitleForQuestID(id))
	if not title then
		return false
	end
	local entry = Entry(i)
	entry.id = id
	entry.title = Title(log, id, title)
	entry.complete = Yes(log.IsComplete(id))
	entry.failed = Fn(log, "IsFailed") and Yes(log.IsFailed(id)) or false
	Objectives(log, entry, id)
	Item(log, entry, id)
	return true
end

local function SuperFirst(super)
	for i = 2, total do
		if entries[i].id == super then
			local entry = entries[i]
			for k = i, 2, -1 do
				entries[k] = entries[k - 1]
			end
			entries[1] = entry
			return
		end
	end
end

function Data.Read()
	total = 0
	if not Data.Available() then
		return 0
	end
	local log = C_QuestLog
	local watches = Number(log.GetNumQuestWatches()) or 0
	for w = 1, watches do
		local id = Number(log.GetQuestIDForQuestWatchIndex(w))
		if id and id > 0 and not Skipped(log, id) and Read(log, total + 1, id) then
			total = total + 1
		end
	end
	local super = Fn(C_SuperTrack, "GetSuperTrackedQuestID") and Number(C_SuperTrack.GetSuperTrackedQuestID()) or 0
	Data.super = super
	if super > 0 then
		SuperFirst(super)
	end
	return total
end

function Data.Count()
	return total
end

function Data.Get(i)
	if i < 1 or i > total then
		return nil
	end
	return entries[i]
end
