-- Data.lua: reads tracked quest titles, objectives, states and items in watch order, reusing cached quest tables and allocating entries and objective tables as needed.
local _, ns = ...

local Data = {}
ns.QuestData = Data

local COUNT_LEAD = "^(%d+%s*/%s*%d+)%s+(.-)%s*$"
local COUNT_TRAIL = "^(.-)%s*:?%s+(%d+%s*/%s*%d+)%s*$"
local MAX_OBJECTIVES = 6

local entries, previous = {}, {}
local total = 0
local watchIDs, watchTitles, order = {}, {}, {}
local changed

local function Set(entry, key, value)
	if entry[key] ~= value then
		entry[key], changed = value, true
	end
end

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

local function Previous(id, count)
	for i = 1, count do
		if previous[i].id == id then
			return previous[i]
		end
	end
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
	if type(log.IsQuestTask) == "function" and Yes(log.IsQuestTask(id)) then
		return true
	end
	return type(log.IsQuestBounty) == "function" and Yes(log.IsQuestBounty(id))
end

local function Title(log, id, title)
	local level = type(log.GetQuestDifficultyLevel) == "function" and Number(log.GetQuestDifficultyLevel(id))
	if not level or level <= 0 then
		return title
	end
	local elite = type(log.IsEliteQuest) == "function" and Yes(log.IsEliteQuest(id))
	return "[" .. level .. (elite and "+" or "") .. "] " .. title
end

local function Objectives(log, entry, id)
	local list = log.GetQuestObjectives(id)
	local n = 0
	if type(list) == "table" then
		local length = #list
		for i = 1, math.min(length, MAX_OBJECTIVES) do
			local info = list[i]
			local text = type(info) == "table" and Text(info.text)
			if text and text ~= "" then
				n = n + 1
				local objective = Objective(entry, n)
				local words, count = Split(text)
				Set(objective, "text", words)
				Set(objective, "count", count)
				Set(objective, "done", Yes(info.finished))
			end
		end
		if length > MAX_OBJECTIVES then n = n + length - MAX_OBJECTIVES end
	end
	Set(entry, "count", n)
end

local function Item(log, entry, id)
	local index = type(log.GetLogIndexForQuestID) == "function" and Number(log.GetLogIndexForQuestID(id))
	Set(entry, "logIndex", index)
	if not index or type(GetQuestLogSpecialItemInfo) ~= "function" then
		Set(entry, "item", nil)
		Set(entry, "icon", nil)
		return
	end
	local link, icon, _, whenComplete = GetQuestLogSpecialItemInfo(index)
	link = Text(link)
	if not link or IsSecret(icon) or icon == nil then
		Set(entry, "item", nil)
		Set(entry, "icon", nil)
		return
	end
	if entry.complete and not Yes(whenComplete) then
		Set(entry, "item", nil)
		Set(entry, "icon", nil)
		return
	end
	Set(entry, "item", link)
	Set(entry, "icon", icon)
end

local function Read(log, entry, id, title)
	Set(entry, "id", id)
	Set(entry, "title", Title(log, id, title))
	Set(entry, "complete", Yes(log.IsComplete(id)))
	Set(entry, "failed", type(log.IsFailed) == "function" and Yes(log.IsFailed(id)) or false)
	Objectives(log, entry, id)
	Item(log, entry, id)
	return entry
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
	changed, Data.changed = false, false
	if not Data.Available() then
		Data.status = "api-unavailable"
		return total
	end
	local log = C_QuestLog
	local watches = Number(log.GetNumQuestWatches())
	Data.watches = watches
	if not watches then
		Data.status = "watches-unavailable"
		return total
	end
	local count, status = 0, "ready"
	for w = 1, watches do
		local id = log.GetQuestIDForQuestWatchIndex(w)
		if IsSecret(id) then
			Data.status = "watch-id-withheld"
			return total
		end
		id = Number(id)
		if not id or id <= 0 then
			status = "watch-id-unavailable"
		elseif not Skipped(log, id) then
			local title = Text(log.GetTitleForQuestID(id))
			if not title then status = "title-unavailable" end
			count = count + 1
			watchIDs[count], watchTitles[count] = id, title
		end
	end
	Data.status = status
	local before = total
	entries, previous = previous, entries
	total = 0
	Data.status = "reading"
	for i = 1, count do
		local id, title = watchIDs[i], watchTitles[i]
		local entry = Previous(id, before)
		if title then
			entry = Read(log, entry or { objectives = {} }, id, title)
		end
		if entry then
			total = total + 1
			entries[total] = entry
		end
	end
	for i = #entries, total + 1, -1 do entries[i] = nil end
	Data.status = status
	local super = Fn(C_SuperTrack, "GetSuperTrackedQuestID") and Number(C_SuperTrack.GetSuperTrackedQuestID()) or 0
	Data.super = super
	if super ~= Data.previousSuper then
		Data.previousSuper, changed = super, true
	end
	if super > 0 then
		SuperFirst(super)
	end
	for i = 1, math.max(before, total) do
		local id = entries[i] and entries[i].id
		if order[i] ~= id then
			order[i], changed = id, true
		end
	end
	Data.changed = changed or total ~= before
	return total
end

function Data.Count()
	return total
end

function Data.ImportQuestie(tracker)
	local log = C_QuestLog
	if not (Fn(log, "GetNumQuestLogEntries") and Fn(log, "GetInfo") and Fn(log, "AddQuestWatch")
		and type(tracker.IsTrackedByQuestie) == "function") then return end
	local count = Number(log.GetNumQuestLogEntries())
	for i = 1, count or 0 do
		local info = log.GetInfo(i)
		local id = not IsSecret(info) and type(info) == "table" and Number(info.questID)
		if id and id > 0 and Yes(tracker.IsTrackedByQuestie(id)) then log.AddQuestWatch(id) end
	end
end

function Data.Get(i)
	if i < 1 or i > total then
		return nil
	end
	return entries[i]
end

do
	local K = KstyleUI
	local Party = {}
	ns.QuestParty = Party
	local OWNER, PREFIX, LIMIT = "Skins.Quests.Party", "KstyleQuest1", 240
	local enabled, registered, pending, generation = false, false, false, 0
	local peers, sent, queue, stale = {}, {}, {}, true
	local tip, hovered

	local function Grouped()
		if not enabled or not Fn(_G, "GetNumGroupMembers") or not Fn(_G, "IsInRaid") then return false end
		local raid, count = IsInRaid(), Number(GetNumGroupMembers())
		return not IsSecret(raid) and raid == false and count ~= nil and count > 1 and count <= 5
	end

	local function Name(unit)
		if not Fn(_G, "UnitFullName") then return end
		local name, realm = UnitFullName(unit)
		name, realm = Text(name), Text(realm) or ""
		if not name then return end
		if realm == "" and Fn(_G, "GetNormalizedRealmName") then realm = Text(GetNormalizedRealmName()) end
		if not realm or realm == "" then return end
		return name .. "-" .. realm, name
	end

	local function Integer(value)
		value = Number(value)
		return value and value >= 0 and value <= 10000000 and value == math.floor(value) and value or nil
	end

	function Party.Encode(id, complete, objectives)
		if not Integer(id) or id == 0 or IsSecret(complete) or IsSecret(objectives) or type(objectives) ~= "table" then return end
		local parts = {}
		for i = 1, math.min(#objectives, MAX_OBJECTIVES) do
			local o = objectives[i]
			if IsSecret(o) or type(o) ~= "table" then return end
			local have, need = Integer(o.numFulfilled), Integer(o.numRequired)
			if not have or not need or IsSecret(o.finished) then return end
			parts[i] = have .. "/" .. need .. "/" .. (Yes(o.finished) and "1" or "0")
		end
		local record = id .. ":" .. (Yes(complete) and "1" or "0") .. ":" .. table.concat(parts, ",")
		return #record <= LIMIT - 3 and record or nil
	end

	function Party.Decode(message)
		message = Text(message)
		if not message or #message > LIMIT or message:sub(1, 2) ~= "1;" then return end
		local result, used = {}, 2
		for record in message:sub(3):gmatch("([^;]+);") do
			used = used + #record + 1
			local id, flag, body = record:match("^(%d+):([01]):(.*)$")
			local removed = record:match("^(%d+):%-$")
			id = Integer(tonumber(id or removed))
			if not id or id == 0 or result[id] ~= nil then return end
			if removed then
				result[id] = false
			else
				local objectives, length = {}, 0
				for piece in (body .. ","):gmatch("([^,]+),") do
					local have, need, done = piece:match("^(%d+)/(%d+)/([01])$")
					have, need = Integer(tonumber(have)), Integer(tonumber(need))
					if not have or not need or #objectives >= MAX_OBJECTIVES then return end
					objectives[#objectives + 1] = { numFulfilled = have, numRequired = need, finished = done == "1" }
					length = length + #piece + 1
				end
				if body ~= "" and length ~= #body + 1 then return end
				result[id] = { complete = flag == "1", objectives = objectives }
			end
		end
		if used ~= #message then return end
		return result
	end

	local function Snapshot()
		local log, out = C_QuestLog, {}
		if not (Fn(log, "GetNumQuestLogEntries") and Fn(log, "GetInfo") and Fn(log, "GetQuestObjectives") and Fn(log, "IsComplete")) then return end
		local count = Integer(log.GetNumQuestLogEntries())
		if not count or count > 200 then return end
		for i = 1, count do
			local info = log.GetInfo(i)
			local id = not IsSecret(info) and type(info) == "table" and Integer(info.questID)
			if id and id > 0 then
				local record = Party.Encode(id, log.IsComplete(id), log.GetQuestObjectives(id))
				if record then out[id] = record end
			end
		end
		return out
	end

	local Flush
	local function Schedule()
		if pending or not Grouped() then return end
		if not Fn(C_ChatInfo, "SendAddonMessage") or not Fn(C_ChatInfo, "RegisterAddonMessagePrefix") then return end
		if not registered then
			local status = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
			if IsSecret(status) or (status ~= 0 and status ~= 1) then return end
			registered = true
		end
		pending = true
		local token = generation
		C_Timer.After(2, function()
			if token ~= generation then return end
			pending = false
			Flush()
		end)
	end

	local function Changed()
		stale = true
		Schedule()
	end

	function Flush()
		if not Grouped() or not Fn(C_ChatInfo, "SendAddonMessage") then return end
		if stale then
			local current = Snapshot()
			if not current then return end
			queue, stale = {}, false
			for id, record in pairs(current) do
				if record ~= sent[id] then queue[id] = record end
			end
			for id in pairs(sent) do
				if not current[id] then queue[id] = false end
			end
		end
		local packet, updates = "1;", {}
		for id, record in pairs(queue) do
			local piece = record and record .. ";" or id .. ":-;"
			if #packet + #piece <= LIMIT then packet, updates[id] = packet .. piece, record end
		end
		if packet == "1;" then return end
		local status = C_ChatInfo.SendAddonMessage(PREFIX, packet, "PARTY")
		if IsSecret(status) then return end
		if status == 0 then
			for id, record in pairs(updates) do sent[id], queue[id] = record or nil, nil end
		end
		if (status == 0 and next(queue) ~= nil) or status == 3 or status == 8 then Schedule() end
	end

	local function Receive(_, prefix, message, channel, sender)
		if IsSecret(prefix) or prefix ~= PREFIX or IsSecret(channel) or channel ~= "PARTY" or not Grouped() then return end
		sender = Text(sender)
		if not sender then return end
		for i = 1, 4 do
			local full, short = Name("party" .. i)
			local realm = Fn(_G, "GetNormalizedRealmName") and Text(GetNormalizedRealmName()) or ""
			if full and (sender == full or sender == short and full == short .. "-" .. realm) then
				local data = Party.Decode(message)
				if not data then return end
				local cache = peers[full] or {}
				for id, entry in pairs(data) do cache[id] = entry or nil end
				local count = 0
				for _ in pairs(cache) do count = count + 1 end
				if count <= 100 then peers[full] = cache else peers[full] = nil end
				return
			end
		end
	end

	local function Questie(id, full, short)
		local loader = rawget(_G, "QuestieLoader")
		if not Fn(loader, "ImportModule") then return end
		local ok, comms = pcall(loader.ImportModule, loader, "QuestieComms")
		local logs = ok and not IsSecret(comms) and type(comms) == "table" and comms.remoteQuestLogs
		local players = not IsSecret(logs) and type(logs) == "table" and logs[id]
		if IsSecret(players) or type(players) ~= "table" then return end
		local objectives = players[full]
		if IsSecret(objectives) then return end
		if objectives == nil and full == short .. "-" .. (Fn(_G, "GetNormalizedRealmName") and Text(GetNormalizedRealmName()) or "") then objectives = players[short] end
		if IsSecret(objectives) or type(objectives) ~= "table" then return end
		local out, complete = {}, #objectives > 0
		for i = 1, math.min(#objectives, MAX_OBJECTIVES) do
			local o = objectives[i]
			if IsSecret(o) or type(o) ~= "table" then return end
			local have, need = Integer(o.fulfilled), Integer(o.required)
			if not have or not need or IsSecret(o.finished) then return end
			out[i] = { numFulfilled = have, numRequired = need, finished = Yes(o.finished) }
			complete = complete and out[i].finished
		end
		return { complete = complete, objectives = out }
	end

	function Party.Hide(owner)
		if tip and tip:IsOwned(owner or hovered) then tip:Hide() end
		if owner == nil or owner == hovered then hovered = nil end
	end

	function Party.Show(owner, id)
		Party.Hide(owner)
		if not Grouped() or not Integer(id) or not Fn(C_QuestLog, "IsUnitOnQuest") or not Fn(C_QuestLog, "GetQuestObjectives") then return end
		local labels, shown = C_QuestLog.GetQuestObjectives(id), false
		if IsSecret(labels) or type(labels) ~= "table" then labels = {} end
		for i = 0, 4 do
			local unit = i == 0 and "player" or "party" .. i
			local full, short = Name(unit)
			if full and Yes(C_QuestLog.IsUnitOnQuest(unit, id)) then
				if not shown then
					tip = K.Widgets.Tooltip()
					tip:SetOwner(owner, "ANCHOR_LEFT")
					hovered = owner
					local title = Fn(C_QuestLog, "GetTitleForQuestID") and Text(C_QuestLog.GetTitleForQuestID(id))
					if title then tip:AddTitle(title) end
					tip:AddRule()
					tip:AddCaption(K.L["Party"])
					shown = true
				end
				local data = i == 0 and { complete = Fn(C_QuestLog, "IsComplete") and Yes(C_QuestLog.IsComplete(id)), objectives = labels }
					or peers[full] and peers[full][id] or Questie(id, full, short)
				local class
				if Fn(_G, "UnitClass") then class = select(2, UnitClass(unit)) end
				local r, g, b = K.Theme.ClassColor(Text(class))
				tip:AddLine(short, r, g, b)
				if data and data.complete then
					tip:AddLine(K.L["done"], "friend")
				elseif data and #data.objectives > 0 then
					for n, o in ipairs(data.objectives) do
						if IsSecret(o) or type(o) ~= "table" then break end
						local label = labels[n]
						local text = not IsSecret(label) and type(label) == "table" and Text(label.text)
						text = text and Split(text) or string.format(K.L["Objective %d"], n)
						local have, need = Integer(o.numFulfilled), Integer(o.numRequired)
						local count = have and need and need > 0 and have .. "/" .. need
						tip:AddLine(text .. (count and ": " .. count or "") .. (Yes(o.finished) and " (" .. K.L["done"] .. ")" or ""), "text")
					end
				else
					tip:AddLine(K.L["on this quest"], "textDisabled")
				end
			end
		end
		if shown then tip:Show() end
	end

	function Party.Sync(on)
		on = on == true and ns.Skins.Setting("quests", "partyProgress") == true
		if enabled == on then return end
		enabled, pending, generation = on, false, generation + 1
		peers, sent, queue, stale = {}, {}, {}, true
		Party.Hide()
		K.Events.UnregisterAll(OWNER)
		if not on then return end
		K.Events.Register(OWNER, "QUEST_LOG_UPDATE", Changed)
		K.Events.Register(OWNER, "UNIT_QUEST_LOG_CHANGED", Changed)
		K.Events.Register(OWNER, "GROUP_ROSTER_UPDATE", function()
			peers, sent, queue, stale = {}, {}, {}, true
			Party.Hide()
			Schedule()
		end)
		K.Events.Register(OWNER, "CHAT_MSG_ADDON", Receive)
	end
end
