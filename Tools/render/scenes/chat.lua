-- chat.lua: the chat panel in the owner's mockup's state: four tabs on Blizzard's dock with GENERAL selected, five
-- lines in the general window, and the plus glyph at the strip's right end, at the owner's density.
--
--   Tools/render/shoot.sh chat
--
-- The tabs are Blizzard's tab buttons as chat_env.lua builds them from ChatTabArtTemplate, laid out on the dock by
-- C.Dock the way FCFDock_UpdateTabs does, then skinned by the module. The lines are laid out by the scene, as the
-- HUD scene does, because the stub ScrollingMessageFrame draws nothing.
local Common = dofile("Tools/render/scenes/_common.lua")
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
local LOOT = { 0, 0.67, 0 }
local EXPERIENCE = { 0.44, 0.44, 1 }

local function saved()
	return {
		version = 2,
		profiles = { Default = { Chat = { enabled = true } } },
		characters = {},
		layouts = {},
		account = { setupSeen = true },
		devlog = {},
	}
end

local function plain(word)
	return (word:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""))
end

-- Scene.TextWidth measures a kit font by its real glyph advances when it is given the font's path, so a row
-- wraps where the game wraps it.
local WIDTH_SLACK = 1

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
			if row ~= "" and rowWidth + space + w > width * WIDTH_SLACK then
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

return Common.Run(function()
	local env, K = C.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved(),
		install = { frames = #TABS },
		setup = function(env)
			Common.ForceScreen(env)
			env.RAID_CLASS_COLORS.WARRIOR = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3] }
			env.UnitClass = function()
				return "Warrior", "WARRIOR", 1
			end
			env._now = os.time({ year = 2026, month = 11, day = 7, hour = 14, min = 31, sec = 0 })
		end,
	})
	local dock = env.GENERAL_CHAT_DOCK
	for id, name in ipairs(TABS) do
		local frame = env["ChatFrame" .. id]
		env.FCF_SetWindowName(frame, name)
		if not frame.isDocked then
			frame.isDocked = 1
			table.insert(dock.DOCKED_CHAT_FRAMES, frame)
		end
	end
	if not K.Modules.IsRunning("Chat") then
		C.Enable(env, K)
	end
	local chat = env.ChatFrame1
	local stamp = env._cvars.showTimestamps
	local function stamped(text)
		if type(stamp) == "string" and stamp ~= "none" then
			return os.date(stamp, env.time()) .. text
		end
		return text
	end
	for _, line in ipairs(LINES) do
		if line[1] == "CHAT_MSG_CHANNEL" then
			env._now = env._now + 60
			C.Say(env, chat, line[1], line[2], line[3])
		else
			local color = line[1] == "CHAT_MSG_COMBAT_XP_GAIN" and EXPERIENCE or LOOT
			chat:AddMessage(stamped(line[2]), color[1], color[2], color[3], 7, 1, 1, line[1])
		end
	end
	env.RunTimers()
	C.W.Settle(env)
	C.Dock(env, Scene.TextWidth)
	env.RunTimers()
	C.W.Settle(env)
	Lines(env, chat)
	local scene = Scene.Build(env)
	scene.log[#scene.log + 1] = "chat lines are laid out by the scene; the game's ScrollingMessageFrame wraps and spaces them itself"
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
	return scene
end)
