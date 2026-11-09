-- Quests.lua: accepts quests and turns in finished ones while the pause key is up, and leaves PvP quests, reward choices and costly turn-ins to the player, as Blizzard's quest frame buttons would.
local _, ns = ...

local function Active()
	if not ns.Get("autoQuests") then
		return false
	end
	local held = _G[ns.PAUSE_KEYS[ns.Get("questModifier")]]
	return not (type(held) == "function" and ns.True(held()))
end

local function OnDetail(_, startItemID)
	if not Active() then
		return
	end
	local item = ns.Number(startItemID)
	if ns.IsSecret(startItemID) or (item and item ~= 0) then
		return
	end
	if ns.True(QuestIsFromAdventureMap()) or ns.True(QuestFlagsPVP()) then
		return
	end
	if ns.True(QuestGetAutoAccept()) then
		if not ns.True(QuestIsFromAreaTrigger()) then
			AcknowledgeAutoAcceptQuest()
		end
	else
		AcceptQuest()
	end
end

local function OnProgress()
	if Active() and ns.True(IsQuestCompletable()) then
		CompleteQuest()
	end
end

local function OnComplete()
	if not Active() then
		return
	end
	local choices = ns.Number(GetNumQuestChoices())
	if not choices or choices > 1 then
		return
	end
	local money = GetQuestMoneyToGet()
	if ns.IsSecret(money) or (type(money) == "number" and money > 0) then
		return
	end
	GetQuestReward(choices)
end

local function OnGreeting()
	if not Active() then
		return
	end
	for i = 1, ns.Number(GetNumActiveQuests()) or 0 do
		local _, complete = GetActiveTitle(i)
		if ns.True(complete) then
			SelectActiveQuest(i)
			return
		end
	end
	for i = 1, ns.Number(GetNumAvailableQuests()) or 0 do
		local trivial = GetAvailableQuestInfo(i)
		if not ns.IsSecret(trivial) and trivial ~= true then
			SelectAvailableQuest(i)
			return
		end
	end
end

local function List(fn)
	local list = type(fn) == "function" and fn()
	return type(list) == "table" and list or {}
end

local function OnGossip()
	local gossip = C_GossipInfo
	if not gossip or not Active() then
		return
	end
	for _, info in ipairs(List(gossip.GetActiveQuests)) do
		local id = type(info) == "table" and ns.Number(info.questID)
		if id and ns.True(info.isComplete) then
			gossip.SelectActiveQuest(id)
			return
		end
	end
	for _, info in ipairs(List(gossip.GetAvailableQuests)) do
		local id = type(info) == "table" and ns.Number(info.questID)
		if id and not ns.IsSecret(info.isTrivial) and info.isTrivial ~= true and not ns.True(info.isIgnored) then
			gossip.SelectAvailableQuest(id)
			return
		end
	end
end

ns.AddPart({
	name = "quests",
	events = {
		QUEST_DETAIL = OnDetail,
		QUEST_PROGRESS = OnProgress,
		QUEST_COMPLETE = OnComplete,
		QUEST_GREETING = OnGreeting,
		GOSSIP_SHOW = OnGossip,
	},
})
