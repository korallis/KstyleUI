-- test-chat-stamps.lua: KstyleUI_Chat's timestamps through the game's showTimestamps CVar: the game stamps chat lines in KstyleUI's format, KstyleUI rewrites only lines whose channel it shortens, and the player's own value comes back when the module turns off.
local C = dofile("Tools/regression/chat_env.lua")

local function has(text, part)
	return type(text) == "string" and text:find(part, 1, true) ~= nil
end

local function Stamp(F, fmt, c)
	return "|c" .. F.Hex(c.r, c.g, c.b) .. "[" .. fmt .. "]|r "
end

local function TextColour(K)
	return K.Options.Read("Chat", "timestampColor")
end

-- Counts TransformMessages calls on a chat frame. Wraps before the module hooks anything.
local function CountTransforms(frame)
	local calls = { n = 0 }
	local transform = frame.TransformMessages
	frame.TransformMessages = function(self, ...)
		calls.n = calls.n + 1
		return transform(self, ...)
	end
	return calls
end

local function Memory(env, K)
	local all = env.KstyleUIDB.account.chatTimestamps
	return all and all[K.Store.CharacterKey()]
end

-- On: the game draws KstyleUI's bracketed, coloured timestamp, and KstyleUI stops rewriting every line.
do
	local env, K = C.New()
	local calls = CountTransforms(env.ChatFrame1)
	C.Enable(env, K)
	local F = env._addons.KstyleUI_Chat.Format
	assert(env._cvars.showTimestamps == Stamp(F, "%H:%M", TextColour(K)), "the CVar holds KstyleUI's format: " .. tostring(env._cvars.showTimestamps))

	env._now = os.time({ year = 2026, month = 11, day = 7, hour = 14, min = 31 })
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "hi")
	local line = C.Last(env.ChatFrame1)
	assert(line:sub(1, 4) == "|cff", "the timestamp is coloured: " .. line)
	assert(F.Strip(line) == "[14:31] [G] [Thargor]: hi", "one timestamp, then the short channel: " .. F.Strip(line))
	assert(calls.n == 1, "a shortened channel line is rewritten once, got " .. calls.n)

	env.ChatFrame1:AddMessage("You receive loot: [Hide].", 0, 1, 0)
	assert(C.Last(env.ChatFrame1) == "You receive loot: [Hide].", "a system line is left as the game wrote it")
	assert(calls.n == 1, "a system line is not rewritten")

	K.Options.Write("Chat", "channels", "full")
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "full")
	assert(F.Strip(C.Last(env.ChatFrame1)) == "[14:31] [Guild] [Thargor]: full", "full channel names: " .. F.Strip(C.Last(env.ChatFrame1)))
	assert(calls.n == 1, "with full channel names no line is rewritten")

	local reads = 0
	local get = env.C_CVar.GetCVar
	env.C_CVar.GetCVar = function(name)
		reads = reads + 1
		return get(name)
	end
	for i = 1, 3 do
		env.ChatFrame1:AddMessage("line " .. i, 1, 1, 1)
	end
	assert(reads == 0, "new lines do not read the CVar")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Settings: the format and the colour rewrite the CVar; none and a damaged format turn the game's timestamps off.
do
	local env, K = C.New()
	C.Enable(env, K)
	local F = env._addons.KstyleUI_Chat.Format
	K.Options.Write("Chat", "timestamp", "%I:%M:%S %p")
	assert(env._cvars.showTimestamps == Stamp(F, "%I:%M:%S %p", TextColour(K)), "a new format: " .. env._cvars.showTimestamps)
	K.Options.Write("Chat", "timestampColor", { r = 1, g = 0, b = 0 })
	assert(env._cvars.showTimestamps == "|cffff0000[%I:%M:%S %p]|r ", "a new colour: " .. env._cvars.showTimestamps)
	K.Options.Write("Chat", "timestamp", "%I:%M")
	assert(env._cvars.showTimestamps == "|cffff0000[%I:%M]|r ", "the game's 12-hour format without AM or PM is offered too")
	K.Options.Write("Chat", "timestamp", "none")
	assert(env._cvars.showTimestamps == "none", "none turns the game's timestamps off")
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "x")
	assert(F.Strip(C.Last(env.ChatFrame1)) == "[G] [Thargor]: x", "no timestamp: " .. F.Strip(C.Last(env.ChatFrame1)))
	env.ChatFrame1:AddMessage("You receive loot.", 1, 1, 1)
	assert(C.Last(env.ChatFrame1) == "You receive loot.", "and KstyleUI adds none either")
	K.Options.Write("Chat", "timestamp", "%Y")
	assert(env._cvars.showTimestamps == "none", "a damaged format never reaches the CVar")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Off: the player's own value comes back, and the saved memory is cleared.
do
	local env, K = C.New({ setup = function(e) e._cvars.showTimestamps = "%I:%M " end })
	C.Enable(env, K)
	assert(env._cvars.showTimestamps ~= "%I:%M ", "on: KstyleUI's format")
	local memory = Memory(env, K)
	assert(memory and memory.original == "%I:%M " and memory.written == env._cvars.showTimestamps, "the player's value is remembered")
	K.Modules.Disable("Chat")
	env.RunTimers()
	assert(env._cvars.showTimestamps == "%I:%M ", "off: the player's value is back: " .. tostring(env._cvars.showTimestamps))
	assert(Memory(env, K) == nil, "the memory is cleared")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- After a reload the CVar still holds KstyleUI's format, and the player's value is still the one restored.
do
	local env, K = C.New({ setup = function(e) e._cvars.showTimestamps = "%H:%M:%S " end })
	C.Enable(env, K)
	local ours = env._cvars.showTimestamps
	local saved = env.KstyleUIDB
	env, K = C.New({ saved = saved, setup = function(e) e._cvars.showTimestamps = ours end })
	assert(K.Modules.IsRunning("Chat"), "the module starts at login")
	assert(env._cvars.showTimestamps == ours and #env._cvarWrites == 0, "an unchanged CVar is not written again")
	assert(Memory(env, K).original == "%H:%M:%S ", "the player's value survives the reload")
	K.Modules.Disable("Chat")
	env.RunTimers()
	assert(env._cvars.showTimestamps == "%H:%M:%S ", "off after a reload: " .. tostring(env._cvars.showTimestamps))
end

-- The client loads the character's saved CVars late: KstyleUI takes that value as the player's and writes its own again.
do
	local env, K = C.New()
	C.Enable(env, K)
	local ours = env._cvars.showTimestamps
	env._cvars.showTimestamps = "%H:%M "
	env.FireEvent("VARIABLES_LOADED")
	env.RunTimers()
	assert(env._cvars.showTimestamps == ours, "KstyleUI's format again after the late load")
	assert(Memory(env, K).original == "%H:%M ", "the late value is the player's")
	K.Modules.Disable("Chat")
	env.RunTimers()
	assert(env._cvars.showTimestamps == "%H:%M ", "off: the late value comes back")
end

-- In combat the CVar waits for combat to end, and lines never get two timestamps meanwhile.
do
	local env, K = C.New()
	C.Enable(env, K)
	local F = env._addons.KstyleUI_Chat.Format
	local before = env._cvars.showTimestamps
	env.SetCombat(true)
	K.Options.Write("Chat", "timestamp", "%H:%M:%S")
	assert(env._cvars.showTimestamps == before, "no CVar write in combat")
	env._now = os.time({ year = 2026, month = 11, day = 7, hour = 9, min = 5, sec = 7 })
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "pull")
	assert(F.Strip(C.Last(env.ChatFrame1)) == "[09:05] [G] [Thargor]: pull", "one timestamp in combat: " .. F.Strip(C.Last(env.ChatFrame1)))
	env.SetCombat(false)
	env.RunTimers()
	assert(env._cvars.showTimestamps == Stamp(F, "%H:%M:%S", TextColour(K)), "written when combat ends")
end

-- A change from Blizzard's own options becomes KstyleUI's setting; any other change is put back.
do
	local env, K = C.New()
	C.Enable(env, K)
	local F = env._addons.KstyleUI_Chat.Format
	local panel = { shown = true }
	function panel.IsShown()
		return panel.shown
	end
	env.SettingsPanel = panel

	env.C_CVar.SetCVar("showTimestamps", "%I:%M %p ")
	env.RunTimers()
	assert(K.Options.Read("Chat", "timestamp") == "%I:%M %p", "Blizzard's choice is KstyleUI's setting now")
	assert(env._cvars.showTimestamps == Stamp(F, "%I:%M %p", TextColour(K)), "drawn in KstyleUI's style: " .. env._cvars.showTimestamps)

	env.C_CVar.SetCVar("showTimestamps", "none")
	env.RunTimers()
	assert(K.Options.Read("Chat", "timestamp") == "none" and env._cvars.showTimestamps == "none", "Blizzard's None turns them off")

	K.Options.Write("Chat", "timestamp", "%H:%M")
	env.C_CVar.SetCVar("showTimestamps", "%d/%m ")
	env.RunTimers()
	assert(K.Options.Read("Chat", "timestamp") == "%H:%M", "a value KstyleUI does not offer is not taken")
	assert(env._cvars.showTimestamps == Stamp(F, "%H:%M", TextColour(K)), "and KstyleUI's format is put back")

	panel.shown = false
	env.C_CVar.SetCVar("showTimestamps", "none")
	env.RunTimers()
	assert(K.Options.Read("Chat", "timestamp") == "%H:%M", "a change from elsewhere does not change the setting")
	assert(env._cvars.showTimestamps == Stamp(F, "%H:%M", TextColour(K)), "and KstyleUI's format is put back")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A client that drops colour codes from the CVar gets the plain format.
do
	local env, K = C.New({
		setup = function(e)
			e._cvarFilter = function(_, value)
				return (value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
			end
		end,
	})
	C.Enable(env, K)
	local F = env._addons.KstyleUI_Chat.Format
	assert(env._cvars.showTimestamps == "[%H:%M] ", "the plain format: " .. tostring(env._cvars.showTimestamps))
	env._now = os.time({ year = 2026, month = 11, day = 7, hour = 9, min = 5 })
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "hi")
	assert(F.Strip(C.Last(env.ChatFrame1)) == "[09:05] [G] [Thargor]: hi", "one timestamp: " .. F.Strip(C.Last(env.ChatFrame1)))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A client that refuses the value keeps the player's, and KstyleUI stamps lines itself only when the game does not.
do
	local env, K = C.New({
		setup = function(e)
			e._cvarFilter = function(name)
				return e._cvars[name]
			end
		end,
	})
	C.Enable(env, K)
	local F = env._addons.KstyleUI_Chat.Format
	assert(env._cvars.showTimestamps == "none", "the player's value stays")
	env._now = os.time({ year = 2026, month = 11, day = 7, hour = 9, min = 5 })
	env.ChatFrame1:AddMessage("You receive loot.", 1, 1, 1)
	assert(F.Strip(C.Last(env.ChatFrame1)) == "[09:05] You receive loot.", "KstyleUI's own timestamp: " .. F.Strip(C.Last(env.ChatFrame1)))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A client without SetCVar: KstyleUI stamps lines itself, and never on top of the game's own timestamps.
do
	local env, K = C.New({ install = { noSetCVar = true } })
	C.Enable(env, K)
	local F = env._addons.KstyleUI_Chat.Format
	env._now = os.time({ year = 2026, month = 11, day = 7, hour = 9, min = 5 })
	env.ChatFrame1:AddMessage("You receive loot.", 1, 1, 1)
	assert(F.Strip(C.Last(env.ChatFrame1)) == "[09:05] You receive loot.", "KstyleUI's own timestamp: " .. F.Strip(C.Last(env.ChatFrame1)))
	env._cvars.showTimestamps = "%H:%M "
	env.FireEvent("CVAR_UPDATE", "showTimestamps", "%H:%M ")
	env.RunTimers()
	env.ChatFrame1:AddMessage("09:05 You receive loot.", 1, 1, 1)
	assert(C.Last(env.ChatFrame1) == "09:05 You receive loot.", "no second timestamp")
	env._cvars.showTimestamps = "none"
	env.FireEvent("CVAR_UPDATE", "showTimestamps", "none")
	env.RunTimers()
	env.ChatFrame1:AddMessage("You receive loot.", 1, 1, 1)
	assert(has(F.Strip(C.Last(env.ChatFrame1)), "[09:05] "), "turning the game's timestamps off brings KstyleUI's back")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("test-chat-stamps: ok")
