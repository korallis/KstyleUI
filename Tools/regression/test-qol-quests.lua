-- test-qol-quests.lua: quest automation accepts and turns in quests when asked, pauses while its key is held, and leaves reward choices, PvP quests and costly turn-ins to the player.
local Q = dofile("Tools/regression/qol_env.lua")

local function Count(env, name)
	return #Q.Calls(env, name)
end

local function Fire(env, event, ...)
	env.FireEvent(event, ...)
	env.RunTimers()
end

local function New(on)
	local env, K = Q.New()
	Q.Enable(env, K)
	if on ~= false then
		Q.Write(env, K, "autoQuests", true)
	end
	return env, K
end

-- Off by default.
do
	local env = New(false)
	Fire(env, "QUEST_DETAIL", 0)
	env._quest.completable = true
	Fire(env, "QUEST_PROGRESS")
	Fire(env, "QUEST_COMPLETE")
	assert(Count(env, "AcceptQuest") + Count(env, "CompleteQuest") + Count(env, "GetQuestReward") == 0, "nothing happens until the player asks")
end

-- Accept.
do
	local env = New()
	Fire(env, "QUEST_DETAIL", 0)
	assert(Count(env, "AcceptQuest") == 1, "a quest offer is accepted")
	env._quest.autoAccept = true
	Fire(env, "QUEST_DETAIL", 0)
	assert(Count(env, "AcknowledgeAutoAcceptQuest") == 1 and Count(env, "AcceptQuest") == 1, "an auto-accept quest is acknowledged, as Blizzard's button does")
end

do
	local env = New()
	env._quest.pvp = true
	Fire(env, "QUEST_DETAIL", 0)
	assert(Count(env, "AcceptQuest") == 0, "a PvP quest waits for the player's confirmation")
	env._quest.pvp = false
	Fire(env, "QUEST_DETAIL", 12345)
	assert(Count(env, "AcceptQuest") == 0, "a quest started from an item is Blizzard's pop-up")
	env._quest.fromMap = true
	Fire(env, "QUEST_DETAIL", 0)
	assert(Count(env, "AcceptQuest") == 0, "an adventure map quest is left alone")
	env._quest.fromMap, env._quest.autoAccept, env._quest.areaTrigger = false, true, true
	Fire(env, "QUEST_DETAIL", 0)
	assert(Count(env, "AcceptQuest") + Count(env, "AcknowledgeAutoAcceptQuest") == 0, "an area-trigger quest is Blizzard's tracker pop-up")
end

-- Turn in.
do
	local env = New()
	Fire(env, "QUEST_PROGRESS")
	assert(Count(env, "CompleteQuest") == 0, "an unfinished quest is not handed in")
	env._quest.completable = true
	Fire(env, "QUEST_PROGRESS")
	assert(Count(env, "CompleteQuest") == 1, "a finished quest is handed in")
end

do
	local env = New()
	Fire(env, "QUEST_COMPLETE")
	local calls = Q.Calls(env, "GetQuestReward")
	assert(#calls == 1 and calls[1][1] == 0, "no reward choice takes the reward")
	env._quest.choices = 1
	Fire(env, "QUEST_COMPLETE")
	calls = Q.Calls(env, "GetQuestReward")
	assert(#calls == 2 and calls[2][1] == 1, "a single reward is taken, as Blizzard's button does")
	env._quest.choices = 3
	Fire(env, "QUEST_COMPLETE")
	assert(Count(env, "GetQuestReward") == 2, "a choice of rewards is the player's")
	env._quest.choices, env._quest.money = 0, 500
	Fire(env, "QUEST_COMPLETE")
	assert(Count(env, "GetQuestReward") == 2, "a turn-in that costs money waits for the player")
end

-- The pause key, Shift by default, then Ctrl or Alt from the setting.
do
	local env, K = New()
	env._modifiers.shift = true
	Fire(env, "QUEST_DETAIL", 0)
	env._quest.completable = true
	Fire(env, "QUEST_PROGRESS")
	Fire(env, "QUEST_COMPLETE")
	assert(Count(env, "AcceptQuest") + Count(env, "CompleteQuest") + Count(env, "GetQuestReward") == 0, "Shift held pauses everything")
	Q.Write(env, K, "questModifier", "ALT")
	Fire(env, "QUEST_DETAIL", 0)
	assert(Count(env, "AcceptQuest") == 1, "with Alt as the key, Shift no longer pauses")
	env._modifiers.shift, env._modifiers.alt = false, true
	Fire(env, "QUEST_DETAIL", 0)
	assert(Count(env, "AcceptQuest") == 1, "Alt held pauses")
	Q.Write(env, K, "questModifier", "CTRL")
	env._modifiers.alt, env._modifiers.ctrl = false, true
	Fire(env, "QUEST_DETAIL", 0)
	assert(Count(env, "AcceptQuest") == 1, "Ctrl held pauses")
end

-- The quest greeting: finished quests first, then a new one that is not grey.
do
	local env = New()
	env._quest.active = { { title = "Open", complete = false }, { title = "Done", complete = true } }
	env._quest.available = { { trivial = false } }
	Fire(env, "QUEST_GREETING")
	local calls = Q.Calls(env, "SelectActiveQuest")
	assert(#calls == 1 and calls[1][1] == 2 and Count(env, "SelectAvailableQuest") == 0, "a finished quest is picked first")
	env._quest.active = { { title = "Open", complete = false } }
	env._quest.available = { { trivial = true }, { trivial = false } }
	Fire(env, "QUEST_GREETING")
	calls = Q.Calls(env, "SelectAvailableQuest")
	assert(#calls == 1 and calls[1][1] == 2, "a grey quest is skipped and the next one is picked")
	env._quest.available = { { trivial = true } }
	Fire(env, "QUEST_GREETING")
	assert(Count(env, "SelectAvailableQuest") == 1 and Count(env, "SelectActiveQuest") == 1, "nothing left to pick, nothing picked")
end

-- Gossip: the same order, by quest ID.
do
	local env = New()
	env._quest.gossipActive = { { questID = 11, isComplete = false }, { questID = 12, isComplete = true } }
	env._quest.gossipAvailable = { { questID = 21, isTrivial = false } }
	Fire(env, "GOSSIP_SHOW")
	local calls = Q.Calls(env, "C_GossipInfo.SelectActiveQuest")
	assert(#calls == 1 and calls[1][1] == 12, "a finished quest is picked first")
	env._quest.gossipActive = {}
	env._quest.gossipAvailable = { { questID = 21, isTrivial = true }, { questID = 22, isTrivial = false, isIgnored = true }, { questID = 23, isTrivial = false } }
	Fire(env, "GOSSIP_SHOW")
	calls = Q.Calls(env, "C_GossipInfo.SelectAvailableQuest")
	assert(#calls == 1 and calls[1][1] == 23, "grey and ignored quests are skipped")
	env._modifiers.shift = true
	env._quest.gossipAvailable = { { questID = 31, isTrivial = false } }
	Fire(env, "GOSSIP_SHOW")
	assert(Count(env, "C_GossipInfo.SelectAvailableQuest") == 1, "the pause key keeps the gossip window open")
end

print("qol quests ok")
