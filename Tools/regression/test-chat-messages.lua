-- test-chat-messages.lua: KstyleUI_Chat's message pipeline: URL links, class-coloured names, timestamps and short channel names, with secret lines passed through untouched.
local C = dofile("Tools/regression/chat_env.lua")

local HOOKED = { AddMessage = true, SetPoint = true, SetAlpha = true }

local function has(text, part)
	return type(text) == "string" and text:find(part, 1, true) ~= nil
end

local function count(list)
	local n = 0
	for _ in pairs(list or {}) do
		n = n + 1
	end
	return n
end

-- Off by default: loading registers the module and nothing else.
do
	local env, K = C.New()
	assert(K.Modules.IsEnabled("Chat") == false, "the chat module is off in code defaults")
	assert(count(env._messageFilters) == 0 and #env._nameFilters == 0, "no filter before Enable")
	assert(rawget(env.ChatFrame1, "AddMessage") and C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "see https://a.com"), "chat works")
	assert(C.Last(env.ChatFrame1) == "|Hchannel:GUILD|h[Guild]|h |Hplayer:Thargor:42|h[Thargor]|h: see https://a.com", "an off module changes no line")
	assert(K.Options.Get("Chat"), "the settings page is registered")
end

-- On: a guild line gets the timestamp, the short channel, the class-coloured name and the link.
do
	local env, K = C.New()
	local snap = C.Snapshot(env)
	C.Enable(env, K)
	assert(K.Modules.IsRunning("Chat"), "the module runs: " .. tostring(env._errors[1]))
	assert(env._messageFilters.CHAT_MSG_GUILD and #env._messageFilters.CHAT_MSG_GUILD == 1, "a URL filter on guild chat")
	assert(#env._nameFilters == 1, "one sender name filter")
	env._now = os.time({ year = 2026, month = 11, day = 7, hour = 14, min = 31 })
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "see https://a.com now", { guid = "Player-1-0001" })
	local line = C.Last(env.ChatFrame1)
	local F = env._addons.KstyleUI_Chat.Format
	assert(line:sub(1, 1) == "|" and has(F.Strip(line), "[14:31] [G] [Thargor]: see https://a.com now"), "decorated line: " .. tostring(F.Strip(line)))
	assert(has(line, "|H" .. F.LINK .. "https://a.com|h"), "the URL is a link")
	local r, g, b = K.Theme.Brighten(K.Theme.ClassColor("WARRIOR"))
	assert(has(line, "[|c" .. F.Hex(r, g, b) .. "Thargor|r]"), "the warrior's name is in the class colour")
	local entry = C.Newest(env.ChatFrame1)
	assert(entry.n == 10 and entry[8] == "CHAT_MSG_GUILD" and type(entry[10]) == "function", "the line keeps every value Blizzard stored with it")
	C.Check(env, snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A numbered channel keeps its number and name; a system line gets only the timestamp.
do
	local env, K = C.New()
	C.Enable(env, K)
	env._now = os.time({ year = 2026, month = 11, day = 7, hour = 9, min = 5 })
	C.Say(env, env.ChatFrame1, "CHAT_MSG_CHANNEL", "LFM", { channel = "1. General - Riverglades" })
	assert(has(C.Last(env.ChatFrame1), "|Hchannel:channel:1|h[1. General]|h"), "the zone goes: " .. C.Last(env.ChatFrame1))
	env.ChatFrame1:AddMessage("You receive loot: [Hide].", 0, 1, 0)
	local F = env._addons.KstyleUI_Chat.Format
	assert(F.Strip(C.Last(env.ChatFrame1)) == "[09:05] You receive loot: [Hide].", "a system line: " .. tostring(F.Strip(C.Last(env.ChatFrame1))))
	assert(C.Newest(env.ChatFrame1)[2] == 0, "the line keeps its colour")
end

-- Secret lines pass through untouched, in the filters and in the frame.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	local secret = env.Secret("https://hidden.com")
	assert(C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", secret), "a secret line is never discarded")
	local entry = C.Newest(env.ChatFrame1)
	assert(env.issecretvalue(entry[1]), "the secret line is still the game's secret")
	local filter = env._messageFilters.CHAT_MSG_GUILD[1]
	assert(filter(env.ChatFrame1, "CHAT_MSG_GUILD", secret, "Thargor") == false, "the URL filter passes a secret on")
	local nameFilter = env._nameFilters[1]
	assert(nameFilter("CHAT_MSG_GUILD", env.Secret("Thargor"), "x", "Thargor") == nil, "a secret name is left alone")
	assert(nameFilter("CHAT_MSG_GUILD", "Thargor", "x", "Thargor", "", "", "", "", 0, 1, "", 0, 42, env.Secret("Player-1-0001")) == nil, "a secret GUID is left alone")
	env.ChatFrame1:AddMessage(env.Secret("whatever"), 1, 1, 1)
	assert(env.issecretvalue(C.Last(env.ChatFrame1)), "a secret system line is untouched")
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "after https://b.com")
	assert(has(C.Last(env.ChatFrame1), "|Hplayer:"), "a plain line after a secret one still works")
	local others = 0
	for _, e in ipairs(C.Entries(env.ChatFrame1)) do
		if env.issecretvalue(e[1]) then
			others = others + 1
		end
	end
	assert(others == 2, "the secret lines in the history stay secret")
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(ns.Messages, "the pipeline is exposed for the other parts")
end

-- The combat log keeps its own lines.
do
	local env, K = C.New()
	C.Enable(env, K)
	env._combatLog = true
	env.ChatFrame2:AddMessage("Your Fireball hits.", 1, 1, 1)
	assert(C.Last(env.ChatFrame2) == "Your Fireball hits.", "no timestamp in the combat log")
end

-- Blizzard's own timestamps win, so a line never gets two.
do
	local env, K = C.New()
	C.Enable(env, K)
	env._cvars.showTimestamps = "%H:%M "
	env.FireEvent("CVAR_UPDATE", "showTimestamps", "%H:%M ")
	env.ChatFrame1:AddMessage("09:05 You receive loot.", 1, 1, 1)
	assert(C.Last(env.ChatFrame1) == "09:05 You receive loot.", "no second timestamp")

	-- The setting is read once and again only when a CVar changes, not on every line.
	local reads = 0
	local get = env.C_CVar.GetCVar
	env.C_CVar.GetCVar = function(name)
		reads = reads + 1
		return get(name)
	end
	env.ChatFrame1:AddMessage("09:06 You receive loot.", 1, 1, 1)
	env.ChatFrame1:AddMessage("09:07 You receive loot.", 1, 1, 1)
	assert(reads == 0, "new lines do not read the CVar again")
	env._cvars.showTimestamps = "none"
	env.FireEvent("CVAR_UPDATE", "showTimestamps", "none")
	env.ChatFrame1:AddMessage("You receive loot.", 1, 1, 1)
	assert(C.Last(env.ChatFrame1) ~= "You receive loot.", "turning the game's timestamps off brings KstyleUI's back")
	assert(reads == 1, "and the CVar is read once after it changes")
end

-- Settings: each feature switches off.
do
	local env, K = C.New()
	C.Enable(env, K)
	K.Options.Write("Chat", "urls", false)
	K.Options.Write("Chat", "classNames", false)
	K.Options.Write("Chat", "timestamp", "none")
	K.Options.Write("Chat", "channels", "full")
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "see https://a.com", { guid = "Player-1-0002" })
	assert(C.Last(env.ChatFrame1) == "|Hchannel:GUILD|h[Guild]|h |Hplayer:Thargor:42|h[Thargor]|h: see https://a.com", "everything off: " .. C.Last(env.ChatFrame1))
	K.Options.Write("Chat", "channels", "short")
	K.Options.Write("Chat", "abbr.guild", "GU")
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "x")
	assert(has(C.Last(env.ChatFrame1), "[GU]"), "a changed abbreviation applies at once")
	K.Options.Write("Chat", "timestamp", "%Y")
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "y")
	assert(C.Last(env.ChatFrame1):sub(1, 1) == "|" and not has(C.Last(env.ChatFrame1), "[20"), "a damaged timestamp format adds nothing")
	K.Options.Write("Chat", "urls", true)
	K.Options.Write("Chat", "accentSource", "custom")
	K.Options.Write("Chat", "accentColor", { r = 1, g = 0, b = 0 })
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "z https://c.com")
	assert(has(C.Last(env.ChatFrame1), "|cffff0000|H"), "links take the custom accent")
end

-- Clicking a link opens a dialog with the URL selected for copying.
do
	local env, K = C.New()
	C.Enable(env, K)
	local F = env._addons.KstyleUI_Chat.Format
	env.EventRegistry:TriggerEvent("SetItemRef", F.LINK .. "https://a.com/x", "https://a.com/x", "LeftButton", env.ChatFrame1)
	env.RunTimers()
	local host = K.Widgets.DialogHost()
	assert(host:IsShown() and host.editBox:IsShown(), "the dialog opens with an edit box")
	assert(host.editBox:GetText() == "https://a.com/x", "it holds the URL")
	local highlighted = false
	for _, call in ipairs(host.editBox._calls) do
		highlighted = highlighted or call.method == "HighlightText"
	end
	assert(highlighted, "the URL is selected, ready for Ctrl+C")
	env.EventRegistry:TriggerEvent("SetItemRef", "item:19019", "[Sword]", "LeftButton", env.ChatFrame1)
	assert(host.editBox:GetText() == "https://a.com/x", "other links are not ours")
end

-- A line identical to an older one decorates the new line, not the old one, also after the history wraps.
do
	local env, K = C.New()
	env.ChatFrame1:AddMessage("You are now away.", 1, 1, 0)
	C.Enable(env, K)
	env.ChatFrame1:AddMessage("You are now away.", 1, 1, 0)
	local lines = C.Lines(env.ChatFrame1)
	assert(lines[1] == "You are now away.", "the old line keeps its text: " .. lines[1])
	assert(lines[2] ~= "You are now away." and has(lines[2], "You are now away."), "the new line is decorated")
	for i = 1, 11 do
		env.ChatFrame1:AddMessage("line " .. i, 1, 1, 1)
	end
	K.Modules.Disable("Chat")
	env.RunTimers()
	env.ChatFrame1:AddMessage("Same.", 1, 1, 1)
	C.Enable(env, K)
	env.ChatFrame1:AddMessage("Same.", 1, 1, 1)
	lines = C.Lines(env.ChatFrame1)
	assert(lines[#lines - 1] == "Same.", "after the wrap, the older copy is untouched: " .. lines[#lines - 1])
	assert(lines[#lines] ~= "Same." and has(lines[#lines], "Same."), "after the wrap, the newest copy is decorated")
end

-- A link clicked while another dialog is open waits, replaces an older link dialog, and is selected when it shows.
do
	local env, K = C.New()
	C.Enable(env, K)
	local F = env._addons.KstyleUI_Chat.Format
	local blocker = K.Widgets.Popup({ title = "Busy", text = "Another dialog" })
	env.EventRegistry:TriggerEvent("SetItemRef", F.LINK .. "https://old.com", "", "LeftButton", env.ChatFrame1)
	env.EventRegistry:TriggerEvent("SetItemRef", F.LINK .. "https://new.com", "", "LeftButton", env.ChatFrame1)
	env.RunTimers()
	blocker:Close()
	env.RunTimers()
	local host = K.Widgets.DialogHost()
	assert(host.editBox:GetText() == "https://new.com", "the newest link shows, not a stale one: " .. tostring(host.editBox:GetText()))
	host.editBox._calls = {}
	host.editBox:GetScript("OnEditFocusGained")(host.editBox)
	local highlighted = false
	for _, call in ipairs(host.editBox._calls) do
		highlighted = highlighted or call.method == "HighlightText"
	end
	assert(highlighted, "the URL is selected when its dialog takes focus")
	local busy = K.Widgets.Popup({ title = "Busy", text = "Another dialog" })
	env.EventRegistry:TriggerEvent("SetItemRef", F.LINK .. "https://queued.com", "", "LeftButton", env.ChatFrame1)
	K.Modules.Disable("Chat")
	env.RunTimers()
	busy:Close()
	env.RunTimers()
	assert(host.editBox:GetText() ~= "https://queued.com", "turning the module off drops a queued link dialog")
end

-- A whisper window opened later is decorated too.
do
	local env, K = C.New()
	C.Enable(env, K)
	local frame = env.FCF_OpenTemporaryWindow("WHISPER", "Kragar")
	env.RunTimers()
	C.Say(env, frame, "CHAT_MSG_GUILD", "hi")
	assert(has(C.Last(frame), "[G]"), "the new window's lines are decorated")
end

-- Off again: filters go, lines pass through, and the module asks for a reload.
do
	local env, K = C.New()
	C.Enable(env, K)
	K.Modules.Disable("Chat")
	env.RunTimers()
	assert(#env._messageFilters.CHAT_MSG_GUILD == 0 and #env._nameFilters == 0, "filters removed")
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "see https://a.com")
	assert(C.Last(env.ChatFrame1) == "|Hchannel:GUILD|h[Guild]|h |Hplayer:Thargor:42|h[Thargor]|h: see https://a.com", "lines pass through")
	assert(count(env._callbacks.SetItemRef) == 0, "the link callback is gone")
	assert(K.Modules.NeedsReload(), "a reskin module asks for a reload")
	C.Enable(env, K)
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "back")
	assert(has(C.Last(env.ChatFrame1), "[G]"), "on again without a reload")
end

-- A client without the filter registries, TransformMessages or EventRegistry still runs, and logs the path.
do
	local env, K = C.New({ install = { noFilters = true, noTransform = true, noEventRegistry = true } })
	C.Enable(env, K)
	assert(K.Modules.IsRunning("Chat"), "the module still runs")
	env.ChatFrame1:AddMessage("plain", 1, 1, 1)
	assert(C.Last(env.ChatFrame1) == "plain", "lines are untouched")
	local logged = {}
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "Chat" then
			logged[#logged + 1] = entry.message
		end
	end
	local all = table.concat(logged, "\n")
	assert(has(all, "AddMessageEventFilter") and has(all, "TransformMessages") and has(all, "EventRegistry"), "each missing API is logged:\n" .. all)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("chat messages ok")
