-- gallery_chat.lua: KstyleUI_Chat's frames beyond the HUD's panel, each cropped as one frame of the gallery: the
-- tab strip with the filled tab style, the edit box skinned while the player types, an undocked window on its own
-- glass, the copy window open with the general window's lines, and the settings window's live preview. The chat
-- panel itself is the HUD scene's frame. The stub ScrollingMessageFrame draws nothing, so the scene lays the lines
-- out as scenes/chat.lua does (its layout is local to that scene, so the minimum is copied here).
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene
local C = dofile("Tools/regression/chat_env.lua")

local TABS = { "General", "Combat", "Loot", "Trade" }
local LINES = {
	{ "CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:4232::::::::38:::::|h[Crocolisk Hide]|h|r x2." },
	{ "CHAT_MSG_COMBAT_XP_GAIN", "You gain 168 experience." },
	{ "CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:4304::::::::38:::::|h[Rugged Hide]|h|r." },
	{ "CHAT_MSG_CHANNEL", "Anyone for croc hunt?", { sender = "Riverglades", channel = "1. General - Riverglades", guid = "Player-1-0001" } },
	{ "CHAT_MSG_CHANNEL", "LFM tank for Razorfen Kraul", { sender = "Thargor", channel = "1. General - Riverglades", guid = "Player-1-0002" } },
}
local TRADE = {
	{ "CHAT_MSG_CHANNEL", "WTS [Rugged Hide] x20, 2g", { sender = "Thargor", channel = "2. Trade - City", guid = "Player-1-0002" } },
	{ "CHAT_MSG_CHANNEL", "LF enchanter, have mats", { sender = "Riverglades", channel = "2. Trade - City", guid = "Player-1-0001" } },
}
local LOOT = { 0, 0.67, 0 }
local EXPERIENCE = { 0.44, 0.44, 1 }
local UNDOCKED = { x = 1200, y = 640, width = 300, height = 120 }
local EDIT_HEIGHT = 32
local EDIT_GAP = 20

local function plain(word)
	return (word:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""))
end

-- Lines(env, chat) lays the window's history out bottom up in its font, wrapped to its width, one font string a
-- row, as ScrollingMessageFrame does in the game.
local function Lines(env, chat)
	local path, size, flags = chat:GetFont()
	path, size, flags = path or "Fonts\\ARIALN.TTF", size or 14, flags or ""
	local _, _, screenWidth, screenHeight = Scene.Rect(env, chat)
	local toOwn = 768 / 1080 / chat:GetEffectiveScale()
	local width = (screenWidth or 300 * 1080 / 768) * toOwn
	local height = (screenHeight or 120 * 1080 / 768) * toOwn
	local spacing = chat:GetSpacing()
	local lineHeight = size * 1.2 + (type(spacing) == "number" and spacing or 0)
	local rows = {}
	for _, entry in ipairs(C.Entries(chat)) do
		local row, rowWidth = "", 0
		local space = Scene.TextWidth(" ", size, path)
		for word in tostring(entry[1]):gmatch("%S+") do
			local w = Scene.TextWidth(plain(word), size, path)
			if row ~= "" and rowWidth + space + w > width then
				rows[#rows + 1] = { row, entry }
				row, rowWidth = "", 0
			end
			row = row == "" and word or (row .. " " .. word)
			rowWidth = rowWidth + (rowWidth > 0 and space or 0) + w
		end
		rows[#rows + 1] = { row, entry }
	end
	local y = 0
	for i = #rows, 1, -1 do
		if y + lineHeight > height then
			break
		end
		local row, entry = rows[i][1], rows[i][2]
		local text = chat:CreateFontString(nil, "ARTWORK")
		text:SetFont(path, size, flags)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
		text:SetPoint("BOTTOMLEFT", chat, "BOTTOMLEFT", 0, y)
		text:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 0, y)
		text:SetHeight(lineHeight)
		text:SetTextColor(entry[2] or 1, entry[3] or 1, entry[4] or 1)
		text:SetText(row)
		y = y + lineHeight
	end
end

local function say(env, chat, list)
	for _, line in ipairs(list) do
		if line[1] == "CHAT_MSG_CHANNEL" then
			env._now = env._now + 60
			C.Say(env, chat, line[1], line[2], line[3])
		else
			local color = line[1] == "CHAT_MSG_COMBAT_XP_GAIN" and EXPERIENCE or LOOT
			chat:AddMessage(line[2], color[1], color[2], color[3], 7, 1, 1, line[1])
		end
	end
end

return Common.Run(function()
	local env, K, ns = C.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = Gallery.Saved({ Chat = { tabStyle = "filled" } }),
		install = { frames = #TABS },
		setup = function(env)
			Gallery.Setup(env)
			env._now = os.time({ year = 2026, month = 11, day = 7, hour = 14, min = 31, sec = 0 })
			local dock = env.GENERAL_CHAT_DOCK
			for id, name in ipairs(TABS) do
				local frame = env["ChatFrame" .. id]
				env.FCF_SetWindowName(frame, name)
				if not frame.isDocked then
					frame.isDocked = 1
					table.insert(dock.DOCKED_CHAT_FRAMES, frame)
				end
			end
		end,
	})
	if not K.Modules.IsRunning("Chat") then
		C.Enable(env, K)
	end
	local chat = env.ChatFrame1
	say(env, chat, LINES)
	-- The trade window is undocked: the module gives it its own glass (Frames.lua:287).
	local trade = env.ChatFrame4
	local dock = env.GENERAL_CHAT_DOCK
	for i, frame in ipairs(dock.DOCKED_CHAT_FRAMES) do
		if frame == trade then
			table.remove(dock.DOCKED_CHAT_FRAMES, i)
		end
	end
	env.FCF_UnDockFrame(trade)
	trade:ClearAllPoints()
	trade:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", UNDOCKED.x, -UNDOCKED.y)
	trade:SetSize(UNDOCKED.width, UNDOCKED.height)
	say(env, trade, TRADE)
	env.RunTimers()
	C.W.Settle(env)
	C.Dock(env, Scene.TextWidth)
	env.RunTimers()
	C.W.Settle(env)
	Lines(env, chat)
	Lines(env, trade)

	-- The undocked window's edit box, where Blizzard's FloatingChatFrame anchors it: under the window, its width.
	-- The general window sits at the screen's bottom edge, where its box would leave the screen.
	local glass = K.Skin.Parts(trade).backdrop
	assert(glass, "the undocked window has its glass")
	local box = trade.editBox
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", glass, "BOTTOMLEFT", 0, -EDIT_GAP)
	box:SetPoint("TOPRIGHT", glass, "BOTTOMRIGHT", 0, -EDIT_GAP)
	box:SetHeight(EDIT_HEIGHT)
	-- Blizzard's UpdateHeader (ChatFrameEditBox.lua) insets the text by 15 plus the header and 13 at the right.
	box:SetTextInsets(15, 13, 0, 0)
	box:SetText("/s Anyone for the croc hunt?")
	-- The stub's SetFocus does not make HasFocus answer; the module hides an unfocused box, so the scene answers for the game.
	box.HasFocus = function()
		return true
	end
	box:SetFocus()
	local gained = box:GetScript("OnEditFocusGained")
	if gained then
		gained(box)
	end

	-- The copy window, open on the general window's lines.
	assert(ns.Copy.Open(chat), "the copy window opens")
	env.RunTimers()
	C.W.Settle(env)
	local copy = ns.Copy.Window()
	copy:ClearAllPoints()
	copy:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 620, -80)

	-- The preview on a plain frame, as the settings window shows it.
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(320, 240)
	parent:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 620, -500)
	local preview = K.Options.Preview("Chat")(parent)
	preview:Refresh()
	env.RunTimers()
	C.W.Settle(env)

	local frames = Gallery.Frames()
	local tabs = {}
	for id = 1, 3 do
		tabs[id] = env["ChatFrame" .. id .. "Tab"]
	end
	frames:Add(env, dock, {
		name = "chat_tabs_filled", title = "Chat tabs, filled style", grade = "button", reference = "chat",
		caption = "The chat panel's tab strip with tabStyle = filled: the selected GENERAL tab on a buttonFill tile (Frames.lua:174) with its edge in the accent, the other tabs plain upper-case text on the panel glass.",
		match = "The tile is the mockup's button body with a one-border line; the mockup's selected tab is underlined in the class colour instead, which is the default style.",
		rect = Gallery.Union(env, tabs),
	})
	frames:Add(env, box, {
		name = "chat_editbox", title = "Chat edit box", grade = "button", reference = "datastrip",
		caption = "The Trade window's edit box skinned by Skin.EditBox (Frames.lua:254) while the player types: Blizzard's art stripped, the kit's input backdrop with its hairline lit in the accent while the box has focus.",
		match = "A one-border line as the mockup's data strip pill, but the body is Core/Skin.lua's raised tone, not the button body #101214: Skin.EditBox is the skins wave's, outside this module.",
		pad = 6,
	})
	frames:Add(env, glass, {
		name = "chat_undocked", title = "Undocked chat window", grade = "panel", reference = "chat",
		caption = "An undocked chat window (Trade) on its own glass from Skin.Backdrop (Frames.lua:287): the panel grade at the chat opacity, reaching past the window for the tab strip above and a margin below.",
		match = "Fill, two-line edge and shadow as the mockup's chat glass, at the 8-unit panel chamfer rather than the chat panel's 12.",
	})
	frames:Add(env, copy, {
		name = "chat_copy", title = "Copy chat window", grade = "window", reference = "chat",
		caption = "Copy.lua's window open on the general window's lines: a titled Widgets.Panel on the window grade, the plain-text log in a read-only TextArea on the button body, the Ctrl+C hint and the Select all button.",
		match = "Window grade: the mockup's chat glass fill, two-line edge, 12-unit chamfer and drop shadow; the text area inside is one step darker on the button body.",
	})
	frames:Add(env, parent, {
		name = "chat_preview", title = "Chat preview", grade = "window", reference = "chat",
		caption = "Preview.lua in the settings window: a Widgets.Panel glass with three tabs, the selected one on a buttonFill tile (Preview.lua:86) in the filled style, the divider and four sample lines in the chat font.",
		match = "Glass as the mockup's chat panel (window grade); the tab tile is the button body with the accent edge.",
	})

	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = "chat lines are laid out by the scene; the game's ScrollingMessageFrame wraps and spaces them itself"
	scene.log[#scene.log + 1] = "the edit box is anchored by the scene under its window, as FloatingChatFrame anchors it"
	return frames:Finish(scene, env, K, "gallery chat")
end)
