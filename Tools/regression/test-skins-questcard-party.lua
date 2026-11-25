-- test-skins-questcard-party.lua: versioned party counters, burst throttling, guarded identities, current membership and the shared quest hover tooltip.
local S = dofile("Tools/regression/skins_env.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Party = dofile("Tools/regression/party_quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function Boot(screen, quests)
	local log, party
	local env, K, ns = S.New({
		width = screen and screen[1], height = screen and screen[2],
		setup = function(e)
			log = Quests.Install(e, Quests.List(quests or 3))
			log.quests[1].title = "Bloodscalp Headhunters"
			log.quests[1].objectives = { { text = "Bloodscalp Headhunters: 1/8" }, { text = "Canvas Scraps: 0/3" } }
			party = Party.Install(e, log)
		end,
		before = function(e) Quests.Tracker(e, S.Blizzard(e)) end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	S.W.Settle(env)
	assert(#party.sent == 0 and #party.prefixes == 0, "party progress must register its prefix lazily and send nothing at load")
	return env, K, ns, log, party
end

local function Lines(tip)
	local out = {}
	for _, line in ipairs(tip.used) do out[#out + 1] = line.left:GetText() or "" end
	return table.concat(out, "\n")
end

do
	local _, _, ns = Boot()
	local encode, decode = ns.QuestParty.Encode, ns.QuestParty.Decode
	local objectives = { { numFulfilled = 5, numRequired = 8, finished = false }, { numFulfilled = 3, numRequired = 3, finished = true } }
	local record = assert(encode(301, false, objectives))
	local data = assert(decode("1;" .. record .. ";302:-;"))
	assert(data[301].objectives[1].numFulfilled == 5 and data[301].objectives[2].finished and data[302] == false)
	assert(encode(301, data[301].complete, data[301].objectives) == record, "message objective counts and done flags round-trip")
	assert(decode("1;301:1:;")[301].complete, "completed quests without objectives round-trip")
	for _, bad in ipairs({ "", "2;301:0:;", "1;301:0:1/8/0", "1;301:0:,,;", "1;301:0:1/8/2;", "1;301:0:1/8/0,;", "1;301:0:;301:-;", "1;0:0:;", "1;301:9:;", "1;" .. string.rep("a", 240) }) do
		assert(decode(bad) == nil, "reject malformed or incompatible packet: " .. bad)
	end
end

do
	local env, K, ns, log, p = Boot()
	for _ = 1, 20 do log.Fire("QUEST_LOG_UPDATE"); log.Fire("UNIT_QUEST_LOG_CHANGED", "player") end
	assert(#p.prefixes == 1, "listen before the two-second send window so peers joining together receive each other's first snapshot")
	p.Advance(1.99)
	assert(#p.sent == 0)
	p.Advance(0.01)
	assert(#p.sent == 1 and #p.prefixes == 1 and p.sent[1].channel == "PARTY", "coalesce a change burst into one PARTY message after two seconds")
	assert(ns.QuestParty.Decode(p.sent[1].message)[301].objectives[1].numFulfilled == 1)
	p.Advance(2)
	assert(#p.sent == 1, "unchanged quests send nothing")
	log.quests[1].objectives[1].text = "Bloodscalp Headhunters: 5/8"
	log.Fire("QUEST_LOG_UPDATE")
	p.Advance(2)
	assert(#p.sent == 2)
	assert(ns.QuestParty.Decode(p.sent[2].message)[302] == nil, "send only changed quests")
	log.quests[3] = nil
	log.Fire("QUEST_LOG_UPDATE")
	p.Advance(2)
	assert(ns.QuestParty.Decode(p.sent[3].message)[303] == false, "abandoned quests remove remote state")
	p.status = 3
	log.quests[1].complete = true
	log.Fire("QUEST_LOG_UPDATE")
	p.Advance(2)
	local n = #p.sent
	p.Advance(1)
	assert(#p.sent == n, "server throttle retries wait two seconds")
	p.status = 0
	p.Advance(1)
	assert(#p.sent == n + 1)
	K.Options.Write("Skins", "quests.partyProgress", false)
	log.Fire("QUEST_LOG_UPDATE")
	p.Advance(10)
	assert(#p.sent == n + 1, "off cancels queued sends and ignores quest events")
	assert(K.ErrorCount() == 0 and #env._errors == 0)
end

-- The idle-work audit's finding 74: one quest change in a 35-quest log took three packets and read and encoded the
-- whole log before each packet and once more after the last, 140 encodes. Each change now reads the log once and
-- drains its differences across the packets.
do
	local env, K, ns, log, p = Boot(nil, 35)
	local encodes = 0
	local encode = ns.QuestParty.Encode
	ns.QuestParty.Encode = function(...)
		encodes = encodes + 1
		return encode(...)
	end
	local function Packet(i)
		local data, count = assert(ns.QuestParty.Decode(p.sent[i].message)), 0
		for _ in pairs(data) do count = count + 1 end
		return data, count
	end
	log.Fire("QUEST_LOG_UPDATE")
	for _ = 1, 6 do p.Advance(2) end
	assert(#p.sent > 1, "35 quests take more than one packet")
	assert(encodes == 35, "one change encodes each of the 35 quests once across every packet, got " .. encodes)
	local seen = {}
	for i = 1, #p.sent do
		for id in pairs(Packet(i)) do seen[id] = true end
	end
	for _, quest in ipairs(log.quests) do assert(seen[quest.id], "quest " .. quest.id .. " reaches a packet") end
	local sent = #p.sent
	encodes = 0
	log.quests[2].objectives[1].text = log.quests[2].objectives[1].text:gsub(": %d+/", ": 3/")
	log.Fire("QUEST_LOG_UPDATE")
	for _ = 1, 3 do p.Advance(2) end
	local data, count = Packet(sent + 1)
	assert(#p.sent == sent + 1 and encodes == 35, "a new change reads the log again and sends one packet, got " .. encodes .. " encodes")
	assert(count == 1 and data[302].objectives[1].numFulfilled == 3, "and that packet holds only the changed quest")
	encodes = 0
	p.status = 3
	log.quests[3].complete = true
	log.Fire("QUEST_LOG_UPDATE")
	p.Advance(2)
	p.Advance(2)
	p.status = 0
	p.Advance(2)
	data, count = Packet(#p.sent)
	assert(#p.sent == sent + 4 and count == 1 and data[303].complete, "throttled sends retry the queued change until one goes through")
	assert(encodes == 35, "the retries send the queued change without reading the log again, got " .. encodes)
	encodes = 0
	K.Options.Write("Skins", "quests.partyProgress", false)
	log.Fire("QUEST_LOG_UPDATE")
	for _ = 1, 3 do p.Advance(2) end
	assert(encodes == 0 and #p.sent == sent + 4, "off reads and sends nothing")
	assert(K.ErrorCount() == 0 and #env._errors == 0)
end

for _, mode in ipairs({ "solo", "raid", "large", "secret" }) do
	local env, K, ns, log, p = Boot()
	if mode == "solo" then p.count = 0 elseif mode == "raid" then p.raid = true elseif mode == "large" then p.count = 6 else p.count = env.Secret(5) end
	log.Fire("GROUP_ROSTER_UPDATE")
	log.Fire("QUEST_LOG_UPDATE")
	p.Advance(10)
	assert(#p.sent == 0 and #p.prefixes == 0, mode .. " must not register or send party messages")
	S.W.Enter(ns.Quests.Rows()[1])
	assert(not K.Widgets.Tooltip():IsShown(), mode .. " shows no party tooltip")
end

for _, screen in ipairs({ {1920, 1080}, {2560, 1440}, {5120, 1440}, {3840, 2160} }) do
	local env, K, ns, _, p = Boot(screen)
	p.Hover(ns)
	S.W.Settle(env)
	local tip = K.Widgets.Tooltip()
	local text = Lines(tip)
	assert(tip:IsShown() and tip:IsOwned(ns.Quests.Rows()[1]))
	assert(text:find("Lycia\nBloodscalp Headhunters: 5/8\nCanvas Scraps: 2/3", 1, true), "native membership and KstyleUI counters show each objective")
	assert(text:find("Rumpy\ndone", 1, true), "read Questie's live runtime counters without writing them")
	assert(text:find("Talia\non this quest", 1, true), "members without either addon still show native membership")
	assert(not text:find("Nessa", 1, true), "members not on this quest have no row")
	for _, line in ipairs(tip.used) do
		if line.left:GetText() == "Lycia" then
			local r, g, b = line.left:GetTextColor()
			local cr, cg, cb = K.Theme.ClassColor("MAGE")
			assert(S.W.Near(r, cr) and S.W.Near(g, cg) and S.W.Near(b, cb), "party names use each member's class colour")
		end
	end
	local rect = Geometry.Rect(tip, K.Scale.Root())
	assert(rect and rect.right > rect.left and rect.top > rect.bottom, "the actual tooltip lays out at every required screen")
	assert(Geometry.Outside(rect, Geometry.Rect(K.Scale.Root(), K.Scale.Root())) < 1, "quest hover stays inside each required screen")
	p.Receive("Stranger-Shadowmoon", "1;301:1:;")
	p.Receive("Lycia-Shadowmoon", "1;301:1:;", "RAID")
	S.W.Enter(ns.Quests.Rows()[1])
	assert(Lines(tip):find("5/8", 1, true), "ignore other senders and channels")
	p.members.party1.quests[301] = false
	S.W.Enter(ns.Quests.Rows()[1])
	assert(not Lines(tip):find("Lycia", 1, true), "native membership wins over cached progress")
	p.members.party1.quests[301] = env.Secret(true)
	p.members.party3.name = env.Secret("Talia")
	S.W.Enter(ns.Quests.Rows()[1])
	assert(not Lines(tip):find("Lycia", 1, true) and not Lines(tip):find("Talia", 1, true), "secret membership and names are never compared")
	K.Options.Write("Skins", "quests.partyProgress", false)
	S.W.Enter(ns.Quests.Rows()[1])
	S.W.Settle(env)
	assert(not tip:IsShown(), "off hides the open tooltip and subsequent hovers show nothing")
	assert(K.ErrorCount() == 0 and #env._errors == 0, "party hover must not raise")
end

do
	local env, K, ns, _, p = Boot()
	local original = env.C_QuestLog.GetQuestObjectives
	env.C_QuestLog.GetQuestObjectives = function(id)
		local objectives = original(id)
		objectives[1].numFulfilled = env.Secret(5)
		return objectives
	end
	assert(ns.QuestParty.Encode(301, false, env.C_QuestLog.GetQuestObjectives(301)) == nil, "withheld counts never enter messages")
	assert(ns.QuestParty.Decode(env.Secret("1;301:0:;")) == nil, "never inspect a secret payload")
	p.Questie()
	p.remote[301] = { Rumpy = { { fulfilled = env.Secret(8), required = 8, finished = true } } }
	S.W.Enter(ns.Quests.Rows()[1])
	local tip = K.Widgets.Tooltip()
	assert(Lines(tip):find("Rumpy\non this quest", 1, true), "malformed or withheld Questie data falls back to native membership")
	p.members.party1.realm = "OtherRealm"
	p.Receive("Lycia", "1;301:1:;")
	S.W.Enter(ns.Quests.Rows()[1])
	assert(Lines(tip):find("Lycia\non this quest", 1, true), "short senders cannot impersonate a cross-realm member")
	p.Receive("Lycia-OtherRealm", "1;301:1:;")
	S.W.Enter(ns.Quests.Rows()[1])
	assert(Lines(tip):find("Lycia\ndone", 1, true), "full cross-realm identities match their own progress")
	local control = env.CreateFrame("Frame", nil, K.Scale.Root())
	tip:SetOwner(control, "ANCHOR_RIGHT")
	tip:AddLine("Another control")
	tip:Show()
	K.Options.Write("Skins", "quests.partyProgress", false)
	S.W.Settle(env)
	assert(tip:IsShown() and tip:IsOwned(control), "turning party progress off preserves another control's shared tooltip")
	assert(K.ErrorCount() == 0 and #env._errors == 0)
end

do
	local env, K, ns, log, p = Boot()
	log.quests = Quests.List(25, 6)
	log.Fire("GROUP_ROSTER_UPDATE")
	for _ = 1, 30 do p.Advance(2) end
	assert(#p.sent > 1, "large logs are split into bounded messages")
	local seen = {}
	for i, packet in ipairs(p.sent) do
		assert(#packet.message <= 240 and (i == 1 or packet.time - p.sent[i - 1].time >= 2))
		for id in pairs(assert(ns.QuestParty.Decode(packet.message))) do seen[id] = true end
	end
	for _, quest in ipairs(log.quests) do assert(seen[quest.id], "send unwatched as well as watched quests") end
	p.Hover(ns)
	log.Fire("GROUP_ROSTER_UPDATE")
	S.W.Settle(env)
	assert(not K.Widgets.Tooltip():IsShown(), "roster changes hide stale hover content")
	assert(K.ErrorCount() == 0 and #env._errors == 0)
end

do
	local log
	local env, K, ns = S.New({ setup = function(e)
		log = Quests.Install(e, Quests.List(3))
		Party.Install(e, log)
		local full = e.UnitFullName
		e.UnitFullName = function(unit) local n, r = full(unit); if unit ~= "player" then r = nil end; return n, r end
	end, before = function(e) Quests.Tracker(e, S.Blizzard(e)) end })
	K.Modules.Enable("Skins"); S.LoadAddOn(env, "Blizzard_ObjectiveTracker"); env.RunTimers(); S.W.Settle(env)
	local row = ns.Quests.Rows()[1]
	row:GetScript("OnEnter")(row)
	local text = {}
	for _, line in ipairs(K.Widgets.Tooltip().used) do text[#text + 1] = line.left:GetText() or "" end
	text = table.concat(text, "|")
	assert(text:find("Lycia", 1, true), "a same-realm party member (UnitFullName realm nil) still shows: treat a nil realm like an empty one")
end

print("quest card party progress ok: codec, throttle, membership, Questie, secrets, off, solo and four screens")
