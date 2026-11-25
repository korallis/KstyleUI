-- Quests.lua: accepts quests and turns in finished ones while the pause key is up, and leaves PvP quests, reward choices and costly turn-ins to the player, as Blizzard's quest frame buttons would.
local _, ns = ...

local function Active(gossip)
	if not ns.Get(gossip and "autoGossip" or "autoQuests") then
		return false
	end
	if not ns.Get("questInstances") then
		if type(IsInInstance) ~= "function" then return false end
		local inside = IsInInstance()
		if ns.IsSecret(inside) or inside ~= false then return false end
	end
	local held = _G[ns.PAUSE_KEYS[ns.Get("questModifier")]]
	return ns.Ask(held) == false
end

local function OnDetail(_, startItemID)
	if not Active() then
		return
	end
	local item = ns.Number(startItemID)
	if ns.IsSecret(startItemID) or (item and item ~= 0) then
		return
	end
	if ns.Ask(QuestIsFromAdventureMap) ~= false or ns.Ask(QuestFlagsPVP) ~= false then
		return
	end
	local auto = ns.Ask(QuestGetAutoAccept)
	if auto == true then
		if ns.Ask(QuestIsFromAreaTrigger) == false then
			AcknowledgeAutoAcceptQuest()
		end
	elseif auto == false then
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
	local money = ns.Number(GetQuestMoneyToGet())
	if not money or money > 0 then
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
		if not ns.IsSecret(trivial) and (trivial ~= true or not ns.Get("ignoreTrivial")) then
			SelectAvailableQuest(i)
			return
		end
	end
end

local function List(fn)
	local list = ns.Ask(fn)
	return type(list) == "table" and list or nil
end

local function OnGossip()
	local gossip = C_GossipInfo
	if not gossip then return end
	local quests, solo = Active(), Active(true) and ns.Ask(InCombatLockdown) == false
	if not (quests or solo) then return end
	local active, available = List(gossip.GetActiveQuests), List(gossip.GetAvailableQuests)
	if not active or not available then return end
	if solo and type(gossip.GetOptions) == "function" and type(gossip.SelectOption) == "function" and #active == 0 and #available == 0 then
		local options = List(gossip.GetOptions)
		if options and #options == 1 then
			local info = options[1]
			local id = not ns.IsSecret(info) and type(info) == "table" and ns.Number(info.gossipOptionID)
			if id then gossip.SelectOption(id); return end
		end
	end
	if not quests then return end
	for _, info in ipairs(active) do
		local id = not ns.IsSecret(info) and type(info) == "table" and ns.Number(info.questID)
		if id and ns.True(info.isComplete) then
			gossip.SelectActiveQuest(id)
			return
		end
	end
	for _, info in ipairs(available) do
		local id = not ns.IsSecret(info) and type(info) == "table" and ns.Number(info.questID)
		if id and not ns.IsSecret(info.isTrivial) and (info.isTrivial ~= true or not ns.Get("ignoreTrivial")) and not ns.IsSecret(info.isIgnored) and not info.isIgnored then
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
