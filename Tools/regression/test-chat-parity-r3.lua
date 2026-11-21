-- test-chat-parity-r3.lua: the edit box's own font and text size follow the message font by default (a v0.2.8 profile too), apply switched on to the box and its header, leave the messages alone, restore switched off and show in the preview.
local C = dofile("Tools/regression/chat_env.lua")

local function boot(settings)
	local saved = { version = 42, profiles = { Default = { Chat = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = C.New({ saved = saved })
	env.RunTimers()
	assert(K.Modules.IsRunning("Chat"), tostring(env._errors[1]))
	return env, K, ns
end

local function write(env, K, key, value)
	assert(K.Options.Write("Chat", key, value) ~= false, key .. " must write")
	env.RunTimers()
end

local function same(a, b, what)
	local pa, sa, fa = a:GetFont()
	local pb, sb, fb = b:GetFont()
	assert(pa == pb and math.abs(sa - sb) < 1e-6 and fa == fb, what .. ": " .. tostring(pa) .. " " .. tostring(sa) .. " against " .. tostring(pb) .. " " .. tostring(sb))
end

-- A v0.2.8-shaped profile: the edit box keeps the message font and size, as today.
local env, K, ns = boot({ enabled = true, fontSize = 14 })
local s, chat = K.Store.Module("Chat"), env.ChatFrame1
assert(s.editFont == "messages" and s.editFontSize == -1, "the new options default to following the messages")
same(chat.editBox, chat, "the edit box follows the message font")
same(chat.editBox.header, chat, "the edit box header follows the message font")
local messagePath, messageSize = chat:GetFont()

-- Switched on: the box and its header take their own size and font; the messages do not move.
write(env, K, "editFontSize", 20)
local _, boxSize = chat.editBox:GetFont()
assert(math.abs(boxSize - messageSize * 20 / 14) < 0.5, "the edit box takes its own size, got " .. tostring(boxSize))
same(chat.editBox.header, chat.editBox, "the header follows the box")
local path, size = chat:GetFont()
assert(path == messagePath and size == messageSize, "the messages keep their font and size")
local other
for _, option in ipairs(K.Widgets.InheritedFontOptions()) do
	if option.value ~= "" and option.value ~= messagePath then other = option.value break end
end
write(env, K, "editFont", other)
assert(chat.editBox:GetFont() == other, "the edit box takes its own font")
assert(chat:GetFont() == messagePath, "the messages keep their font")

-- A message size change keeps the box's own choice.
write(env, K, "fontSize", 16)
assert(chat.editBox:GetFont() == other and math.abs(select(2, chat.editBox:GetFont()) - boxSize) < 1e-6, "the box keeps its own font and size")

-- The preview shows typed text in the edit box font, and hides it again when the box follows the messages.
local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
parent:SetSize(320, 240)
local preview = K.Options.Preview("Chat")(parent)
preview:Refresh()
assert(preview.edit:IsShown() and preview.edit.text:IsShown() and preview.edit.text:GetFont() == other, "the preview shows the edit box font")

-- Switched off: the box follows the message font and size again.
write(env, K, "editFont", "messages")
write(env, K, "editFontSize", -1)
same(chat.editBox, chat, "the edit box follows the messages again")
same(chat.editBox.header, chat, "the header follows the messages again")
preview:Refresh()
assert(not preview.edit:IsShown() and not preview.edit.text:IsShown(), "the preview keeps today's look")
-- The message font and size rows no longer say they set the edit box outright (PR #657 review).
local rows = 0
for _, row in ipairs(ns.Schema()) do
	if row.key == "font" or row.key == "fontSize" then
		rows = rows + 1
		assert(row.help:find("unless it has its own", 1, true), row.key .. "'s help claims the edit box outright: " .. row.help)
	end
end
assert(rows == 2, "both message rows checked")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-chat-parity-r3: ok")
