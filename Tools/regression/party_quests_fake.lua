-- party_quests_fake.lua: party identities, native membership and addon transport shared by quest-hover tests and renders.
local Fake = {}

function Fake.Install(env, log)
	local p = { count = 5, raid = false, sent = {}, prefixes = {}, time = 0, timers = {}, status = 0, remote = {} }
	p.members = {
		player = { name = "Korallis", class = "WARLOCK", quests = { [301] = true } },
		party1 = { name = "Lycia", class = "MAGE", quests = { [301] = true } },
		party2 = { name = "Rumpy", class = "WARRIOR", quests = { [301] = true } },
		party3 = { name = "Talia", class = "PRIEST", quests = { [301] = true } },
		party4 = { name = "Nessa", class = "HUNTER", quests = {} },
	}
	local after, unitClass = env.C_Timer.After, env.UnitClass
	env.C_Timer.After = function(delay, fn)
		if delay == 2 then p.timers[#p.timers + 1] = { at = p.time + delay, fn = fn } else after(delay, fn) end
	end
	env.GetNumGroupMembers = function() return p.count end
	env.IsInRaid = function() return p.raid end
	env.UnitFullName = function(unit)
		local member = p.members[unit]
		if member then return member.name, member.realm or "Shadowmoon" end
	end
	env.GetNormalizedRealmName = function() return "Shadowmoon" end
	local colors = {
		WARLOCK = { r = 0.58, g = 0.51, b = 0.79 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 },
		WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, PRIEST = { r = 1, g = 1, b = 1 }, HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
	}
	env.C_ClassColor = { GetClassColor = function(class) return colors[class] end }
	env.UnitClass = function(unit)
		local member = p.members[unit]
		if member then return member.class, member.class end
		return unitClass(unit)
	end
	env.C_QuestLog.IsUnitOnQuest = function(unit, id)
		local member = p.members[unit]
		return member and member.quests[id] or false
	end
	env.C_QuestLog.GetNumQuestLogEntries = function() return #log.quests end
	env.C_QuestLog.GetInfo = function(i) return log.quests[i] and { questID = log.quests[i].id } end
	env.C_ChatInfo = {
		RegisterAddonMessagePrefix = function(prefix) p.prefixes[#p.prefixes + 1] = prefix; return 0 end,
		SendAddonMessage = function(prefix, message, channel)
			p.sent[#p.sent + 1] = { prefix = prefix, message = message, channel = channel, time = p.time }
			return p.status
		end,
	}
	function p.Advance(seconds)
		p.time = p.time + seconds
		local timers = p.timers
		p.timers = {}
		for _, timer in ipairs(timers) do
			if timer.at <= p.time then timer.fn() else p.timers[#p.timers + 1] = timer end
		end
		env.RunTimers()
	end
	function p.Receive(sender, message, channel)
		env.FireEvent("CHAT_MSG_ADDON", "KstyleQuest1", message, channel or "PARTY", sender)
	end
	function p.Questie()
		env.QuestieLoader = { ImportModule = function(_, name)
			if name == "QuestieComms" then return { remoteQuestLogs = p.remote } end
		end }
	end
	function p.Hover(ns, before)
		if before then env.KstyleUI.Options.Write("Skins", "quests.partyProgress", false) end
		log.Fire("QUEST_LOG_UPDATE")
		p.Receive("Lycia-Shadowmoon", "1;301:0:5/8/0,2/3/0;")
		p.Questie()
		p.remote[301] = { Rumpy = { { fulfilled = 8, required = 8, finished = true }, { fulfilled = 3, required = 3, finished = true } } }
		local row = ns.Quests.Rows()[1]
		row:GetScript("OnEnter")(row)
	end
	return p
end

return Fake
