-- Communities.lua: the guild and communities window skin: the window, its side tabs, dropdowns, community and member lists, chat and buttons on glass.
local _, ns = ...

local K = KstyleUI
local Skin, L = K.Skin, K.L
local Style, Parts, Skins, Kit = ns.Style, ns.Parts, ns.Skins, ns.PartC

local KEY = "communities"
local TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }
local DROPDOWNS = { "StreamDropdown", "GuildMemberListDropdown", "CommunityMemberListDropdown", "CommunitiesListDropdown" }
local BUTTONS = {
	"InviteButton", "GuildLogButton", "CommunitiesControlFrame.GuildControlButton",
	"CommunitiesControlFrame.GuildRecruitmentButton", "CommunitiesControlFrame.CommunitiesSettingsButton",
}
local INSETS = { "CommunitiesList.InsetFrame", "MemberList.InsetFrame", "Chat.InsetFrame" }
local ART_FRAMES = { "PortraitOverlay", "CommunitiesList.FilligreeOverlay", "GuildBenefitsFrame", "GuildDetailsFrame", "MemberList.ColumnDisplay" }
local ENTRY_ART = { "Background", "IconRing" }
local MEMBER_TEXTS = { "Level", "Zone", "Rank", "Note", "GuildInfo" }

local rows = setmetatable({}, { __mode = "k" })

local function Entry(row)
	if not rows[row] then
		rows[row] = true
		for _, key in ipairs(ENTRY_ART) do
			Parts.Hush(row[key])
		end
		Kit.Wash(row.Selection)
	end
	if row.Name then
		Style.Text(row.Name, "body")
	end
end

local function Member(row)
	if not rows[row] then
		rows[row] = true
		Kit.Highlight(row)
	end
	local name = type(row.NameFrame) == "table" and row.NameFrame.Name
	if name then
		Style.Text(name, "body")
	end
	for _, key in ipairs(MEMBER_TEXTS) do
		if row[key] then
			Style.Text(row[key], "body")
		end
	end
end

local function List(list, fn)
	if type(list) ~= "table" then
		return
	end
	if type(list.ScrollBar) == "table" then
		Kit.ScrollBar(list.ScrollBar)
	end
	if fn and type(list.ScrollBox) == "table" then
		Parts.EachRow(list.ScrollBox, fn)
	end
end

local function SizeButtons(frame)
	local maxMin = frame.MaximizeMinimizeFrame
	if type(maxMin) ~= "table" then
		return
	end
	Parts.Glyph(maxMin.MaximizeButton, "glyphChevron", { flip = true })
	Parts.Glyph(maxMin.MinimizeButton, "glyphChevron")
end

local function Apply()
	local frame = Kit.Frame(KEY, "CommunitiesFrame")
	if not frame then
		return
	end
	Kit.Window(frame, { tabs = false })
	SizeButtons(frame)
	local tabs = {}
	Kit.Each(KEY, frame, TABS, function(tab)
		Parts.SideTab(tab)
		tabs[#tabs + 1] = tab
	end)
	Kit.Dock(frame, tabs)
	Kit.Each(KEY, frame, DROPDOWNS, Parts.Dropdown)
	Kit.Each(KEY, frame, BUTTONS, Kit.Button)
	Kit.Each(KEY, frame, INSETS, function(inset)
		Skin.Strip(inset, { children = { "NineSlice", "Bg" } })
	end)
	Kit.Each(KEY, frame, ART_FRAMES, Skin.Strip)
	local list = frame.CommunitiesList
	if type(list) == "table" then
		Skin.Strip(list)
		List(list, Entry)
	end
	local members = frame.MemberList
	if type(members) == "table" then
		List(members, Member)
		if type(members.ShowOfflineButton) == "table" then
			Kit.CheckBox(members.ShowOfflineButton)
			Kit.Texts(members.ShowOfflineButton, "body")
		end
		if members.MemberCount then
			Style.Text(members.MemberCount, "caption", "text")
		end
	end
	List(frame.Chat)
	Kit.EditBox(frame.ChatEditBox)
end

Skins.Add({
	key = KEY,
	label = L["Guild and communities"],
	help = L["Restyles the guild and communities window: lists, chat, tabs and buttons."],
	addon = "Blizzard_Communities",
	frame = "CommunitiesFrame",
	Apply = Apply,
})
