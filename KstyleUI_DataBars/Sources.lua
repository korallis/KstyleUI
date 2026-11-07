-- Sources.lua: experience, reputation and honour read from the game's API, guarded against missing functions and secret values.
local _, ns = ...

local L = ns.L
local IsNumber, IsSecret = ns.IsNumber, ns.IsSecret
local format, select = string.format, select

local Sources = {}
ns.Sources = Sources

local PVP_RANK_FACTION = 2800
local MAX_REACTION = 8
local FRIEND_REACTION = 5
local STANDINGS = {
	L["Hated"], L["Hostile"], L["Unfriendly"], L["Neutral"], L["Friendly"], L["Honored"], L["Revered"], L["Exalted"],
}

Sources.PVP_RANK_FACTION = PVP_RANK_FACTION

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		ns.LogOnce("call:" .. tostring(a), "a game call failed: " .. tostring(a))
		return nil
	end
	return a, b, c, d
end
Sources.Call = Call

local function AnySecret(...)
	for i = 1, select("#", ...) do
		if IsSecret((select(i, ...))) then
			return true
		end
	end
	return false
end

local function Secret(what)
	ns.LogOnce("secret:" .. what, what .. " came back secret; its bar stays hidden")
	return nil, "secret"
end

local function Range(value, low, high, capped)
	local max = high - low
	if max <= 0 then
		return 1, 1, true
	end
	local current = value - low
	if current < 0 then
		current = 0
	elseif current > max then
		current = max
	end
	return current, max, capped == true
end

local function MaxLevel()
	local max = Call(GetMaxLevelForPlayerExpansion)
	if not IsNumber(max) or max <= 0 then
		max = Call(GetMaxPlayerLevel)
	end
	return IsNumber(max) and max > 0 and max or nil
end

local function XPHidden(level)
	if Call(IsXPUserDisabled) == true then
		return "disabled"
	end
	local rules = GameRulesUtil
	if type(rules) == "table" and type(rules.CanShowExperienceBar) == "function" then
		local can = Call(rules.CanShowExperienceBar)
		if can == false then
			return "max level"
		elseif can == true then
			return nil
		end
	end
	local max = MaxLevel()
	if IsNumber(level) and max and level >= max then
		return "max level"
	end
	return nil
end

function Sources.XP()
	if type(UnitXP) ~= "function" or type(UnitXPMax) ~= "function" then
		ns.LogOnce("xp-missing", "UnitXP or UnitXPMax is missing; the experience bar stays hidden")
		return nil, "missing"
	end
	local level = Call(UnitLevel, "player")
	if IsSecret(level) then
		return Secret("the player's level")
	end
	local hidden = XPHidden(level)
	if hidden then
		return nil, hidden
	end
	local current, max, rested = Call(UnitXP, "player"), Call(UnitXPMax, "player"), Call(GetXPExhaustion)
	if AnySecret(current, max, rested) then
		return Secret("experience")
	end
	if not IsNumber(current) or not IsNumber(max) then
		return nil, "missing"
	end
	if max <= 0 then
		return nil, "empty"
	end
	if not IsNumber(rested) or rested < 0 then
		rested = 0
	end
	local _, restName = Call(GetRestState)
	return {
		current = current, max = max, rested = rested,
		level = IsNumber(level) and level or nil,
		label = IsNumber(level) and format(L["Level %d"], level) or L["Experience"],
		restName = type(restName) == "string" and restName ~= "" and restName or nil,
	}
end

local function StandingName(reaction)
	if type(GetText) == "function" and IsNumber(reaction) then
		local text = Call(GetText, "FACTION_STANDING_LABEL" .. reaction, Call(UnitSex, "player"))
		if type(text) == "string" and text ~= "" then
			return text
		end
	end
	return STANDINGS[reaction] or L["Unknown"]
end

local function Paragon(api, id, info)
	if Call(api.IsFactionParagonForCurrentPlayer, id) ~= true then
		return nil
	end
	local value, threshold, _, pending = Call(api.GetFactionParagonInfo, id)
	if AnySecret(value, threshold, pending) then
		return Secret("paragon reputation")
	end
	if not IsNumber(value) or not IsNumber(threshold) or threshold <= 0 then
		return nil
	end
	info.kind, info.standing = "paragon", L["Paragon"]
	info.rewardPending = pending == true
	info.current, info.max = value % threshold, threshold
	if info.rewardPending then
		info.current = threshold
	end
	return info
end

local function Major(api, id, info)
	if Call(api.IsMajorFaction, id) ~= true or type(C_MajorFactions) ~= "table" then
		return nil
	end
	local major = Call(C_MajorFactions.GetMajorFactionData, id)
	if type(major) ~= "table" then
		return nil
	end
	local level, earned, threshold, top = major.renownLevel, major.renownReputationEarned, major.renownLevelThreshold, major.maxLevel
	if AnySecret(level, earned, threshold, top) then
		return Secret("renown")
	end
	if not IsNumber(level) or not IsNumber(earned) or not IsNumber(threshold) then
		return nil
	end
	info.kind, info.level, info.standing = "major", level, format(L["Renown %d"], level)
	info.current, info.max, info.capped = Range(earned, 0, threshold, IsNumber(top) and level >= top)
	return info
end

local function Friend(id, info)
	if type(C_GossipInfo) ~= "table" then
		return nil
	end
	local friend = Call(C_GossipInfo.GetFriendshipReputation, id)
	if type(friend) ~= "table" then
		return nil
	end
	local friendID, standing, low, high = friend.friendshipFactionID, friend.standing, friend.reactionThreshold, friend.nextThreshold
	if AnySecret(friendID, standing, low, high) then
		return Secret("friendship")
	end
	if not IsNumber(friendID) or friendID <= 0 then
		return nil
	end
	info.kind, info.reaction = "friend", FRIEND_REACTION
	info.standing = type(friend.reaction) == "string" and friend.reaction ~= "" and friend.reaction or STANDINGS[FRIEND_REACTION]
	if IsNumber(standing) and IsNumber(low) and IsNumber(high) then
		info.current, info.max, info.capped = Range(standing, low, high, false)
	else
		info.current, info.max, info.capped = 1, 1, true
	end
	return info
end

function Sources.Reputation()
	local api = C_Reputation
	if type(api) ~= "table" or type(api.GetWatchedFactionData) ~= "function" then
		ns.LogOnce("rep-missing", "C_Reputation.GetWatchedFactionData is missing; the reputation bar stays hidden")
		return nil, "missing"
	end
	local data = Call(api.GetWatchedFactionData)
	if type(data) ~= "table" then
		return nil, "none"
	end
	local id, reaction = data.factionID, data.reaction
	local standing, low, high = data.currentStanding, data.currentReactionThreshold, data.nextReactionThreshold
	if AnySecret(id, reaction, standing, low, high, data.name) then
		return Secret("reputation")
	end
	if not IsNumber(id) or id == 0 then
		return nil, "none"
	end
	local name = type(data.name) == "string" and data.name or L["Reputation"]
	local info = { kind = "faction", name = name, label = name, reaction = IsNumber(reaction) and reaction or nil, capped = false }
	local special, why = Paragon(api, id, info)
	if special or why then
		return special, why
	end
	special, why = Major(api, id, info)
	if special or why then
		return special, why
	end
	special, why = Friend(id, info)
	if special or why then
		return special, why
	end
	if not IsNumber(standing) or not IsNumber(low) or not IsNumber(high) then
		return nil, "missing"
	end
	local top = IsNumber(MAX_REPUTATION_REACTION) and MAX_REPUTATION_REACTION or MAX_REACTION
	info.standing = StandingName(info.reaction)
	info.current, info.max, info.capped = Range(standing, low, high, info.reaction ~= nil and info.reaction >= top)
	return info
end

local function Rank()
	local api = C_MajorFactions
	if type(api) ~= "table" then
		return nil
	end
	local rank = Call(api.GetMajorFactionProgressionInfo, PVP_RANK_FACTION)
	if type(rank) ~= "table" then
		return nil
	end
	local level, earned, threshold, top = rank.renownLevel, rank.renownReputationEarned, rank.renownLevelThreshold, rank.maxLevel
	if AnySecret(level, earned, threshold, top) then
		return Secret("PvP rank")
	end
	if not IsNumber(level) or not IsNumber(earned) or not IsNumber(threshold) then
		return nil
	end
	local info = { kind = "rank", level = level }
	info.label = level > 0 and format(L["Rank %d"], level) or L["Unranked"]
	info.current, info.max, info.capped = Range(earned, 0, threshold, IsNumber(top) and level >= top)
	return info
end

local function Honor()
	if type(UnitHonor) ~= "function" or type(UnitHonorMax) ~= "function" then
		return nil
	end
	local current, max, level = Call(UnitHonor, "player"), Call(UnitHonorMax, "player"), Call(UnitHonorLevel, "player")
	if AnySecret(current, max, level) then
		return Secret("honour")
	end
	if not IsNumber(current) or not IsNumber(max) or max <= 0 then
		return nil
	end
	local info = { kind = "honor", level = IsNumber(level) and level or nil }
	info.label = info.level and format(L["Honor level %d"], info.level) or L["Honor"]
	info.current, info.max, info.capped = Range(current, 0, max, false)
	return info
end

function Sources.Honor()
	local info, why = Rank()
	if info or why then
		return info, why
	end
	info, why = Honor()
	if info or why then
		return info, why
	end
	return nil, "empty"
end

function Sources.InPvP()
	if type(C_PvP) == "table" and Call(C_PvP.IsActiveBattlefield) == true then
		return true
	end
	return Call(IsInActiveWorldPVP) == true
end
