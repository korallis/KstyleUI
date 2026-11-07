-- Friends.lua: the social window skin: the friends list and its tabs, status and broadcast controls, the ignore list, and the raid and quick join tabs.
local _, ns = ...

local K = KstyleUI
local Skin, L = K.Skin, K.L
local Style, Parts, Skins, Kit = ns.Style, ns.Parts, ns.Skins, ns.PartC

local KEY = "friends"
local LINE_ALPHA = 0.5
local LIST_BUTTONS = { "FriendsFrameAddFriendButton", "FriendsFrameSendMessageButton", "RaidFrameConvertToRaidButton", "RaidFrameRaidInfoButton" }
local BROADCAST_BUTTONS = { "UpdateButton", "CancelButton" }
local INVITE_HEADER_KEEP = { "RightArrow", "DownArrow" }

local rows = setmetatable({}, { __mode = "k" })

local function Keep(frame, keys)
	local keep = {}
	for _, key in ipairs(keys) do
		if Parts.IsTexture(frame[key]) then
			keep[frame[key]] = true
		end
	end
	return keep
end

local function Friend(row, first)
	if first then
		Kit.Highlight(row)
	end
	Style.Text(row.name, "body")
	if row.info then
		Style.Text(row.info, "body")
	end
end

local function Invite(row, first)
	if first then
		local decline = row.DeclineButton
		if type(decline) == "table" then
			Skin.Strip(decline, { keep = Keep(decline, { "Icon" }) })
			Kit.Button(decline)
		end
		if type(row.AcceptButton) == "table" then
			Kit.Button(row.AcceptButton)
		end
	end
	if row.Name then
		Style.Text(row.Name, "body")
	end
end

local function InviteHeader(row, first)
	if first then
		Skin.Strip(row, { keep = Keep(row, INVITE_HEADER_KEEP) })
		Skin.Backdrop(row, { shape = "tile", fill = "raised", shadow = false })
	end
	local text = type(row.GetFontString) == "function" and row:GetFontString()
	if text then
		Style.Text(text, "body", "textEmphasis")
	end
end

local function Header(row, first)
	if first then
		Parts.AccentLine(row, { alpha = LINE_ALPHA })
	end
	Style.Text(row.Title, "caption", "text")
end

local function Divider(row, first)
	if first then
		Skin.Strip(row)
		Parts.AccentLine(row, { anchor = row, alpha = LINE_ALPHA })
	end
end

local function Ignored(row, first)
	if first then
		Kit.Highlight(row)
	end
	Style.Text(row.name, "body")
end

local function Row(row)
	local first = not rows[row]
	rows[row] = true
	if row.status and row.name then
		Friend(row, first)
	elseif row.AcceptButton then
		Invite(row, first)
	elseif row.RightArrow or row.DownArrow then
		InviteHeader(row, first)
	elseif row.Title then
		Header(row, first)
	elseif row.name then
		Ignored(row, first)
	else
		Divider(row, first)
	end
end

local function List(list)
	if type(list.ScrollBar) == "table" then
		Kit.ScrollBar(list.ScrollBar)
	end
	if type(list.ScrollBox) == "table" then
		Parts.EachRow(list.ScrollBox, Row)
	end
end

local function Broadcast(bnet)
	Skin.Strip(bnet)
	Skin.Backdrop(bnet, { shape = "tile", fill = "raised", shadow = false })
	if bnet.Tag then
		Style.Text(bnet.Tag, "body")
	end
	if bnet.UnavailableLabel then
		Style.Text(bnet.UnavailableLabel, "body")
	end
	local broadcast = bnet.BroadcastFrame
	if type(broadcast) == "table" then
		Skin.Strip(broadcast, { children = { "Border", "Border.NineSlice" } })
		Skin.Backdrop(broadcast, { shape = "panel", fill = "surface", shadow = true })
		Kit.Texts(broadcast, "heading", "textEmphasis")
		Kit.EditBox(broadcast.EditBox)
		Kit.Each(KEY, broadcast, BROADCAST_BUTTONS, Kit.Button)
	end
	local unavailable = bnet.UnavailableInfoFrame
	if type(unavailable) == "table" then
		Skin.Strip(unavailable, { children = { "NineSlice" } })
		Skin.Backdrop(unavailable, { shape = "panel", fill = "surface", shadow = true })
	end
end

local function TabHeader(frame)
	local header = Kit.Child(KEY, frame, "FriendsTabHeader")
	if not header then
		return
	end
	Kit.TabSystem(header.TabSystem)
	if type(header.StatusDropdown) == "table" then
		Parts.Dropdown(header.StatusDropdown)
	end
	if type(header.BattlenetFrame) == "table" then
		Broadcast(header.BattlenetFrame)
	end
end

local function Raid()
	local check = _G.RaidFrameAllAssistCheckButton
	if type(check) == "table" then
		Kit.CheckBox(check)
		Kit.Texts(check, "body")
	end
	local info = _G.RaidInfoFrame
	if type(info) == "table" then
		Skin.Strip(info, { children = { "Border", "Border.NineSlice", "Header" } })
		Skin.Backdrop(info, { shape = "panel", fill = "surface", shadow = true })
		local close = _G.RaidInfoCloseButton
		if type(close) == "table" then
			Skin.CloseButton(close)
		end
		if type(info.ScrollBar) == "table" then
			Kit.ScrollBar(info.ScrollBar)
		end
	end
end

local function Apply()
	local frame = Kit.Frame(KEY, "FriendsFrame")
	if not frame then
		return
	end
	Kit.Window(frame)
	local title = _G.FriendsFrameTitleText
	if type(title) == "table" then
		Style.Text(title, "heading", "textEmphasis")
	end
	TabHeader(frame)
	local list = Kit.Frame(KEY, "FriendsListFrame")
	if list then
		List(list)
	end
	for _, name in ipairs(LIST_BUTTONS) do
		local button = _G[name]
		if type(button) == "table" then
			Kit.Button(button)
		end
	end
	local ignore = frame.IgnoreListWindow
	if type(ignore) == "table" then
		Kit.Window(ignore)
		if type(ignore.UnignorePlayerButton) == "table" then
			Kit.Button(ignore.UnignorePlayerButton)
		end
		List(ignore)
	end
	Raid()
	local quick = _G.QuickJoinFrame
	if type(quick) == "table" then
		if type(quick.ScrollBar) == "table" then
			Kit.ScrollBar(quick.ScrollBar)
		end
		if type(quick.JoinQueueButton) == "table" then
			Kit.Button(quick.JoinQueueButton)
		end
	end
end

Skins.Add({
	key = KEY,
	label = L["Friends list"],
	help = L["Restyles the friends, ignore, raid and quick join tabs."],
	addon = "Blizzard_FriendsFrame",
	frame = "FriendsFrame",
	Apply = Apply,
})
