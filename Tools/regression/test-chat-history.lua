-- test-chat-history.lua: the chat keeps each window's last lines across a reload or a relog in KstyleUI's own saved data, bounded per window, never a secret, a Battle.net name or the combat log, and only while the setting is on.
local C = dofile("Tools/regression/chat_env.lua")

local function Saved(chat)
	local section = { enabled = true }
	for k, v in pairs(chat or {}) do
		section[k] = v
	end
	return { version = 2, profiles = { Default = { Chat = section } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function Plain(text)
	return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""))
end

local function Find(lines, needle)
	for i, line in ipairs(lines) do
		if Plain(line):find(needle, 1, true) then
			return i
		end
	end
	return nil
end

local function Session(saved, play)
	local env, K, ns = C.New({ saved = saved })
	C.Enable(env, K)
	if play then
		play(env, K, ns)
	end
	C.W.CoreEnv.Logout(env)
	return env, K, ns, env.KstyleUIDB
end

-- Session one: guild and party talk in the general window, a trade line in the third, a combat log line, a secret
-- line and a Battle.net name, as the game hands them to AddMessage.
local first, K1, _, saved = Session(Saved(), function(env)
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "Raid at 8 tonight.", { sender = "Thargor", guid = "Player-1-0002", color = { 0.25, 1, 0.25 } })
	C.Say(env, env.ChatFrame1, "CHAT_MSG_PARTY", "ready when you are", { sender = "Leduc", guid = "Player-1-0003" })
	env.ChatFrame1:AddMessage("You receive loot: |cff1eff00|Hitem:4232::::::::38:::::|h[Crocolisk Hide]|h|r x2.", 0, 0.67, 0)
	env.ChatFrame1:AddMessage(env.Secret("a secret line"), 1, 1, 1)
	env.ChatFrame1:AddMessage("|Kq12|k: whispers: hi", 0, 1, 0.96)
	C.Say(env, env.ChatFrame3, "CHAT_MSG_CHANNEL", "WTS Rugged Hide", { sender = "Riverglades", channel = "2. Trade - City" })
	env._combatLog = true
	env.ChatFrame2:AddMessage("Your Mortal Strike hits Crocolisk for 312.", 1, 1, 1)
end)
assert(#first._errors == 0, "no Lua error: " .. tostring(first._errors[1]))

-- What is saved is plain data in KstyleUI's own saved variables, under this character: no secret, no |K name.
local store = saved.account and saved.account.chatHistory
assert(type(store) == "table" and type(store.characters) == "table", "the history lives in KstyleUIDB.account.chatHistory")
local key = K1.Store.CharacterKey()
local mine = store.characters[key]
assert(type(mine) == "table" and type(mine.ChatFrame1) == "table", "this character's general window is kept")
for name, lines in pairs(mine) do
	for _, line in ipairs(lines) do
		assert(type(line[1]) == "string" and type(line[2]) == "number" and type(line[3]) == "number" and type(line[4]) == "number", name .. " keeps text and colour only")
		assert(not first.issecretvalue(line[1]), "no secret is saved")
		assert(not line[1]:find("|K", 1, true), "a Battle.net name is never saved")
	end
end
assert(#mine.ChatFrame1 == 3, "the guild, party and loot lines are kept: " .. #mine.ChatFrame1)
assert(mine.ChatFrame2 == nil, "the combat log is never kept")
assert(type(mine.ChatFrame3) == "table" and #mine.ChatFrame3 == 1, "the trade window keeps its own line")

-- Session two: each window starts with its kept lines, as the player saw them (short channel names), oldest first,
-- then one muted line that marks where this session starts.
local second, K2, _, saved2 = Session(saved, function(env)
	local lines = C.Lines(env.ChatFrame1)
	local guild, party, loot = Find(lines, "Raid at 8 tonight."), Find(lines, "ready when you are"), Find(lines, "Crocolisk Hide")
	assert(guild and party and loot and guild < party and party < loot, "the kept lines come back in order: " .. table.concat(lines, " | "))
	assert(Plain(lines[guild]):find("[G]", 1, true), "a line comes back as the player saw it, with the short channel name: " .. Plain(lines[guild]))
	local mark = Find(lines, "Chat from your last session")
	assert(mark and mark > loot, "a muted line marks where the new session starts")
	assert(not Find(lines, "a secret line") and not Find(lines, "whispers: hi"), "the secret and Battle.net lines stay gone")
	assert(Find(C.Lines(env.ChatFrame3), "WTS Rugged Hide"), "the trade window gets its own line back")
	assert(not Find(C.Lines(env.ChatFrame2), "Mortal Strike"), "the combat log gets nothing back")
	-- A line said now joins the kept lines; the restored ones are not kept twice.
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "On my way.", { sender = "Thargor", guid = "Player-1-0002" })
end)
assert(#second._errors == 0, "no Lua error: " .. tostring(second._errors[1]))
local kept = saved2.account.chatHistory.characters[K2.Store.CharacterKey()].ChatFrame1
assert(#kept == 4, "three kept lines and the new one, none twice: " .. #kept)
assert(Plain(kept[4][1]):find("On my way.", 1, true), "the new line is the newest")

-- The count per window is a setting: with 2, only the newest two lines are kept, and they come back oldest first.
local _, K3, _, saved3 = Session(Saved({ historyLines = 2 }), function(env)
	for i = 1, 5 do
		C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "line " .. i, { sender = "Thargor", guid = "Player-1-0002" })
	end
end)
local bounded = saved3.account.chatHistory.characters[K3.Store.CharacterKey()].ChatFrame1
assert(#bounded == 2, "two lines are kept: " .. #bounded)
Session(saved3, function(env)
	local lines = C.Lines(env.ChatFrame1)
	local four, five = Find(lines, "line 4"), Find(lines, "line 5")
	assert(four and five and four < five and not Find(lines, "line 3"), "the newest two lines come back, oldest first: " .. table.concat(lines, " | "))
end)

-- The idle-work audit's finding 77: with a full history every new line moved each kept line down one slot. Now a new
-- line takes the oldest line's slot, and the next session still restores and copies the lines oldest first.
local guild = {
	"Raid at 8 tonight.", "ready when you are", "Anyone selling Runecloth?", "LF healer for Scholo", "grats on the mount",
	"summons at the stone please", "who has the UBRS key?", "Onyxia attunement run Sunday", "selling Arcanite Bar 40g",
	"need 2 more for Strat live", "brb, doorbell", "Rag down!", "gz all on the drops",
}
local function Kept(account, K)
	return account.chatHistory.characters[K.Store.CharacterKey()].ChatFrame1
end
local function Order(lines, from, to)
	local last = 0
	for i = from, to do
		local at = Find(lines, guild[i])
		if not at or at <= last then
			return false
		end
		last = at
	end
	return true
end
local _, K7, _, saved7 = Session(Saved({ historyLines = 5 }), function(env, K)
	for i = 1, #guild do
		local before = {}
		for slot, line in ipairs(K.Store.Account().chatHistory and Kept(K.Store.Account(), K) or {}) do
			before[slot] = line
		end
		C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", guild[i], { sender = "Thargor", guid = "Player-1-0002" })
		local lines, changed = Kept(K.Store.Account(), K), 0
		for slot = 1, math.max(#lines, #before) do
			if lines[slot] ~= before[slot] then
				changed = changed + 1
			end
		end
		assert(changed == 1, "line " .. i .. " of a history kept at 5 changes one saved slot, not " .. changed)
	end
end)
assert(#Kept(saved7.account, K7) == 5, "five lines are kept: " .. #Kept(saved7.account, K7))
local _, K8, _, saved8 = Session(saved7, function(env, _, ns)
	local lines = C.Lines(env.ChatFrame1)
	assert(Order(lines, 9, 13) and not Find(lines, guild[8]), "the newest five lines come back, oldest first: " .. table.concat(lines, " | "))
	local copied = {}
	for line in ns.Copy.Text(env.ChatFrame1):gmatch("[^\n]+") do
		copied[#copied + 1] = line
	end
	assert(Order(copied, 9, 13), "the copy window lists them oldest first: " .. table.concat(copied, " | "))
end)

-- Changed input: a full history an earlier version saved in order, then a lower and a higher line count, keep the order.
local said = "|Hchannel:GUILD|h[G]|h |Hplayer:Thargor:42|h[|cff40c7ebThargor|r]|h: "
saved8.account.chatHistory.characters[K8.Store.CharacterKey()].ChatFrame1 = {
	{ said .. guild[11], 0.25, 1, 0.25 }, { said .. guild[12], 0.25, 1, 0.25 }, { said .. guild[13], 0.25, 1, 0.25 },
}
saved8.profiles.Default.Chat.historyLines = 3
local _, K9, _, saved9 = Session(saved8, function(env, K)
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", guild[1], { sender = "Thargor", guid = "Player-1-0002" })
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", guild[2], { sender = "Thargor", guid = "Player-1-0002" })
	K.Options.Write("Chat", "historyLines", 2)
	env.RunTimers()
	K.Options.Write("Chat", "historyLines", 4)
	env.RunTimers()
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", guild[3], { sender = "Thargor", guid = "Player-1-0002" })
end)
assert(#Kept(saved9.account, K9) == 3, "lowering the count to two kept the newest two, and one line joined after raising it: " .. #Kept(saved9.account, K9))
Session(saved9, function(env)
	local lines = C.Lines(env.ChatFrame1)
	assert(Order(lines, 1, 3) and not Find(lines, guild[13]), "the lines come back oldest first after the count changed: " .. table.concat(lines, " | "))
end)

-- Off: nothing is kept, nothing comes back, and turning it off forgets this character's lines.
local _, K4, _, saved4 = Session(Saved({ history = false }), function(env)
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "not kept", { sender = "Thargor", guid = "Player-1-0002" })
end)
local off = saved4.account.chatHistory and saved4.account.chatHistory.characters[K4.Store.CharacterKey()]
assert(off == nil or off.ChatFrame1 == nil, "with history off no line is kept")
local env5, K5 = C.New({ saved = saved2 })
C.Enable(env5, K5)
K5.Options.Write("Chat", "history", false)
env5.RunTimers()
C.W.CoreEnv.Logout(env5)
local forgotten = env5.KstyleUIDB.account.chatHistory
assert(forgotten == nil or forgotten.characters == nil or forgotten.characters[K5.Store.CharacterKey()] == nil, "turning history off forgets this character's lines")

-- With history off from the start, a new session gets nothing back.
local env6, K6 = C.New({ saved = (function()
	local s = saved2
	s.profiles.Default.Chat.history = false
	return s
end)() })
C.Enable(env6, K6)
assert(not Find(C.Lines(env6.ChatFrame1), "Raid at 8 tonight."), "with history off nothing comes back")

print("ok - chat history: kept per window across sessions, bounded, plain, and only while the setting is on")
