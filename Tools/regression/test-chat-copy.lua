-- test-chat-copy.lua: KstyleUI_Chat's copy window, its button and tab-menu entry, and the live preview in the settings window.
local C = dofile("Tools/regression/chat_env.lua")
local W = C.W

local function has(text, part)
	return type(text) == "string" and text:find(part, 1, true) ~= nil
end

local function called(object, method)
	for _, call in ipairs(object._calls) do
		if call.method == method then
			return true
		end
	end
	return false
end

local function element(K, key)
	for _, el in ipairs(K.Layout.Elements()) do
		if el.key == key then
			return el
		end
	end
end

-- The window shows the chat's lines as plain text, newest last, with secret lines replaced.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	env.ChatFrame1:AddMessage("|cffff0000You receive loot:|r |cff9d9d9d|Hitem:1|h[Rugged Hide]|h|r", 1, 1, 1)
	env.ChatFrame1:AddMessage(env.Secret("hidden"), 1, 1, 1)
	C.Say(env, env.ChatFrame1, "CHAT_MSG_GUILD", "see https://a.com")
	assert(ns.Copy.Open(env.ChatFrame1), "the window opens")
	env.RunTimers()
	W.Settle(env)
	local window = ns.Copy.Window()
	assert(window and window:IsShown(), "shown")
	local text = window.area:GetText()
	local lines = {}
	for line in (text .. "\n"):gmatch("(.-)\n") do
		lines[#lines + 1] = line
	end
	assert(#lines == 3, "one line per message: " .. text)
	assert(has(lines[1], "You receive loot: [Rugged Hide]") and not has(lines[1], "|c"), "plain text: " .. lines[1])
	assert(lines[2] == K.L["(a line the game keeps hidden)"], "a secret line is replaced: " .. lines[2])
	assert(has(lines[3], "[G] [Thargor]: see https://a.com"), "the decorated line, plain: " .. lines[3])
	assert(called(window.area.box, "HighlightText"), "the text is selected, ready for Ctrl+C")
	local el = element(K, "chat.copy")
	assert(el and el.module == "Chat" and el.opts.resizable, "a resizable Layout element")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The copy button sits in the panel's tab strip and copies the selected window; turning it off widens the messages.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	local button = ns.Panel.CopyButton()
	assert(button and button:IsShown(), "the copy button shows")
	env.GENERAL_CHAT_DOCK.selected = env.ChatFrame2
	button:GetScript("OnClick")(button, "LeftButton")
	env.RunTimers()
	assert(ns.Copy.Window():IsShown() and ns.Copy.Source() == env.ChatFrame2, "it copies the selected window")
	local right = select(4, env.ChatFrame1:GetPoint(2))
	K.Options.Write("Chat", "copyButton", false)
	env.RunTimers()
	assert(not button:IsShown(), "hidden by the setting")
	assert(select(4, env.ChatFrame1:GetPoint(2)) > right, "the messages take its room")
	env.ChatFrame1Tab:SetAlpha(0.4)
	K.Options.Write("Chat", "copyButton", true)
	env.ChatFrame1Tab:SetAlpha(0.4)
	assert(math.abs(button:GetAlpha() - 0.4) < 1e-6, "it fades with the tabs")
end

-- The chat tab's right-click menu offers Copy chat for that tab's window.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	local entries = C.OpenMenu(env, "MENU_FCF_TAB", env.ChatFrame2Tab)
	assert(#entries == 1 and entries[1].label == K.L["Copy chat"], "one entry")
	entries[1].onClick()
	env.RunTimers()
	assert(ns.Copy.Source() == env.ChatFrame2, "copies the tab's window")
	K.Modules.Disable("Chat")
	env.RunTimers()
	W.Settle(env)
	assert(#C.OpenMenu(env, "MENU_FCF_TAB", env.ChatFrame2Tab) == 0, "the entry goes with the module")
	assert(not ns.Copy.Window():IsShown(), "the window closes")
end

-- Without Menu.ModifyMenu the button still works and the devlog says why the menu has no entry.
do
	local env, K = C.New({ install = { noMenu = true } })
	C.Enable(env, K)
	local found = false
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		found = found or (entry.module == "Chat" and has(entry.message, "Menu.ModifyMenu"))
	end
	assert(found, "logged")
end

-- The settings window's live preview: a small panel with tabs and sample lines that follow the settings.
do
	local env, K = C.New()
	local build = K.Options.Preview("Chat")
	assert(type(build) == "function", "a preview builder")
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(320, 240)
	local preview = build(parent)
	assert(preview and type(preview.Refresh) == "function", "a frame with Refresh")
	preview:Refresh()
	local first = preview.lines[1]:GetText()
	assert(has(first, "[G]") and has(first, "["), "a sample guild line with the short channel: " .. tostring(first))
	K.Options.Write("Chat", "timestamp", "none")
	K.Options.Write("Chat", "channels", "full")
	preview:Refresh()
	first = preview.lines[1]:GetText()
	assert(not has(first, "[G]") and has(first, "[Guild]") and first:sub(1, 2) == "|H", "follows the settings: " .. first)
	local linked = false
	for _, line in ipairs(preview.lines) do
		linked = linked or has(line:GetText(), "|Haddon:KstyleUI:url:")
	end
	assert(linked, "a sample link")
	K.Options.Write("Chat", "tabStyle", "filled")
	preview:Refresh()
	assert(preview.fill:IsShown(), "the filled style shows its tile")
	assert(preview.tabs[1]:GetParent():GetFrameLevel() > preview.fill:GetFrameLevel(), "the tab label draws above the tile")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("chat copy ok")
