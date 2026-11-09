-- skins_windows.lua: stand-in Blizzard windows for every skin KstyleUI_Skins restyles, built with the fields, sizes
-- and anchors Forever's XML and Lua give them, in a representative state, for the render gallery and the tests.
--
--   local Windows = dofile("Tools/regression/skins_windows.lua")
--   local B = S.Blizzard(env)
--   local frame, parts = Windows.Build("mail", env, B)   -- the window, hidden, and its parts
--   Windows.LIST                                          -- every window in gallery order, with its skin's addon
--
-- Every builder returns the window frame and a parts table: parts.show lists the frames to show (default the
-- window), parts.bounds the frames the gallery crop covers (default the window), parts.portraits the textures the
-- game paints with SetPortraitTexture (none by default). Sizes come from Forever's
-- source (Interface/AddOns in Gethe/wow-ui-source, branch forever): CharacterFrameConstants.lua:4,
-- Blizzard_PlayerSpellsFrame.lua:8, Blizzard_WorldMap.lua:104, QuestMapFrame.xml:427, Blizzard_LFGVanilla_ParentFrame.xml:23,
-- Blizzard_LFGVanilla_Browse.xml:125, MailFrame.xml:12, MerchantFrame.xml:4 and :89, Blizzard_ProfessionsFrame.xml:5,
-- AddonList.xml:121, CommunitiesFrame.xml:304, FriendsFrame.xml:391, Blizzard_LegacySystem.xml:5, LootFrame.xml:117,
-- GroupLootFrame.xml:292, GameDialog.xml:52, ReadyCheck.xml:16.
local S = dofile("Tools/regression/skins_env.lua")

local Windows = { S = S }

-- Set B spell icons, as stand-ins for every icon a window shows.
local ICONS = {
	132282, 132340, 132337, 132155, 136105, 132333, 132277, 135358, 132223, 132316, 132338, 132369,
	132355, 132110, 132363, 136080, 132366, 136009, 132307, 132938, 132353, 132343, 132342, 135726,
	136224, 132357, 132336, 132306,
}
Windows.ICONS = ICONS

local TITLE_HEIGHT = 24
local CLOSE = 24
local BUTTON_HEIGHT = 22
local MODE_TAB = 40
-- The character window's mode tabs (Camelot/CharacterFrame.lua:58 CHARACTER_MODE_TAB_ICONS): the first wears the
-- player's portrait, the PvP tab the faction's honour icon.
local MODE_TAB_ICONS = {
	false,
	"Interface\\ICONS\\INV_SideTab_Reputation2_c60",
	"Interface\\ICONS\\Ability_Racial_JackofAllTrades",
	"Interface\\ICONS\\INV_SideTab_Honor_Horde_c60",
	"Interface\\ICONS\\INV_SideTab_Currency_c60",
	"Interface\\ICONS\\INV_SideTab_Stats_c60",
}
local ROW_HEIGHT = 20

-- Layout ----------------------------------------------------------------------------------------------

-- Anchor(frame, rel, point, x, y) puts frame's point on the same point of rel, offset x, y;
-- Anchor(frame, rel, point, relPoint, x, y) puts it on relPoint of rel.
local function Anchor(frame, rel, point, a, b, c)
	frame:ClearAllPoints()
	if type(a) == "string" then
		frame:SetPoint(point, rel, a, b or 0, c or 0)
	else
		frame:SetPoint(point, rel, point, a or 0, b or 0)
	end
end

local function At(frame, parent, x, y, w, h)
	Anchor(frame, parent, "TOPLEFT", x, -y)
	if w then
		frame:SetSize(w, h)
	end
end

local function Fill(frame, parent, left, top, right, bottom)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", left or 0, -(top or 0))
	frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(right or 0), bottom or 0)
end

local function Text(fs, value, point, rel, relPoint, x, y)
	fs:ClearAllPoints()
	fs:SetPoint(point or "CENTER", rel or fs:GetParent(), relPoint or point or "CENTER", x or 0, y or 0)
	fs:SetText(value)
	fs:Show()
	return fs
end

-- Colour(B, parent, layer, r, g, b, a) -> a Blizzard texture that stands in as a flat colour (a model, a status dot).
local function Colour(B, parent, layer, r, g, b, a)
	local t = B.texture(parent, layer)
	t:SetColorTexture(r, g, b, a or 1)
	return t
end

-- Pieces ----------------------------------------------------------------------------------------------

local function Icon(B, parent, id, layer)
	local icon = B.texture(parent, layer or "ARTWORK")
	icon:SetTexture(id)
	icon:SetAllPoints(parent)
	return icon
end

-- Window(B, name, parent, w, h, title, opts) -> a PortraitFrameTemplate or ButtonFrameTemplate window
-- (SharedUIPanelTemplates.xml:566 and :711): NineSlice, Bg, portrait, title, close button and, with opts.inset,
-- the inset from opts.inset.top to opts.inset.bottom units of the window's bottom.
local function Window(B, name, parent, w, h, title, opts)
	opts = opts or {}
	local f = B.frame("Frame", parent, name)
	f:SetSize(w, h)
	f.NineSlice = B.frame("Frame", f)
	f.NineSlice:SetAllPoints(f)
	B.texture(f.NineSlice)
	f.Bg = B.texture(f, "BACKGROUND")
	f.Bg:SetAllPoints(f)
	f.TitleContainer = B.frame("Frame", f)
	At(f.TitleContainer, f, 0, 0, w, TITLE_HEIGHT)
	f.TitleContainer.TitleText = B.text(f.TitleContainer)
	Text(f.TitleContainer.TitleText, title, "CENTER", f.TitleContainer)
	f.PortraitContainer = B.frame("Frame", f)
	At(f.PortraitContainer, f, -6, -6, 60, 60)
	f.PortraitContainer.portrait = B.texture(f.PortraitContainer)
	f.CloseButton = B.frame("Button", f)
	Anchor(f.CloseButton, f, "TOPRIGHT", -4, -2)
	f.CloseButton:SetSize(CLOSE, CLOSE)
	B.texture(f.CloseButton)
	if opts.inset then
		f.Inset = B.frame("Frame", f)
		Fill(f.Inset, f, 4, opts.inset.top or 60, 6, opts.inset.bottom or 26)
		f.Inset.NineSlice = B.frame("Frame", f.Inset)
		f.Inset.NineSlice:SetAllPoints(f.Inset)
		B.texture(f.Inset.NineSlice)
		f.Inset.Bg = B.texture(f.Inset, "BACKGROUND")
		f.Inset.Bg:SetAllPoints(f.Inset)
	end
	f:Hide()
	return f
end

local function Button(B, parent, label, w, h)
	local button = B.frame("Button", parent)
	button:SetSize(w or 80, h or BUTTON_HEIGHT)
	B.texture(button, "BACKGROUND")
	local text = B.text(button)
	Text(text, label, "CENTER", button)
	button:SetFontString(text)
	return button
end

local function Item(B, parent, id, size, name)
	local button = B.frame("Button", parent, name)
	button:SetSize(size or 37, size or 37)
	button.slot = B.texture(button, "BACKGROUND")
	button.icon = Icon(B, button, id, "BORDER")
	button.IconBorder = B.texture(button, "OVERLAY")
	return button
end

local function Dropdown(B, parent, label, w)
	local drop = B.frame("DropdownButton", parent)
	drop:SetSize(w or 140, BUTTON_HEIGHT)
	drop.Background = B.texture(drop, "BACKGROUND")
	drop.Arrow = Colour(B, drop, "OVERLAY", 0.67, 0.67, 0.67)
	Anchor(drop.Arrow, drop, "RIGHT", -6, 0)
	drop.Arrow:SetSize(8, 5)
	drop.Text = B.text(drop)
	Text(drop.Text, label, "LEFT", drop, "LEFT", 8, 0)
	return drop
end

local function ScrollBar(B, parent)
	local bar = B.frame("EventFrame", parent)
	bar:SetWidth(10)
	bar.Track = B.frame("Frame", bar)
	bar.Track:SetAllPoints(bar)
	B.texture(bar.Track)
	bar.Track.Thumb = B.frame("Button", bar.Track)
	At(bar.Track.Thumb, bar.Track, 0, 4, 10, 60)
	bar.Thumb = bar.Track.Thumb
	return bar
end

local function EditBox(B, parent, text, w, h, name)
	local box = B.frame("EditBox", parent, name)
	box:SetSize(w or 160, h or BUTTON_HEIGHT)
	B.texture(box)
	local value = B.text(box)
	Text(value, text, "LEFT", box, "LEFT", 6, 0)
	return box
end

local function Check(B, parent, label, name)
	local check = B.frame("CheckButton", parent, name)
	check:SetSize(20, 20)
	B.texture(check)
	local text = B.text(check)
	Text(text, label, "LEFT", check, "RIGHT", 4, 0)
	check.Label = text
	return check
end

local function SideTab(B, parent, id)
	local tab = B.frame("Frame", parent)
	tab:SetSize(32, 32)
	tab.Background = B.texture(tab, "BACKGROUND")
	tab.Icon = Icon(B, tab, id)
	tab.SelectedTexture = B.texture(tab, "OVERLAY")
	function tab:SetChecked(checked)
		self.SelectedTexture:SetShown(checked)
	end
	return tab
end

-- Tab(B, parent, label) -> a bottom tab for PanelTemplates: a Button with Text that GetFontString returns.
local function Tab(B, parent, label, name)
	local tab = B.frame("Button", parent, name)
	tab:SetSize(80, BUTTON_HEIGHT)
	B.texture(tab)
	tab.Text = B.text(tab)
	Text(tab.Text, label, "CENTER", tab)
	tab:SetFontString(tab.Text)
	return tab
end

local function StatusBar(B, parent, w, h, value)
	local bar = B.frame("StatusBar", parent)
	bar:SetSize(w, h)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	B.add(bar:GetStatusBarTexture())
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(value or 0.5)
	bar:SetStatusBarColor(0.26, 0.42, 1)
	B.texture(bar, "BACKGROUND")
	return bar
end

local function ScrollBox(B, parent)
	local box = S.ScrollBox(B, parent)
	box.ScrollTarget:SetAllPoints(box)
	return box
end

local function Row(B, box, h)
	local row = B.frame("Button", box.ScrollTarget)
	row:SetHeight(h or ROW_HEIGHT)
	return row
end

-- Stack(rows, parent, top, gap) anchors each row under the one before, across the parent.
local function Stack(rows, parent, top, gap)
	local y = top or 0
	for _, row in ipairs(rows) do
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
		row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
		y = y + row:GetHeight() + (gap or 0)
	end
	return y
end

-- Windows ----------------------------------------------------------------------------------------------

Windows.LIST = {
	{ key = "character", skins = { "character" }, title = "Character sheet", frame = "CharacterFrame" },
	{ key = "reputation", skins = { "character" }, title = "Character sheet: reputation", frame = "CharacterFrame" },
	{ key = "spellbook", skins = { "spellbook", "talents" }, title = "Spellbook", frame = "PlayerSpellsFrame", addon = "Blizzard_PlayerSpells" },
	{ key = "talents", skins = { "spellbook", "talents" }, title = "Talents", frame = "PlayerSpellsFrame", addon = "Blizzard_PlayerSpells" },
	{ key = "worldmap", skins = { "worldMap", "questLog" }, title = "World map and quest log", frame = "WorldMapFrame", addon = "Blizzard_WorldMap" },
	{ key = "gamemenu", skins = { "gameMenu" }, title = "Game menu", frame = "GameMenuFrame", addon = "Blizzard_GameMenu" },
	{ key = "groupfinder", skins = { "groupFinder" }, title = "Group finder", frame = "LFGParentFrame", addon = "Blizzard_GroupFinder_VanillaStyle" },
	{ key = "mail", skins = { "mail" }, title = "Mail and open letter", frame = "MailFrame", addon = "Blizzard_MailFrame" },
	{ key = "merchant", skins = { "merchant" }, title = "Merchant", frame = "MerchantFrame", addon = "Blizzard_UIPanels_Game" },
	{ key = "professions", skins = { "professions" }, title = "Professions", frame = "ProfessionsFrame", addon = "Blizzard_Professions" },
	{ key = "trainer", skins = { "trainer" }, title = "Trainer", frame = "ClassTrainerFrame", addon = "Blizzard_TrainerUI" },
	{ key = "addonlist", skins = { "addonList" }, title = "Addon list", frame = "AddonList", addon = "Blizzard_AddOnList" },
	{ key = "communities", skins = { "communities" }, title = "Guild and communities", frame = "CommunitiesFrame", addon = "Blizzard_Communities" },
	{ key = "friends", skins = { "friends" }, title = "Friends list", frame = "FriendsFrame", addon = "Blizzard_FriendsFrame" },
	{ key = "legacy", skins = { "legacy" }, title = "Legacy", frame = "LegacySystemFrame", addon = "Blizzard_LegacySystem" },
	{ key = "loot", skins = { "loot" }, title = "Loot window", frame = "LootFrame" },
	{ key = "lootrolls", skins = { "lootRolls" }, title = "Loot rolls", frame = "GroupLootFrame1" },
	{ key = "popups", skins = { "popups" }, title = "Popup", frame = "StaticPopup1" },
	{ key = "readycheck", skins = { "readyCheck" }, title = "Ready check", frame = "ReadyCheckFrame" },
}

local build = {}

-- The character window (Camelot/CharacterFrame.xml:403, 631 by 484): side mode tabs, the paper doll's slots in two
-- columns beside the model, the level line, and the stats pane on the right.
local function CharacterWindow(env, B, x, y)
	local f = Window(B, "CharacterFrame", nil, 631, 484, "Valerin")
	At(f, env.UIParent, x, y)
	f.LeftPaneHost = B.frame("Frame", f)
	Fill(f.LeftPaneHost, f, 0, TITLE_HEIGHT, 290, 0)
	B.texture(f.LeftPaneHost, "BACKGROUND")
	f.RightPaneHost = B.frame("Frame", f)
	Fill(f.RightPaneHost, f, 341, TITLE_HEIGHT, 0, 0)
	f.RightPaneHost.StoneBg = B.texture(f.RightPaneHost)
	-- The mode tabs hang off the window's right edge (CharacterFrame.xml:568: TOPLEFT at the frame's
	-- TOPRIGHT, y -30), stacked 2 apart as CharacterFrameMixin:UpdateTabLayout stacks them.
	f.ModeTabs = B.frame("Frame", f)
	f.ModeTabs:SetSize(64, 384)
	Anchor(f.ModeTabs, f, "TOPLEFT", "TOPRIGHT", 0, -30)
	f.ModeTabs.Tabs = {}
	f.portraits = {}
	for i, icon in ipairs(MODE_TAB_ICONS) do
		local tab = SideTab(B, f.ModeTabs, icon or nil)
		tab:SetSize(MODE_TAB, MODE_TAB)
		tab:SetChecked(i == 1)
		f.ModeTabs.Tabs[i] = tab
		if not icon then
			f.portraits[#f.portraits + 1] = tab.Icon
		end
	end
	function f.UpdateTabLayout()
		local previous
		for _, tab in ipairs(f.ModeTabs.Tabs) do
			if tab:IsShown() then
				if previous then
					Anchor(tab, previous, "TOPLEFT", "BOTTOMLEFT", 0, -2)
				else
					Anchor(tab, f.ModeTabs, "TOPLEFT", 0, 0)
				end
				previous = tab
			end
		end
	end
	f.UpdateTabLayout()
	f.RightPaneToggleButton = B.frame("Button", f)
	Anchor(f.RightPaneToggleButton, f, "TOPRIGHT", -30, -2)
	f.RightPaneToggleButton:SetSize(CLOSE, CLOSE)
	B.texture(f.RightPaneToggleButton)
	function f.IsRightPaneCollapsed()
		return false
	end
	function f.UpdateRightPaneToggleButton() end
	return f
end

function build.character(env, B)
	local f = CharacterWindow(env, B, 120, 120)
	local qualities = { 4, 3, 2, 2, 4, 1, 1, 3, 2, 2, 3, 2, 4, 3, 2, 2, 3, 2 }
	env.GetInventoryItemQuality = function(_, id)
		return qualities[id]
	end
	env.PaperDollItemSlotButton_Update = function() end
	local slots = {
		"CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot", "CharacterChestSlot",
		"CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot", "CharacterHandsSlot", "CharacterWaistSlot",
		"CharacterLegsSlot", "CharacterFeetSlot", "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot",
		"CharacterTrinket1Slot", "CharacterMainHandSlot", "CharacterSecondaryHandSlot",
	}
	local doll = B.frame("Frame", f, "PaperDollFrame")
	doll:SetAllPoints(f.LeftPaneHost)
	for i, name in ipairs(slots) do
		local slot = Item(B, doll, ICONS[i], 37, name)
		slot:SetID(i)
		slot.NormalTexture = B.texture(slot)
		slot.BorderFrame = B.frame("Frame", slot)
		slot.BorderFrame:SetAllPoints(slot)
		B.texture(slot.BorderFrame, "BACKGROUND")
		-- PaperDollFrame.xml:781 and :822: the columns start 24 in from the left pane's left edge and 20 from its
		-- right, 60 under its top, each slot 6 under the one before; the weapons sit in a row under the model.
		if i <= 8 then
			At(slot, doll, 24, 40 + (i - 1) * 43)
		elseif i <= 16 then
			Anchor(slot, doll, "TOPRIGHT", -20, -(40 + (i - 9) * 43))
		else
			At(slot, doll, 128 + (i - 17) * 43, 40 + 8 * 43)
		end
	end
	local scene = B.frame("Frame", doll, "CharacterModelScene")
	Fill(scene, doll, 70, 40, 70, 60)
	Colour(B, scene, "BACKGROUND", 0.09, 0.11, 0.12, 0.6):SetAllPoints(scene)
	doll.TopBackgroundStripHost = B.frame("Frame", doll)
	At(doll.TopBackgroundStripHost, doll, 0, 0, 341, 12)
	B.texture(doll.TopBackgroundStripHost)
	env.CharacterLevelText = Text(B.text(doll), "Level 38 Orc Warrior", "BOTTOM", doll, "BOTTOM", 0, 14)
	for i = 1, 2 do
		local tab = B.frame("CheckButton", f, "PaperDollSidebarTab" .. i)
		tab:SetSize(26, 26)
		Anchor(tab, f.RightPaneHost, "TOPRIGHT", -8 - (i - 1) * 30, -6)
		tab.Icon = Icon(B, tab, ICONS[20 + i], "BACKGROUND")
		B.texture(tab, "BORDER")
		tab:SetChecked(i == 1)
	end
	local stats = B.frame("Frame", f, "CharacterStatsPaneScrollBox")
	Fill(stats, f.RightPaneHost, 8, 40, 8, 8)
	stats.Border = B.texture(stats, "BORDER")
	stats.ScrollBox = ScrollBox(B, stats)
	stats.ScrollBar = ScrollBar(B, stats)
	Anchor(stats.ScrollBar, stats, "TOPRIGHT", 0, 0)
	stats.ScrollBar:SetHeight(380)
	Fill(stats.ScrollBox, stats, 0, 0, 14, 0)
	local rows = {}
	local function Header(title)
		local row = Row(B, stats.ScrollBox, 24)
		row.Background = B.texture(row, "BACKGROUND")
		row.Title = Text(B.text(row), title, "LEFT", row, "LEFT", 4, 0)
		stats.ScrollBox.AddRow(row, { isHeader = true })
		rows[#rows + 1] = row
	end
	local function Stat(label, value)
		local row = Row(B, stats.ScrollBox, 22)
		row.Background = B.texture(row, "BACKGROUND")
		row.Icon = B.texture(row)
		row.Label = Text(B.text(row), label, "LEFT", row, "LEFT", 8, 0)
		row.Value = Text(B.text(row), value, "RIGHT", row, "RIGHT", -8, 0)
		stats.ScrollBox.AddRow(row, {})
		rows[#rows + 1] = row
	end
	Header("Attributes")
	Stat("Strength", "142")
	Stat("Agility", "68")
	Stat("Stamina", "131")
	Stat("Intellect", "24")
	Stat("Spirit", "41")
	Header("Melee")
	Stat("Damage", "188 - 262")
	Stat("Attack Power", "412")
	Stat("Crit Chance", "8.4%")
	Header("Defense")
	Stat("Armor", "1,842")
	Stat("Block", "17%")
	Stack(rows, stats.ScrollBox, 0, 2)
	return f, { bounds = { f, f.ModeTabs.Tabs[6] }, portraits = f.portraits }
end

-- RepBar(B, parent, w) -> a ColoredProgressBarTemplate bar: a background, a masked Fill, a Text.
local function RepBar(B, parent, w, fraction, label)
	local bar = B.frame("Frame", parent)
	bar:SetSize(w, 14)
	bar.FillArea = B.frame("Frame", bar)
	bar.FillArea:SetAllPoints(bar)
	B.texture(bar, "BACKGROUND")
	bar.Fill = B.texture(bar, "BORDER")
	bar.Fill:SetVertexColor(0, 0.6, 0.1)
	bar.Fill:SetWidth(w * fraction)
	bar.Mask = B.add(bar:CreateMaskTexture())
	bar.Fill:AddMaskTexture(bar.Mask)
	bar.Text = Text(B.text(bar), label, "CENTER", bar)
	return bar
end

function build.reputation(env, B)
	local f = CharacterWindow(env, B, 120, 120)
	f.ModeTabs.Tabs[1]:SetChecked(false)
	f.ModeTabs.Tabs[2]:SetChecked(true)
	local rep = B.frame("Frame", f, "ReputationFrame")
	rep:SetAllPoints(f.LeftPaneHost)
	rep.filterDropdown = Dropdown(B, rep, "All factions", 140)
	At(rep.filterDropdown, rep, 12, 10)
	rep.ScrollBar = ScrollBar(B, rep)
	Anchor(rep.ScrollBar, rep, "TOPRIGHT", -6, -40)
	rep.ScrollBar:SetHeight(400)
	rep.ScrollBox = ScrollBox(B, rep)
	Fill(rep.ScrollBox, rep, 10, 40, 22, 8)
	local rows = {}
	local function Header(name)
		local row = Row(B, rep.ScrollBox, 22)
		B.texture(row, "BACKGROUND")
		row.StateIcon = Colour(B, row, "BORDER", 0.67, 0.67, 0.67)
		Anchor(row.StateIcon, row, "LEFT", 4, 0)
		row.StateIcon:SetSize(10, 10)
		row.Name = Text(B.text(row), name, "LEFT", row, "LEFT", 20, 0)
		rep.ScrollBox.AddRow(row, { isHeader = true })
		rows[#rows + 1] = row
	end
	local function Entry(name, fraction, standing, r, g, b)
		local row = Row(B, rep.ScrollBox, 36)
		row.Content = B.frame("Frame", row)
		row.Content:SetAllPoints(row)
		row.Content.Name = Text(B.text(row.Content), name, "TOPLEFT", row.Content, "TOPLEFT", 8, -2)
		row.Content.ReputationBar = RepBar(B, row.Content, 200, fraction, standing)
		row.Content.ReputationBar.Fill:SetVertexColor(r, g, b)
		Anchor(row.Content.ReputationBar, row.Content, "BOTTOMLEFT", 8, 4)
		row.Content.BackgroundHighlight = B.frame("Frame", row.Content)
		row.Content.BackgroundHighlight:SetAllPoints(row.Content)
		B.texture(row.Content.BackgroundHighlight, "BACKGROUND")
		rep.ScrollBox.AddRow(row, {})
		rows[#rows + 1] = row
		return row
	end
	Header("Horde")
	Entry("Orgrimmar", 0.62, "Revered", 0, 0.6, 0.1)
	Entry("Darkspear Trolls", 0.31, "Honored", 0, 0.6, 0.1)
	Entry("Thunder Bluff", 0.8, "Friendly", 0, 0.6, 0.1)
	Header("Other")
	Entry("Steamwheedle Cartel", 0.12, "Neutral", 0.9, 0.7, 0)
	Entry("Ravenholdt", 0.45, "Unfriendly", 0.8, 0.3, 0.2)
	Stack(rows, rep.ScrollBox, 0, 2)
	local detail = B.frame("Frame", rep)
	rep.ReputationDetailFrame = detail
	detail:SetAllPoints(f.RightPaneHost)
	detail.Title = Text(B.text(detail), "Orgrimmar", "TOPLEFT", detail, "TOPLEFT", 16, -16)
	detail.Subtitle = Text(B.text(detail), "Revered  14,200 / 21,000", "TOPLEFT", detail, "TOPLEFT", 16, -40)
	detail.EmptyText = B.text(detail)
	detail.EmptyText:Hide()
	detail.Divider = B.texture(detail, "BORDER")
	At(detail.Divider, detail, 16, 60, 250, 2)
	-- CharacterFrame.xml:352: the description is a ScrollingFontTemplate under the divider, from the pane's left
	-- edge to 14 short of its right, its scroll bar 4 to its right; the font string inside is LEFT-justified.
	detail.Description = B.frame("Frame", detail)
	detail.Description:SetPoint("TOP", detail.Divider, "BOTTOM", 0, -6)
	detail.Description:SetPoint("LEFT", detail, "LEFT", 16, 0)
	detail.Description:SetPoint("RIGHT", detail, "RIGHT", -30, 0)
	detail.Description:SetHeight(120)
	detail.Description.ScrollBox = B.frame("Frame", detail.Description)
	detail.Description.ScrollBox:SetAllPoints(detail.Description)
	detail.Description.ScrollBox.FontStringContainer = B.frame("Frame", detail.Description.ScrollBox)
	detail.Description.ScrollBox.FontStringContainer:SetAllPoints(detail.Description.ScrollBox)
	local description = B.text(detail.Description.ScrollBox.FontStringContainer)
	detail.Description.ScrollBox.FontStringContainer.FontString = description
	description:SetPoint("TOPLEFT", detail.Description.ScrollBox.FontStringContainer, "TOPLEFT", 0, 0)
	description:SetPoint("TOPRIGHT", detail.Description.ScrollBox.FontStringContainer, "TOPRIGHT", 0, 0)
	description:SetHeight(40)
	description:SetText("The capital of the Horde, home of the orcs and their allies. Thrall rules here from Grommash Hold.")
	description:Show()
	detail.DescriptionScrollBar = ScrollBar(B, detail)
	detail.DescriptionScrollBar:SetPoint("TOPLEFT", detail.Description, "TOPRIGHT", 4, -1)
	detail.DescriptionScrollBar:SetPoint("BOTTOMLEFT", detail.Description, "BOTTOMRIGHT", 4, 1)
	detail.StandingBar = RepBar(B, detail, 240, 0.62, "14,200 / 21,000")
	At(detail.StandingBar, detail, 16, 210)
	for i, key in ipairs({ "AtWarCheckbox", "MakeInactiveCheckbox", "WatchFactionCheckbox" }) do
		detail[key] = Check(B, detail, ({ "At war", "Inactive", "Show as experience bar" })[i])
		At(detail[key], detail, 16, 240 + (i - 1) * 28)
	end
	detail.ViewRenownButton = Button(B, detail, "View Renown", 120)
	Anchor(detail.ViewRenownButton, detail, "BOTTOMRIGHT", -16, 16)
	return f, { bounds = { f, f.ModeTabs.Tabs[6] }, portraits = f.portraits }
end

-- Tabs(B, parent, labels, icons) -> a TabSystemTemplate with text tabs or, with icons, Forever's icon-only tabs.
local function TabSystem(B, parent, labels, icons)
	local system = B.frame("Frame", parent)
	system.tabs = {}
	for i, label in ipairs(labels) do
		local tab = B.frame("Button", system)
		B.texture(tab)
		tab.Text = B.text(tab)
		if icons then
			tab:SetSize(36, 36)
			tab.tabIcon = icons[i]
			tab.Icon = Icon(B, tab, icons[i])
			tab.SquareBackground, tab.SquareBackgroundActive = B.texture(tab, "BACKGROUND"), B.texture(tab, "BACKGROUND")
		else
			tab:SetSize(90, BUTTON_HEIGHT)
			Text(tab.Text, label, "CENTER", tab)
			tab:SetFontString(tab.Text)
		end
		function tab.SetTabSelected(self, selected)
			self.isSelected = selected
		end
		tab:SetTabSelected(i == 1)
		system.tabs[i] = tab
	end
	function system.AddTab() end
	return system
end

-- The PlayerSpellsFrame (Camelot/Blizzard_PlayerSpellsFrame.xml:4), at its minimum width (Blizzard_PlayerSpellsFrame.lua:8).
local function SpellsWindow(env, B)
	local f = Window(B, "PlayerSpellsFrame", nil, 760, 600, "Spellbook & Talents")
	At(f, env.UIParent, 160, 120)
	f.MaximizeMinimizeButton = B.frame("Frame", f)
	for i, key in ipairs({ "MaximizeButton", "MinimizeButton" }) do
		local button = B.frame("Button", f.MaximizeMinimizeButton)
		Anchor(button, f, "TOPRIGHT", -4 - CLOSE - 2, -2)
		button:SetSize(CLOSE, CLOSE)
		B.texture(button)
		button:SetShown(i == 2)
		f.MaximizeMinimizeButton[key] = button
	end
	return f
end

function build.spellbook(env, B)
	local f = SpellsWindow(env, B)
	local book = B.frame("Frame", f)
	f.SpellBookFrame = book
	Fill(book, f, 0, TITLE_HEIGHT, 0, 0)
	for _, key in ipairs({ "TopBar", "BookBGLeft", "BookBGRight", "BookCornerFlipbook", "Bookmark" }) do
		book[key] = B.texture(book)
	end
	book.CategoryTabSystem = TabSystem(B, book, { "General", "Arms", "Fury", "Protection" }, { ICONS[1], ICONS[2], ICONS[12], ICONS[14] })
	for i, tab in ipairs(book.CategoryTabSystem.tabs) do
		Anchor(tab, f, "TOPRIGHT", 4, -(TITLE_HEIGHT + 20 + (i - 1) * 44))
	end
	book.CategoryTabSystem.tabs[1]:SetTabSelected(false)
	book.CategoryTabSystem.tabs[2]:SetTabSelected(true)
	book.SearchBox = EditBox(B, book, "Search", 180)
	Anchor(book.SearchBox, book, "TOPRIGHT", -60, -8)
	book.SettingsDropdown = B.frame("Button", book)
	Anchor(book.SettingsDropdown, book, "TOPRIGHT", -30, -8)
	book.SettingsDropdown:SetSize(22, 22)
	book.SettingsDropdown.Icon = B.texture(book.SettingsDropdown)
	local paged = B.frame("Frame", book)
	book.PagedSpellsFrame = paged
	Fill(paged, book, 30, 44, 60, 40)
	local shown = {}
	local header = B.frame("Frame", paged)
	At(header, paged, 0, 0, 640, 34)
	header.Text = Text(B.text(header), "Arms", "LEFT", header, "LEFT", 4, 0)
	header.Border = B.texture(header)
	header.Backplate = B.texture(header, "BACKGROUND")
	shown[#shown + 1] = header
	local spells = {
		{ "Mortal Strike", "Rank 4", ICONS[13] }, { "Overpower", "Rank 3", ICONS[9] }, { "Rend", "Rank 6", ICONS[4] },
		{ "Charge", "Rank 3", ICONS[3] }, { "Hamstring", "Rank 3", ICONS[10] }, { "Thunder Clap", "Rank 4", ICONS[5] },
		{ "Sweeping Strikes", "", ICONS[28] }, { "Retaliation", "", ICONS[27] }, { "Heroic Strike", "Rank 8", ICONS[1] },
		{ "Slam", "Rank 3", ICONS[2] }, { "Execute", "Rank 4", ICONS[8] }, { "Cleave", "Rank 4", ICONS[11] },
	}
	for i, spell in ipairs(spells) do
		local item = B.frame("Frame", paged)
		local column, row = (i - 1) % 2, math.floor((i - 1) / 2)
		At(item, paged, column * 320, 44 + row * 78, 300, 64)
		item.Backplate = B.texture(item, "BACKGROUND")
		local button = B.frame("Button", item)
		item.Button = button
		At(button, item, 8, 6, 48, 48)
		button.Icon = Icon(B, button, spell[3])
		button.IconMask = B.add(button:CreateMaskTexture())
		button.Icon:AddMaskTexture(button.IconMask)
		for _, key in ipairs({ "Border", "BorderShadow", "TrainableShadow", "TrainableBackplate", "BorderSheen" }) do
			button[key] = B.texture(button, "OVERLAY")
		end
		item.Name = Text(B.text(item), spell[1], "TOPLEFT", button, "TOPRIGHT", 12, -6)
		item.SubName = Text(B.text(item), spell[2], "TOPLEFT", button, "TOPRIGHT", 12, -28)
		item.RequiredLevel = B.text(item)
		item.RequiredLevel:Hide()
		shown[#shown + 1] = item
	end
	function paged.ForEachFrame(_, fn)
		for _, frame in ipairs(shown) do
			fn(frame)
		end
	end
	function paged.DisplayViewsForCurrentPage() end
	paged.PagingControls = B.frame("Frame", paged)
	Anchor(paged.PagingControls, book, "BOTTOMRIGHT", -40, 12)
	paged.PagingControls:SetSize(140, 24)
	paged.PagingControls.PageText = Text(B.text(paged.PagingControls), "Page 1 / 2", "CENTER", paged.PagingControls)
	for i, key in ipairs({ "PrevPageButton", "NextPageButton" }) do
		local button = B.frame("Button", paged.PagingControls)
		Anchor(button, paged.PagingControls, i == 1 and "LEFT" or "RIGHT", 0, 0)
		button:SetSize(20, 20)
		B.texture(button)
		paged.PagingControls[key] = button
	end
	f.TalentsFrame = B.frame("Frame", f)
	f.TalentsFrame:Hide()
	return f, { bounds = { f, book.CategoryTabSystem.tabs[1] } }
end

function build.talents(env, B)
	local f = SpellsWindow(env, B)
	f.SpellBookFrame = B.frame("Frame", f)
	f.SpellBookFrame:Hide()
	local talents = B.frame("Frame", f)
	f.TalentsFrame = talents
	Fill(talents, f, 0, TITLE_HEIGHT, 0, 0)
	for _, key in ipairs({ "Background", "BackgroundBorder", "DividerHorizontalLeft", "DividerHorizontalRight", "DividerVerticalLeft", "DividerVerticalRight" }) do
		talents[key] = B.texture(talents, "BACKGROUND")
	end
	talents.ClassBackground = Colour(B, talents, "BACKGROUND", 0.16, 0.12, 0.08, 0.5)
	Fill(talents.ClassBackground, talents, 20, 44, 20, 50)
	talents.TabSystem = TabSystem(B, talents, { "Arms", "Fury", "Protection" })
	for i, tab in ipairs(talents.TabSystem.tabs) do
		At(tab, talents, 30 + (i - 1) * 96, 8)
	end
	talents.SearchBox = EditBox(B, talents, "Search talents", 180)
	Anchor(talents.SearchBox, talents, "TOPRIGHT", -40, -8)
	talents.ApplyButton = Button(B, talents, "Apply Changes", 130)
	Anchor(talents.ApplyButton, talents, "BOTTOM", 0, 14)
	talents.InspectCopyButton = Button(B, talents, "Copy Build", 100)
	Anchor(talents.InspectCopyButton, talents, "BOTTOMRIGHT", -30, 14)
	local currency = B.frame("Frame", talents)
	talents.ClassCurrencyDisplay = currency
	Anchor(currency, talents, "BOTTOMLEFT", 30, 10)
	currency:SetSize(120, 40)
	currency.Border = B.texture(currency)
	currency.UnspentLabel = Text(B.text(currency), "Unspent points", "BOTTOMLEFT", currency, "BOTTOMLEFT", 0, 0)
	currency.CurrentAmountContainer = B.frame("Frame", currency)
	At(currency.CurrentAmountContainer, currency, 0, 0, 40, 26)
	currency.CurrentAmountContainer.CurrencyAmount = Text(B.text(currency.CurrentAmountContainer), "3", "LEFT", currency.CurrentAmountContainer, "LEFT", 0, 0)
	-- Blizzard's talent nodes keep their own art; the scene stands them in as a dark grid.
	for row = 0, 3 do
		for column = 0, 4 do
			local node = Colour(B, talents, "ARTWORK", 0.06, 0.07, 0.08, 0.9)
			At(node, talents, 90 + column * 130, 80 + row * 100, 40, 40)
		end
	end
	return f, {}
end

-- The world map (Blizzard_WorldMap.lua:104, 702 by 534 minimized) with the quest log docked on its right (QuestMapFrame.xml:427, 330 wide).
function build.worldmap(env, B)
	local map = B.frame("Frame", nil, "WorldMapFrame")
	map:SetSize(702, 534)
	At(map, env.UIParent, 120, 120)
	map:SetFrameLevel(5)
	map.ScrollContainer = B.frame("ScrollFrame", map)
	Fill(map.ScrollContainer, map, 0, TITLE_HEIGHT + 20, 0, 0)
	Colour(B, map.ScrollContainer, "BACKGROUND", 0.23, 0.29, 0.19):SetAllPoints(map.ScrollContainer)
	local border = B.frame("Frame", map)
	map.BorderFrame = border
	border:SetAllPoints(map)
	border:SetFrameLevel(20)
	border.NineSlice = B.frame("Frame", border)
	border.NineSlice:SetAllPoints(border)
	B.texture(border.NineSlice)
	border.Bg = B.texture(border, "BACKGROUND")
	border.InsetBorderTop = B.texture(border, "BACKGROUND")
	border.TitleContainer = B.frame("Frame", border)
	At(border.TitleContainer, border, 0, 0, 702, TITLE_HEIGHT)
	border.TitleContainer.TitleText = Text(B.text(border.TitleContainer), "Durotar", "CENTER", border.TitleContainer)
	border.PortraitContainer = B.frame("Frame", border)
	B.texture(border.PortraitContainer)
	border.CloseButton = B.frame("Button", border)
	Anchor(border.CloseButton, border, "TOPRIGHT", -4, -2)
	border.CloseButton:SetSize(CLOSE, CLOSE)
	B.texture(border.CloseButton)
	border.MaximizeMinimizeFrame = B.frame("Frame", border)
	for i, key in ipairs({ "MaximizeButton", "MinimizeButton" }) do
		local button = B.frame("Button", border.MaximizeMinimizeFrame)
		Anchor(button, border, "TOPRIGHT", -4 - CLOSE - 2, -2)
		button:SetSize(CLOSE, CLOSE)
		B.texture(button)
		button:SetShown(i == 1)
		border.MaximizeMinimizeFrame[key] = button
	end
	map.NavBar = B.frame("Frame", map)
	At(map.NavBar, map, 4, TITLE_HEIGHT, 694, 20)
	map.NavBar:SetFrameLevel(21)
	B.texture(map.NavBar)
	map.NavBar.overlay = B.frame("Frame", map.NavBar)
	map.NavBar.overlay:SetAllPoints(map.NavBar)
	B.texture(map.NavBar.overlay)
	map.NavBar.home = B.frame("Button", map.NavBar)
	At(map.NavBar.home, map.NavBar, 4, 0, 80, 20)
	Text(B.text(map.NavBar.home), "Kalimdor  >  Durotar", "LEFT", map.NavBar.home, "LEFT", 4, 0)

	local log = B.frame("Frame", map, "QuestMapFrame")
	Anchor(log, map, "TOPLEFT", "TOPRIGHT", 2, 0)
	log:SetSize(330, 534)
	log.QuestsFrame = B.frame("Frame", log)
	log.QuestsFrame:SetAllPoints(log)
	local scroll = B.frame("ScrollFrame", log.QuestsFrame, "QuestScrollFrame")
	log.QuestsFrame.ScrollFrame = scroll
	Fill(scroll, log, 8, 36, 8, 8)
	scroll.Background, scroll.Edge = B.texture(scroll, "BACKGROUND"), B.texture(scroll)
	scroll.ScrollBar = ScrollBar(B, scroll)
	Anchor(scroll.ScrollBar, scroll, "TOPRIGHT", 0, -30)
	scroll.ScrollBar:SetHeight(440)
	scroll.SearchBox = EditBox(B, scroll, "Search quests", 260)
	At(scroll.SearchBox, scroll, 10, 2)
	scroll.BorderFrame = B.frame("Frame", scroll)
	B.texture(scroll.BorderFrame)
	local headers, titles = {}, {}
	local y = 36
	local function Header(text)
		local header = B.frame("Button", scroll)
		At(header, scroll, 10, y, 280, 22)
		header.ButtonText = Text(B.text(header), text, "LEFT", header, "LEFT", 6, 0)
		headers[#headers + 1] = header
		y = y + 24
	end
	local function Title(text)
		local title = B.frame("Button", scroll)
		At(title, scroll, 24, y, 266, 20)
		title.Text = Text(B.text(title), text, "LEFT", title, "LEFT", 6, 0)
		titles[#titles + 1] = title
		y = y + 22
	end
	Header("Durotar")
	Title("Riverglade Crocolisks")
	Title("The Lost Patrol")
	Title("Thunder Ridge Harpies")
	Header("The Barrens")
	Title("Supplies for the Crossroads")
	Title("Plainstrider Menace")
	local function Pool(list)
		return {
			EnumerateActive = function()
				local i = 0
				return function()
					i = i + 1
					return list[i]
				end
			end,
		}
	end
	scroll.headerFramePool = Pool(headers)
	scroll.titleFramePool = Pool(titles)
	env.QuestLogQuests_Update = function() end
	local details = B.frame("Frame", log.QuestsFrame)
	log.QuestsFrame.DetailsFrame = details
	details:Hide()
	details.Bg = B.texture(details, "BACKGROUND")
	details.BackFrame = B.frame("Frame", details)
	details.BackFrame.BackButton = Button(B, details.BackFrame, "Back", 60)
	for _, key in ipairs({ "AbandonButton", "ShareButton", "TrackButton" }) do
		details[key] = Button(B, details, key, 60)
	end
	details.ScrollFrame = B.frame("ScrollFrame", details)
	details.ScrollFrame.ScrollBar = ScrollBar(B, details.ScrollFrame)
	return map, { show = { map, log }, bounds = { map, log } }
end

-- The game menu (Shared/GameMenuFrame.xml:7): a header and pooled buttons.
function build.gamemenu(env, B)
	local menu = B.frame("Frame", nil, "GameMenuFrame")
	menu:SetSize(220, 360)
	Anchor(menu, env.UIParent, "CENTER", 0, 60)
	menu.Border = B.frame("Frame", menu)
	menu.Border:SetAllPoints(menu)
	B.texture(menu.Border)
	menu.Header = B.frame("Frame", menu)
	At(menu.Header, menu, 0, -10, 220, 30)
	B.texture(menu.Header)
	menu.Header.Text = Text(B.text(menu.Header), "Game Menu", "CENTER", menu.Header)
	local buttons = {}
	for i, label in ipairs({ "Options", "Support", "Macros", "AddOns", "Edit Mode", "Logout", "Exit Game", "Return to Game" }) do
		local button = Button(B, menu, label, 180, 28)
		At(button, menu, 20, 30 + (i - 1) * 36 + (i == 8 and 12 or 0))
		buttons[i] = button
	end
	menu.buttonPool = {
		EnumerateActive = function()
			local i = 0
			return function()
				i = i + 1
				return buttons[i]
			end
		end,
	}
	function menu.InitButtons() end
	menu:Hide()
	return menu, {}
end

-- The group finder (Blizzard_LFGVanilla_ParentFrame.xml:23, 384 by 512) on its browse page, rows 312 by 36 (Browse.xml:125).
function build.groupfinder(env, B)
	local parent = B.frame("Frame", nil, "LFGParentFrame")
	parent:SetSize(384, 512)
	At(parent, env.UIParent, 160, 100)
	parent:Hide()
	local close = B.frame("Button", parent, "LFGParentFrameCloseButton")
	Anchor(close, parent, "TOPRIGHT", -4, -2)
	close:SetSize(CLOSE, CLOSE)
	B.texture(close)
	for i, label in ipairs({ "Dungeons", "Raids", "PvP" }) do
		parent["Tab" .. i] = Tab(B, parent, label, "LFGParentFrameTab" .. i)
		Anchor(parent["Tab" .. i], parent, "BOTTOMLEFT", 12 + (i - 1) * 84, -22)
	end
	parent.numTabs = 2
	parent.Tab1:Disable()
	for i, key in ipairs({ "ListingTab", "BrowsingTab", "WhoListingTab" }) do
		parent[key] = SideTab(B, parent, ICONS[6 + i])
		Anchor(parent[key], parent, "TOPLEFT", -36, -(TITLE_HEIGHT + 8 + (i - 1) * 38))
		parent[key]:SetChecked(i == 2)
	end
	local listing = Window(B, "LFGListingFrame", parent, 384, 512, "Group Finder")
	listing:SetAllPoints(parent)
	listing.BackButton, listing.PostButton = Button(B, listing, "Back", 80), Button(B, listing, "Post", 80)
	listing.ActivityView = B.frame("Frame", listing)
	listing.ActivityView.ScrollBar = ScrollBar(B, listing.ActivityView)
	listing.ActivityView.Comment = B.frame("ScrollFrame", listing.ActivityView)
	B.texture(listing.ActivityView.Comment)
	listing.ActivityView.Comment.ScrollBar = ScrollBar(B, listing.ActivityView.Comment)
	local browse = Window(B, "LFGBrowseFrame", parent, 384, 512, "Browse Groups")
	browse:SetAllPoints(parent)
	browse.CategoryDropdown = Dropdown(B, browse, "Dungeons", 150)
	At(browse.CategoryDropdown, browse, 16, 34)
	browse.ActivityDropdown = Dropdown(B, browse, "Wailing Caverns", 150)
	At(browse.ActivityDropdown, browse, 176, 34)
	browse.RefreshButton = B.frame("Button", browse)
	Anchor(browse.RefreshButton, browse, "TOPRIGHT", -16, -34)
	browse.RefreshButton:SetSize(22, 22)
	browse.RefreshButton.Icon = Icon(B, browse.RefreshButton, ICONS[19])
	browse.ScrollBox = ScrollBox(B, browse)
	Fill(browse.ScrollBox, browse, 16, 66, 30, 60)
	browse.ScrollBar = ScrollBar(B, browse)
	Anchor(browse.ScrollBar, browse, "TOPRIGHT", -14, -66)
	browse.ScrollBar:SetHeight(380)
	local rows = {}
	for i, entry in ipairs({ { "Thargor", "Tank, 2 / 5", true }, { "Riverglades", "Healer wanted, 3 / 5" }, { "Zul'tak", "DPS, 4 / 5" }, { "Morgla", "Any role, 1 / 5" }, { "Krek", "Tank, 3 / 5" }, { "Shazi", "Healer, 2 / 5" } }) do
		local row = Row(B, browse.ScrollBox, 36)
		row.ResultBG = B.texture(row, "BACKGROUND")
		row.Selected = B.texture(row)
		row.Selected:SetShown(entry[3] == true)
		row.Highlight = B.texture(row, "HIGHLIGHT")
		row.Name = Text(B.text(row), entry[1], "TOPLEFT", row, "TOPLEFT", 8, -4)
		row.ActivityName = Text(B.text(row), entry[2], "BOTTOMLEFT", row, "BOTTOMLEFT", 8, 4)
		rows[i] = row
		browse.ScrollBox.AddRow(row, {})
	end
	Stack(rows, browse.ScrollBox, 0, 2)
	browse.SendMessageButton = Button(B, browse, "Send Message", 110)
	Anchor(browse.SendMessageButton, browse, "BOTTOMLEFT", 16, 30)
	browse.GroupInviteButton = Button(B, browse, "Invite", 90)
	Anchor(browse.GroupInviteButton, browse, "BOTTOMRIGHT", -16, 30)
	local who = Window(B, "LFGWhoListFrame", parent, 384, 512, "Who")
	who.EditBox = EditBox(B, who, "", 200)
	who.FilterDropdown = Dropdown(B, who, "", 120)
	return parent, { show = { parent, browse }, bounds = { parent, parent.ListingTab, parent.Tab1 } }
end

-- The mailbox (MailFrame.xml:277, ButtonFrameTemplate) with its inbox and the open letter beside it (MailFrame.xml:898).
function build.mail(env, B)
	local mail = Window(B, "MailFrame", nil, 338, 424, "Mailbox", { inset = { top = 60, bottom = 30 } })
	At(mail, env.UIParent, 120, 120)
	mail.numTabs = 2
	for i, label in ipairs({ "Inbox", "Send Mail" }) do
		local tab = Tab(B, mail, label, "MailFrameTab" .. i)
		Anchor(tab, mail, "BOTTOMLEFT", 12 + (i - 1) * 84, -22)
	end
	env.MailFrameTab1:Disable()
	local inbox = B.frame("Frame", mail, "InboxFrame")
	inbox:SetAllPoints(mail.Inset)
	B.texture(inbox)
	local letters = { { "Auctioneer Grizzlin", "Auction successful: Rugged Hide", 2 }, { "Thargor", "Loot from the raid", 4 }, { "Riverglades", "Thanks for the help!", 1 }, { "Gazlowe", "Your order is ready", 3 }, { "Zul'tak", "Guild meeting tonight", 1 } }
	for i = 1, 7 do
		local item = B.frame("Frame", inbox, "MailItem" .. i)
		item:SetSize(305, 45)
		At(item, inbox, 8, 6 + (i - 1) * 47)
		B.texture(item)
		local letter = letters[i]
		if letter then
			item.Button = Item(B, item, ICONS[i + 14], 37, "MailItem" .. i .. "Button")
			Anchor(item.Button, item, "LEFT", 2, 0)
			env["MailItem" .. i .. "ButtonCODBackground"] = B.texture(item.Button)
			Text(B.text(item), letter[1], "TOPLEFT", item, "TOPLEFT", 48, -6)
			Text(B.text(item), letter[2], "BOTTOMLEFT", item, "BOTTOMLEFT", 48, 8)
		else
			item:Hide()
		end
	end
	inbox.PrevPageButton = B.frame("Button", inbox)
	inbox.NextPageButton = B.frame("Button", inbox)
	Anchor(inbox.PrevPageButton, mail, "BOTTOMLEFT", 20, 6)
	Anchor(inbox.NextPageButton, mail, "BOTTOMRIGHT", -20, 6)
	inbox.PrevPageButton:SetSize(20, 20)
	inbox.NextPageButton:SetSize(20, 20)
	B.texture(inbox.PrevPageButton)
	B.texture(inbox.NextPageButton)
	inbox.OpenAllMail = Button(B, inbox, "Open All", 100)
	Anchor(inbox.OpenAllMail, mail, "BOTTOM", 0, 5)
	local send = B.frame("Frame", mail, "SendMailFrame")
	send:Hide()
	B.texture(send)
	EditBox(B, send, "", 200, nil, "SendMailNameEditBox")
	EditBox(B, send, "", 200, nil, "SendMailSubjectEditBox")
	local money = B.frame("Frame", send, "SendMailMoney")
	for _, coin in ipairs({ "gold", "silver", "copper" }) do
		money[coin] = EditBox(B, money, "", 40)
		money[coin].texture = B.texture(money[coin])
	end
	Check(B, send, "", "SendMailSendMoneyButton")
	Check(B, send, "", "SendMailCODButton")
	env.SendMailCancelButton = Button(B, send, "Cancel", 80)
	env.SendMailMailButton = Button(B, send, "Send", 80)
	local inset = B.frame("Frame", send, "SendMailMoneyInset")
	inset.NineSlice = B.frame("Frame", inset)
	B.texture(inset.NineSlice)
	inset.Bg = B.texture(inset, "BACKGROUND")
	env.SendMailMoneyBg = B.texture(send)
	env.SendMailScrollFrame = B.frame("ScrollFrame", send)
	B.texture(env.SendMailScrollFrame)
	env.SendMailScrollFrame.ScrollBar = ScrollBar(B, env.SendMailScrollFrame)

	local letter = Window(B, "OpenMailFrame", nil, 338, 424, "Thargor", { inset = { top = 60, bottom = 30 } })
	Anchor(letter, mail, "TOPLEFT", "TOPRIGHT", 16, 0)
	local scroll = B.frame("ScrollFrame", letter, "OpenMailScrollFrame")
	Fill(scroll, letter.Inset, 6, 6, 6, 60)
	B.texture(scroll)
	scroll.ScrollBar = ScrollBar(B, scroll)
	Anchor(scroll.ScrollBar, scroll, "TOPRIGHT", -2, -4)
	scroll.ScrollBar:SetHeight(200)
	Text(B.text(scroll), "Subject: Loot from the raid", "TOPLEFT", scroll, "TOPLEFT", 10, -10)
	-- MailFrame.xml:1010: the body is 276 wide from 10 in; in the game it is a SimpleHTML, here a font string the
	-- renderer can draw.
	local body = Text(B.text(scroll), "Here is the hide you rolled on. Good fight last night, see you at the Crossroads.\n\n- Thargor", "TOPLEFT", scroll, "TOPLEFT", 10, -36)
	body:SetWidth(276)
	body:SetHeight(60)
	env.OpenMailBodyText = body
	local letterButton = Item(B, letter, ICONS[20], 37, "OpenMailLetterButton")
	Anchor(letterButton, letter.Inset, "BOTTOMLEFT", 10, 10)
	local moneyButton = Item(B, letter, ICONS[21], 37, "OpenMailMoneyButton")
	Anchor(moneyButton, letterButton, "LEFT", "RIGHT", 6, 0)
	for i = 1, 3 do
		local attachment = Item(B, letter, ICONS[22 + i], 37, "OpenMailAttachmentButton" .. i)
		Anchor(attachment, moneyButton, "LEFT", "RIGHT", 6 + (i - 1) * 43, 0)
	end
	for i, entry in ipairs({ { "OpenMailReplyButton", "Reply" }, { "OpenMailDeleteButton", "Delete" }, { "OpenMailReportSpamButton", "Report Spam" }, { "OpenMailCancelButton", "Close" } }) do
		local button = Button(B, letter, entry[2], 74)
		env[entry[1]] = button
		Anchor(button, letter, "BOTTOMLEFT", 8 + (i - 1) * 80, 6)
	end
	return mail, { show = { mail, letter }, bounds = { mail, letter, env.MailFrameTab1 } }
end

-- The merchant (Vanilla/MerchantFrame.xml:89, 336 by 444) with its 153 by 44 item rows (MerchantFrame.xml:4).
function build.merchant(env, B)
	local merchant = Window(B, "MerchantFrame", nil, 336, 444, "Gazlowe", { inset = { top = 60, bottom = 60 } })
	At(merchant, env.UIParent, 120, 120)
	merchant.numTabs = 2
	for i, label in ipairs({ "Merchant", "Buyback" }) do
		local tab = Tab(B, merchant, label, "MerchantFrameTab" .. i)
		Anchor(tab, merchant, "BOTTOMLEFT", 12 + (i - 1) * 84, -22)
	end
	env.MerchantFrameTab1:Disable()
	merchant.FilterDropdown = Dropdown(B, merchant, "All", 110)
	Anchor(merchant.FilterDropdown, merchant, "TOPRIGHT", -30, -34)
	local goods = {
		{ "Rugged Hide", "4g 12s", 2 }, { "Heavy Silk Bandage", "48s", 1 }, { "Greater Healing Potion", "1g 20s", 1 },
		{ "Steel Weapon Chain", "2g 80s", 2 }, { "Thorium Bar", "3g", 1 }, { "Ironfeather", "6g 40s", 3 },
		{ "Dense Grinding Stone", "18s", 1 }, { "Flask of Oil", "12s", 1 }, { "Runecloth", "90s", 1 }, { "Enchanted Thorium", "14g", 4 },
	}
	for i, good in ipairs(goods) do
		local slot = B.frame("Frame", merchant, "MerchantItem" .. i)
		slot:SetSize(153, 44)
		local column, row = (i - 1) % 2, math.floor((i - 1) / 2)
		At(slot, merchant.Inset, 8 + column * 160, 8 + row * 50)
		slot.SlotTexture = B.texture(slot)
		slot.ItemButton = Item(B, slot, ICONS[i], 37)
		Anchor(slot.ItemButton, slot, "LEFT", 3, 0)
		slot.Name = Text(B.text(slot), good[1], "TOPLEFT", slot, "TOPLEFT", 46, -5)
		slot.MoneyFrame = Text(B.text(slot), good[2], "BOTTOMLEFT", slot, "BOTTOMLEFT", 46, 6)
	end
	local buyback = B.frame("Frame", merchant, "MerchantBuyBackItem")
	buyback:SetSize(153, 44)
	Anchor(buyback, merchant.Inset, "BOTTOMLEFT", 8, 8)
	buyback.ItemButton = Item(B, buyback, ICONS[15], 37)
	Anchor(buyback.ItemButton, buyback, "LEFT", 3, 0)
	Text(B.text(buyback), "Buyback", "LEFT", buyback, "LEFT", 46, 0)
	local x = 180
	for _, name in ipairs({ "MerchantRepairItemButton", "MerchantRepairAllButton", "MerchantGuildBankRepairButton", "MerchantSellAllJunkButton" }) do
		local button = B.frame("Button", merchant, name)
		button:SetSize(32, 32)
		Anchor(button, merchant.Inset, "BOTTOMLEFT", x, 14)
		button.slot = B.texture(button)
		button.Icon = Icon(B, button, ICONS[24])
		x = x + 36
	end
	for _, name in ipairs({ "MerchantExtraCurrencyInset", "MerchantMoneyInset" }) do
		local inset = B.frame("Frame", merchant, name)
		inset.NineSlice = B.frame("Frame", inset)
		B.texture(inset.NineSlice)
		inset.Bg = B.texture(inset, "BACKGROUND")
	end
	Anchor(env.MerchantMoneyInset, merchant, "BOTTOMRIGHT", -8, 30)
	env.MerchantMoneyInset:SetSize(170, 24)
	Text(B.text(env.MerchantMoneyInset), "143g 82s 17c", "RIGHT", env.MerchantMoneyInset, "RIGHT", -8, 0)
	Anchor(env.MerchantExtraCurrencyInset, merchant, "BOTTOMLEFT", 8, 30)
	env.MerchantExtraCurrencyInset:SetSize(60, 24)
	env.MerchantExtraCurrencyBg = B.texture(merchant)
	env.MerchantMoneyBg = B.texture(merchant)
	for i, name in ipairs({ "MerchantPrevPageButton", "MerchantNextPageButton" }) do
		local button = B.frame("Button", merchant, name)
		button:SetSize(20, 20)
		Anchor(button, merchant.Inset, i == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT", i == 1 and 180 or -8, -4)
		B.texture(button)
	end
	Text(B.text(merchant), "Page 1", "BOTTOM", merchant.Inset, "BOTTOM", 60, -4)
	return merchant, { bounds = { merchant, env.MerchantFrameTab1 } }
end

-- A ProfessionsRankBarTemplate bar: Background, Fill, Border, the Rank text.
local function RankBar(B, parent, w, label)
	local bar = B.frame("Frame", parent)
	bar:SetSize(w, 16)
	bar.Background = B.texture(bar)
	bar.Fill = B.texture(bar)
	bar.Border = B.texture(bar)
	bar.Rank = B.frame("Frame", bar)
	bar.Rank:SetAllPoints(bar)
	bar.Rank.Text = Text(B.text(bar.Rank), label, "CENTER", bar.Rank)
	bar.ratio = 0.62
	function bar:Update(info)
		self.Rank.Text:SetText(info.skillLevel)
	end
	return bar
end

-- The professions window (Blizzard_ProfessionsFrame.xml:5, 658 tall; its width is the crafting page's).
function build.professions(env, B)
	local f = Window(B, "ProfessionsFrame", nil, 942, 658, "Blacksmithing")
	At(f, env.UIParent, 100, 80)
	f.ProfessionsOverviewTab = SideTab(B, f, ICONS[22])
	Anchor(f.ProfessionsOverviewTab, f, "TOPLEFT", -36, -(TITLE_HEIGHT + 8))
	f.rightProfessionTabs = { SideTab(B, f, ICONS[23]), SideTab(B, f, ICONS[24]) }
	for i, tab in ipairs(f.rightProfessionTabs) do
		Anchor(tab, f, "TOPLEFT", -36, -(TITLE_HEIGHT + 46 + (i - 1) * 38))
		tab:SetChecked(i == 1)
	end
	local page = B.frame("Frame", f)
	f.CraftingPage = page
	Fill(page, f, 0, TITLE_HEIGHT, 0, 0)
	B.texture(page)
	local list = B.frame("Frame", page)
	page.RecipeList = list
	Fill(list, page, 12, 40, 660, 12)
	list.BackgroundNineSlice = B.frame("Frame", list)
	B.texture(list.BackgroundNineSlice)
	list.SearchBox = EditBox(B, list, "Search recipes", 180)
	At(list.SearchBox, list, 8, 8)
	list.FilterDropdown = Dropdown(B, list, "Filter", 70)
	Anchor(list.FilterDropdown, list, "TOPRIGHT", -8, -8)
	list.ScrollBar = ScrollBar(B, list)
	Anchor(list.ScrollBar, list, "TOPRIGHT", -6, -40)
	list.ScrollBar:SetHeight(520)
	for i, recipe in ipairs({ "Weapons", "  Thorium Greatsword", "  Steel Weapon Chain", "  Heavy Mithril Axe", "Armor", "  Thorium Helm", "  Mithril Scale Pants", "  Steel Plate Helm", "Misc", "  Dense Grinding Stone" }) do
		Text(B.text(list), recipe, "TOPLEFT", list, "TOPLEFT", 12, -(44 + (i - 1) * 22))
	end
	local form = B.frame("Frame", page)
	page.SchematicForm = form
	Fill(form, page, 290, 40, 12, 60)
	form.Background, form.MinimalBackground = B.texture(form, "BACKGROUND"), B.texture(form, "BACKGROUND")
	form.NineSlice = B.frame("Frame", form)
	B.texture(form.NineSlice)
	Text(B.text(form), "Thorium Greatsword", "TOPLEFT", form, "TOPLEFT", 60, -16)
	Text(B.text(form), "Two-Handed Sword   Requires Blacksmithing 285", "TOPLEFT", form, "TOPLEFT", 60, -40)
	local output = Item(B, form, ICONS[13], 44)
	At(output, form, 10, 12)
	Text(B.text(form), "Reagents", "TOPLEFT", form, "TOPLEFT", 16, -80)
	for i, reagent in ipairs({ "Thorium Bar x12", "Dense Grinding Stone x4", "Rugged Leather x2" }) do
		local slot = Item(B, form, ICONS[14 + i], 32)
		At(slot, form, 16, 100 + (i - 1) * 40)
		Text(B.text(form), reagent, "LEFT", slot, "RIGHT", 10, 0)
	end
	page.RankBar = RankBar(B, page, 320, "262 / 300")
	Anchor(page.RankBar, page, "TOP", 150, -10)
	page.CreateMultipleInputBox = EditBox(B, page, "1", 50)
	Anchor(page.CreateMultipleInputBox, page, "BOTTOMRIGHT", -250, 18)
	for _, key in ipairs({ "IncrementButton", "DecrementButton" }) do
		local button = B.frame("Button", page.CreateMultipleInputBox)
		button:SetSize(16, 16)
		Anchor(button, page.CreateMultipleInputBox, key == "IncrementButton" and "LEFT" or "RIGHT", key == "IncrementButton" and "RIGHT" or "LEFT", 0, 0)
		B.texture(button)
		page.CreateMultipleInputBox[key] = button
	end
	page.CreateAllButton = Button(B, page, "Create All", 130)
	Anchor(page.CreateAllButton, page, "BOTTOMRIGHT", -112, 18)
	page.CreateButton = Button(B, page, "Create", 90)
	Anchor(page.CreateButton, page, "BOTTOMRIGHT", -12, 18)
	for i, key in ipairs({ "Prof0ToolSlot", "Prof0Gear0Slot", "Prof0Gear1Slot" }) do
		page[key] = Item(B, page, ICONS[25 + i], 36)
		Anchor(page[key], page, "BOTTOMLEFT", 300 + (i - 1) * 42, 14)
	end
	f.BookPage = B.frame("Frame", f)
	f.BookPage:Hide()
	f.BookPage.ProfessionsContentFrame = B.frame("Frame", f.BookPage)
	return f, { bounds = { f, f.ProfessionsOverviewTab } }
end

-- The trainer (Blizzard_TrainerUI.xml:150, ButtonFrameTemplate): the skill bar, the filter, category and skill rows.
function build.trainer(env, B)
	local trainer = Window(B, "ClassTrainerFrame", nil, 338, 424, "Grezz Ragefist", { inset = { top = 90, bottom = 60 } })
	At(trainer, env.UIParent, 120, 120)
	-- Blizzard_TrainerUI.xml:167: the skill bar is 130 by 18 at (64, -35) and reads "rank/max"
	-- (Blizzard_TrainerUI.lua:565); the skill line's name comes from GetTrainerServiceSkillLine.
	local bar = StatusBar(B, trainer, 130, 18, 0.62)
	env.ClassTrainerStatusBar = bar
	At(bar, trainer, 64, 35)
	bar.rankText = Text(B.text(bar), "186/300", "CENTER", bar)
	env.GetNumTrainerServices = function()
		return 4
	end
	env.GetTrainerServiceSkillLine = function()
		return "Polearms"
	end
	trainer.FilterDropdown = Dropdown(B, trainer, "Available", 100)
	Anchor(trainer.FilterDropdown, trainer, "TOPRIGHT", -12, -60)
	Text(B.text(trainer), "Warrior Trainer", "TOPLEFT", trainer, "TOPLEFT", 60, -60)
	trainer.ScrollBar = ScrollBar(B, trainer)
	Anchor(trainer.ScrollBar, trainer.Inset, "TOPRIGHT", -4, -4)
	trainer.ScrollBar:SetHeight(260)
	trainer.ScrollBox = ScrollBox(B, trainer)
	Fill(trainer.ScrollBox, trainer.Inset, 4, 4, 18, 4)
	local rows = {}
	local function Category(label)
		local row = Row(B, trainer.ScrollBox, 22)
		row.LeftPiece, row.RightPiece, row.CenterPiece = B.texture(row), B.texture(row), B.texture(row)
		row.Label = Text(B.text(row), label, "LEFT", row, "LEFT", 8, 0)
		rows[#rows + 1] = row
		trainer.ScrollBox.AddRow(row, {})
	end
	local function Skill(name, cost, id, selected)
		local row = Row(B, trainer.ScrollBox, 44)
		row.icon = Icon(B, row, id)
		row.icon:ClearAllPoints()
		row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
		row.icon:SetSize(36, 36)
		row.selectedTex = B.texture(row)
		row.selectedTex:SetShown(selected == true)
		row.name = Text(B.text(row), name, "TOPLEFT", row, "TOPLEFT", 48, -6)
		row.money = Text(B.text(row), cost, "BOTTOMLEFT", row, "BOTTOMLEFT", 48, 6)
		rows[#rows + 1] = row
		trainer.ScrollBox.AddRow(row, {})
	end
	Category("Available")
	Skill("Mortal Strike (Rank 2)", "2g 40s", ICONS[13], true)
	Skill("Whirlwind (Rank 1)", "1g 80s", ICONS[12])
	Category("Unavailable")
	Skill("Execute (Rank 4)", "Requires level 40", ICONS[8])
	Skill("Sweeping Strikes", "Requires level 42", ICONS[28])
	Stack(rows, trainer.ScrollBox, 0, 2)
	trainer.TrainButton = Button(B, trainer, "Train", 90)
	env.ClassTrainerTrainButton = trainer.TrainButton
	Anchor(trainer.TrainButton, trainer, "BOTTOMRIGHT", -10, 10)
	trainer.bottomInset = B.frame("Frame", trainer)
	Fill(trainer.bottomInset, trainer, 4, 374, 6, 10)
	trainer.bottomInset.NineSlice = B.frame("Frame", trainer.bottomInset)
	B.texture(trainer.bottomInset.NineSlice)
	trainer.bottomInset.Bg = B.texture(trainer.bottomInset, "BACKGROUND")
	Text(B.text(trainer.bottomInset), "143g 82s 17c", "LEFT", trainer.bottomInset, "LEFT", 10, 0)
	env.ClassTrainerFrame_InitCategoryButton = function() end
	env.ClassTrainerFrame_SetTrainButtonEnabled = function() end
	return trainer, {}
end

-- The addon list (AddonList.xml:121, 600 by 550).
function build.addonlist(env, B)
	local f = Window(B, "AddonList", nil, 600, 550, "AddOns", { inset = { top = 64, bottom = 60 } })
	At(f, env.UIParent, 120, 100)
	f.Dropdown = Dropdown(B, f, "Valerin", 150)
	At(f.Dropdown, f, 14, 32)
	f.ForceLoad = Check(B, f, "Load out of date AddOns")
	At(f.ForceLoad, f, 180, 32)
	f.SearchBox = EditBox(B, f, "Search", 160)
	Anchor(f.SearchBox, f, "TOPRIGHT", -14, -32)
	f.SearchBox.searchIcon = Colour(B, f.SearchBox, "OVERLAY", 0.67, 0.67, 0.67)
	Anchor(f.SearchBox.searchIcon, f.SearchBox, "RIGHT", -6, 0)
	f.SearchBox.searchIcon:SetSize(10, 10)
	f.Performance = B.frame("Frame", f)
	Anchor(f.Performance, f, "BOTTOMLEFT", 14, 36)
	f.Performance:SetSize(260, 20)
	f.Performance.Header = Text(B.text(f.Performance), "Performance", "LEFT", f.Performance, "LEFT", 0, 0)
	f.Performance.Current = Text(B.text(f.Performance), "12.4 ms per frame", "RIGHT", f.Performance, "RIGHT", 0, 0)
	f.Performance.Divider = B.texture(f.Performance)
	for i, entry in ipairs({ { "CancelButton", "Cancel" }, { "OkayButton", "Okay" }, { "EnableAllButton", "Enable All" }, { "DisableAllButton", "Disable All" } }) do
		local button = Button(B, f, entry[2], 90)
		f[entry[1]] = button
		if i <= 2 then
			Anchor(button, f, "BOTTOMRIGHT", -14 - (2 - i) * 96, 10)
		else
			Anchor(button, f, "BOTTOMLEFT", 14 + (i - 3) * 96, 10)
		end
	end
	f.ScrollBar = ScrollBar(B, f)
	Anchor(f.ScrollBar, f.Inset, "TOPRIGHT", -4, -4)
	f.ScrollBar:SetHeight(400)
	f.ScrollBox = ScrollBox(B, f)
	Fill(f.ScrollBox, f.Inset, 4, 4, 18, 4)
	local rows = {}
	local function Category(title)
		local row = Row(B, f.ScrollBox, 24)
		row.Title = Text(B.text(row), title, "LEFT", row, "LEFT", 26, 0)
		row.CollapseExpand = B.frame("Button", row)
		Anchor(row.CollapseExpand, row, "LEFT", 4, 0)
		row.CollapseExpand:SetSize(16, 16)
		row.CollapseExpand.Art = B.texture(row.CollapseExpand)
		row:SetHighlightTexture(B.texture(row, "HIGHLIGHT"))
		rows[#rows + 1] = row
		f.ScrollBox.AddRow(row, {})
	end
	local function Entry(title, status, on, load)
		local row = Row(B, f.ScrollBox, 24)
		row.Title = Text(B.text(row), title, "LEFT", row, "LEFT", 40, 0)
		row.Status = Text(B.text(row), status, "RIGHT", row, "RIGHT", -120, 0)
		row.Reload = B.text(row)
		row.Reload:Hide()
		row:SetHighlightTexture(B.texture(row, "HIGHLIGHT"))
		local check = B.frame("CheckButton", row)
		row.Enabled = check
		Anchor(check, row, "LEFT", 12, 0)
		check:SetSize(20, 20)
		check.CheckedTexture = B.texture(check, "ARTWORK")
		B.texture(check, "BACKGROUND")
		check:SetChecked(on)
		if load then
			row.LoadAddonButton = Button(B, row, "Load AddOn", 90, 18)
			Anchor(row.LoadAddonButton, row, "RIGHT", -8, 0)
		end
		rows[#rows + 1] = row
		f.ScrollBox.AddRow(row, {})
	end
	Category("KstyleUI")
	Entry("KstyleUI", "Loaded", true)
	Entry("KstyleUI Skins", "Loaded", true)
	Entry("KstyleUI Icons", "Load on demand", false, true)
	Category("Other")
	Entry("RestedXP Guides", "Loaded", true)
	Entry("Details! Damage Meter", "Disabled", false)
	Entry("WeakAuras", "Loaded", true)
	Stack(rows, f.ScrollBox, 0, 2)
	return f, {}
end

-- The guild and communities window (CommunitiesFrame.xml:304, 814 by 426).
function build.communities(env, B)
	local f = Window(B, "CommunitiesFrame", nil, 814, 426, "Warsong Outriders")
	At(f, env.UIParent, 120, 140)
	f.PortraitOverlay = B.frame("Frame", f)
	B.texture(f.PortraitOverlay, "BACKGROUND")
	f.MaximizeMinimizeFrame = B.frame("Frame", f)
	for i, key in ipairs({ "MaximizeButton", "MinimizeButton" }) do
		local button = B.frame("Button", f.MaximizeMinimizeFrame)
		Anchor(button, f, "TOPRIGHT", -4 - CLOSE - 2, -2)
		button:SetSize(CLOSE, CLOSE)
		button.Art = B.texture(button)
		button:SetShown(i == 2)
		f.MaximizeMinimizeFrame[key] = button
	end
	for i, key in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" }) do
		local tab = B.frame("CheckButton", f)
		tab:SetSize(32, 32)
		Anchor(tab, f, "TOPRIGHT", 36, -(TITLE_HEIGHT + 8 + (i - 1) * 38))
		tab.Icon = Icon(B, tab, ICONS[6 + i])
		tab.Art = B.texture(tab, "BORDER")
		tab:SetChecked(i == 2)
		f[key] = tab
	end
	local list = B.frame("Frame", f)
	f.CommunitiesList = list
	Fill(list, f, 0, TITLE_HEIGHT, 634, 0)
	list.Bg = B.texture(list, "BACKGROUND")
	list.FilligreeOverlay = B.frame("Frame", list)
	B.texture(list.FilligreeOverlay)
	list.InsetFrame = B.frame("Frame", list)
	list.InsetFrame.NineSlice = B.frame("Frame", list.InsetFrame)
	B.texture(list.InsetFrame.NineSlice)
	list.InsetFrame.Bg = B.texture(list.InsetFrame, "BACKGROUND")
	list.ScrollBar = ScrollBar(B, list)
	Anchor(list.ScrollBar, list, "TOPRIGHT", -4, -8)
	list.ScrollBar:SetHeight(340)
	list.ScrollBox = ScrollBox(B, list)
	Fill(list.ScrollBox, list, 6, 8, 18, 8)
	local entries = {}
	for i, name in ipairs({ "Warsong Outriders", "Durotar Levelers", "Croc Hunters" }) do
		local entry = Row(B, list.ScrollBox, 52)
		entry.Background = B.texture(entry, "BACKGROUND")
		entry.Selection = B.texture(entry, "BACKGROUND")
		entry.Selection:SetShown(i == 1)
		entry.Icon = Icon(B, entry, ICONS[16 + i])
		entry.Icon:ClearAllPoints()
		entry.Icon:SetPoint("LEFT", entry, "LEFT", 6, 0)
		entry.Icon:SetSize(40, 40)
		entry.IconRing = B.texture(entry, "OVERLAY")
		entry.Name = Text(B.text(entry), name, "LEFT", entry, "LEFT", 54, 0)
		entries[i] = entry
		list.ScrollBox.AddRow(entry, {})
	end
	Stack(entries, list.ScrollBox, 0, 2)
	for i, key in ipairs({ "StreamDropdown", "GuildMemberListDropdown", "CommunityMemberListDropdown", "CommunitiesListDropdown" }) do
		f[key] = Dropdown(B, f, ({ "Guild", "All members", "All", "Communities" })[i], 160)
		f[key]:SetShown(i <= 2)
	end
	At(f.StreamDropdown, f, 190, 32)
	Anchor(f.GuildMemberListDropdown, f, "TOPRIGHT", -14, -32)
	local members = B.frame("Frame", f)
	f.MemberList = members
	Fill(members, f, 184, 60, 8, 40)
	members.InsetFrame = B.frame("Frame", members)
	members.InsetFrame.NineSlice = B.frame("Frame", members.InsetFrame)
	B.texture(members.InsetFrame.NineSlice)
	members.InsetFrame.Bg = B.texture(members.InsetFrame, "BACKGROUND")
	members.ColumnDisplay = B.frame("Frame", members)
	At(members.ColumnDisplay, members, 0, 0, 620, 22)
	B.texture(members.ColumnDisplay)
	for i, column in ipairs({ "Name", "Level", "Zone", "Rank" }) do
		Text(B.text(members.ColumnDisplay), column, "LEFT", members.ColumnDisplay, "LEFT", ({ 8, 220, 300, 480 })[i], 0)
	end
	members.ScrollBar = ScrollBar(B, members)
	Anchor(members.ScrollBar, members, "TOPRIGHT", -4, -26)
	members.ScrollBar:SetHeight(280)
	members.ScrollBox = ScrollBox(B, members)
	Fill(members.ScrollBox, members, 0, 24, 18, 28)
	members.MemberCount = Text(B.text(members), "24 / 61 online", "BOTTOMLEFT", members, "BOTTOMLEFT", 8, 6)
	members.ShowOfflineButton = Check(B, members, "Show offline members")
	Anchor(members.ShowOfflineButton, members, "BOTTOMRIGHT", -170, 4)
	local rows = {}
	for i, member in ipairs({ { "Thargor", "40", "The Barrens", "Guild Master" }, { "Valerin", "38", "Durotar", "Officer" }, { "Riverglades", "36", "Durotar", "Veteran" }, { "Zul'tak", "33", "Orgrimmar", "Member" }, { "Morgla", "29", "Ashenvale", "Member" }, { "Krek", "27", "Stonetalon", "Initiate" } }) do
		local row = Row(B, members.ScrollBox, 20)
		row.NameFrame = B.frame("Frame", row)
		row.NameFrame:SetAllPoints(row)
		row.NameFrame.Name = Text(B.text(row.NameFrame), member[1], "LEFT", row.NameFrame, "LEFT", 28, 0)
		row.Class = Icon(B, row, ICONS[i])
		row.Class:ClearAllPoints()
		row.Class:SetPoint("LEFT", row, "LEFT", 6, 0)
		row.Class:SetSize(16, 16)
		row.Level = Text(B.text(row), member[2], "LEFT", row, "LEFT", 220, 0)
		row.Zone = Text(B.text(row), member[3], "LEFT", row, "LEFT", 300, 0)
		row.Rank = Text(B.text(row), member[4], "LEFT", row, "LEFT", 480, 0)
		row:SetHighlightTexture(B.texture(row, "HIGHLIGHT"))
		rows[i] = row
		members.ScrollBox.AddRow(row, {})
	end
	Stack(rows, members.ScrollBox, 0, 2)
	f.Chat = B.frame("Frame", f)
	f.Chat:Hide()
	f.Chat.ScrollBar = ScrollBar(B, f.Chat)
	f.Chat.InsetFrame = B.frame("Frame", f.Chat)
	f.Chat.InsetFrame.NineSlice = B.frame("Frame", f.Chat.InsetFrame)
	f.Chat.InsetFrame.Bg = B.texture(f.Chat.InsetFrame, "BACKGROUND")
	f.ChatEditBox = EditBox(B, f, "", 400)
	f.ChatEditBox:Hide()
	f.InviteButton = Button(B, f, "Invite", 90)
	Anchor(f.InviteButton, f, "BOTTOMRIGHT", -14, 10)
	f.GuildLogButton = Button(B, f, "Guild Log", 90)
	Anchor(f.GuildLogButton, f, "BOTTOMRIGHT", -110, 10)
	f.CommunitiesControlFrame = B.frame("Frame", f)
	f.CommunitiesControlFrame.GuildControlButton = Button(B, f.CommunitiesControlFrame, "Guild Control", 110)
	Anchor(f.CommunitiesControlFrame.GuildControlButton, f, "BOTTOMLEFT", 190, 10)
	f.GuildBenefitsFrame = B.frame("Frame", f)
	f.GuildBenefitsFrame:Hide()
	B.texture(f.GuildBenefitsFrame)
	f.GuildDetailsFrame = B.frame("Frame", f)
	f.GuildDetailsFrame:Hide()
	return f, { bounds = { f, f.ChatTab } }
end

-- The friends list (Camelot/FriendsFrame.xml:390, 385 by 424).
function build.friends(env, B)
	local f = Window(B, "FriendsFrame", nil, 385, 424, "Friends", { inset = { top = 94, bottom = 36 } })
	At(f, env.UIParent, 120, 120)
	env.FriendsFrameTitleText = f.TitleContainer.TitleText
	f.Tabs = {}
	f.numTabs = 3
	for i, label in ipairs({ "Friends", "Who", "Raid" }) do
		local tab = Tab(B, f, label, "FriendsFrameTab" .. i)
		Anchor(tab, f, "BOTTOMLEFT", 12 + (i - 1) * 84, -22)
		f.Tabs[i] = tab
	end
	f.Tabs[1]:Disable()
	local header = B.frame("Frame", f, "FriendsTabHeader")
	f.FriendsTabHeader = header
	Fill(header, f, 0, TITLE_HEIGHT, 0, 330)
	header.TabSystem = TabSystem(B, header, { "Friends", "Recent Allies" })
	for i, tab in ipairs(header.TabSystem.tabs) do
		At(tab, header, 12 + (i - 1) * 96, 6)
	end
	header.StatusDropdown = Dropdown(B, header, "Online", 110)
	Anchor(header.StatusDropdown, header, "TOPRIGHT", -12, -6)
	local bnet = B.frame("Frame", header)
	header.BattlenetFrame = bnet
	At(bnet, header, 12, 36, 361, 26)
	B.texture(bnet, "BACKGROUND")
	bnet.Tag = Text(B.text(bnet), "Valerin#1842", "LEFT", bnet, "LEFT", 8, 0)
	bnet.UnavailableLabel = B.text(bnet)
	bnet.UnavailableLabel:Hide()
	bnet.BroadcastFrame = B.frame("Frame", bnet)
	bnet.BroadcastFrame:Hide()
	bnet.BroadcastFrame.Border = B.frame("Frame", bnet.BroadcastFrame)
	bnet.BroadcastFrame.EditBox = EditBox(B, bnet.BroadcastFrame, "", 200)
	bnet.BroadcastFrame.UpdateButton = Button(B, bnet.BroadcastFrame, "Update", 80)
	bnet.BroadcastFrame.CancelButton = Button(B, bnet.BroadcastFrame, "Cancel", 80)
	local list = B.frame("Frame", f, "FriendsListFrame")
	list:SetAllPoints(f.Inset)
	list.ScrollBar = ScrollBar(B, list)
	Anchor(list.ScrollBar, list, "TOPRIGHT", -4, -4)
	list.ScrollBar:SetHeight(280)
	list.ScrollBox = ScrollBox(B, list)
	Fill(list.ScrollBox, list, 4, 4, 18, 4)
	local rows = {}
	local function Header(title)
		local row = Row(B, list.ScrollBox, 20)
		row.Title = Text(B.text(row), title, "LEFT", row, "LEFT", 8, 0)
		rows[#rows + 1] = row
		list.ScrollBox.AddRow(row, {})
	end
	local function Friend(name, info, online)
		local row = Row(B, list.ScrollBox, 34)
		row.background = Colour(B, row, "BACKGROUND", 0, 0.3, 0.55, online and 0.25 or 0.1)
		row.background:SetAllPoints(row)
		row.status = Colour(B, row, "ARTWORK", online and 0.3 or 0.5, online and 0.8 or 0.5, online and 0.3 or 0.5)
		Anchor(row.status, row, "LEFT", 6, 0)
		row.status:SetSize(12, 12)
		row.gameIcon = Icon(B, row, ICONS[3])
		row.gameIcon:ClearAllPoints()
		row.gameIcon:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		row.gameIcon:SetSize(24, 24)
		row.name = Text(B.text(row), name, "TOPLEFT", row, "TOPLEFT", 24, -3)
		row.info = Text(B.text(row), info, "BOTTOMLEFT", row, "BOTTOMLEFT", 24, 4)
		row:SetHighlightTexture(B.texture(row, "HIGHLIGHT"))
		rows[#rows + 1] = row
		list.ScrollBox.AddRow(row, {})
	end
	Header("Online")
	Friend("Thargor", "Level 40 Orc Warrior, The Barrens", true)
	Friend("Riverglades", "Level 36 Troll Hunter, Durotar", true)
	Friend("Shazi", "World of Warcraft: Forever", true)
	local divider = Row(B, list.ScrollBox, 12)
	B.texture(divider)
	rows[#rows + 1] = divider
	list.ScrollBox.AddRow(divider, {})
	Header("Offline")
	Friend("Morgla", "Last online 2 days ago", false)
	Friend("Krek", "Last online 1 week ago", false)
	Stack(rows, list.ScrollBox, 0, 2)
	local add = Button(B, list, "Add Friend", 110)
	env.FriendsFrameAddFriendButton = add
	Anchor(add, f, "BOTTOMLEFT", 10, 10)
	local whisper = Button(B, list, "Send Message", 110)
	env.FriendsFrameSendMessageButton = whisper
	Anchor(whisper, f, "BOTTOMRIGHT", -10, 10)
	local ignore = Window(B, nil, f, 200, 300, "Ignore")
	f.IgnoreListWindow = ignore
	ignore.UnignorePlayerButton = Button(B, ignore, "Stop Ignoring", 110)
	ignore.ScrollBar = ScrollBar(B, ignore)
	ignore.ScrollBox = ScrollBox(B, ignore)
	local raid = B.frame("Frame", f, "RaidFrame")
	raid:Hide()
	Check(B, raid, "All assist", "RaidFrameAllAssistCheckButton")
	env.RaidFrameConvertToRaidButton = Button(B, raid, "Convert to Raid", 110)
	env.RaidFrameRaidInfoButton = Button(B, raid, "Raid Info", 90)
	return f, { bounds = { f, f.Tabs[1] } }
end

-- The Legacy window (Blizzard_LegacySystem.xml:5, 920 by 575) on its reward track page.
function build.legacy(env, B)
	local f = Window(B, "LegacySystemFrame", nil, 920, 575, "Legacy")
	At(f, env.UIParent, 100, 100)
	f.Tabs = {}
	for i = 1, 3 do
		local tab = SideTab(B, f, ICONS[9 + i])
		Anchor(tab, f, "TOPLEFT", -36, -(TITLE_HEIGHT + 8 + (i - 1) * 38))
		tab:SetChecked(i == 1)
		f.Tabs[i] = tab
	end
	local track = B.frame("Frame", f)
	f.RewardTrackPage = track
	Fill(track, f, 0, TITLE_HEIGHT, 0, 0)
	track.Background = B.texture(track, "BACKGROUND")
	track.Points = Text(B.text(track), "1,240", "TOPLEFT", track, "TOPLEFT", 30, -20)
	track.PointsLabel = Text(B.text(track), "Legacy points", "TOPLEFT", track, "TOPLEFT", 30, -52)
	track.ProgressBarBackground = B.texture(track)
	local bar = StatusBar(B, track, 760, 18, 0.64)
	track.LegacyRewardProgressBar = bar
	Anchor(bar, track, "TOP", 0, -90)
	bar.ProgressBarFrame = B.texture(bar, "OVERLAY")
	bar.Text = Text(B.text(bar), "6,400 / 10,000 to the next reward", "CENTER", bar)
	for i = 1, 5 do
		local card = Colour(B, track, "ARTWORK", 0.08, 0.09, 0.1, 0.9)
		At(card, track, 40 + (i - 1) * 172, 140, 150, 220)
		Text(B.text(track), ({ "Tabard of the Legacy", "Riding Crocolisk", "Title: Enduring", "Bag of Relics", "Heirloom Chest" })[i], "TOP", track, "TOP", -400 + (i - 1) * 172, -370)
	end
	local challenges = B.frame("Frame", f)
	f.ChallengesPage = challenges
	challenges:Hide()
	challenges.Background = B.texture(challenges, "BACKGROUND")
	challenges.CategoryList = B.frame("Frame", challenges)
	challenges.CategoryList.FilterDropdown = Dropdown(B, challenges.CategoryList, "All", 100)
	challenges.CategoryList.SearchBox = EditBox(B, challenges.CategoryList, "", 100)
	challenges.CategoryList.ScrollBar = ScrollBar(B, challenges.CategoryList)
	challenges.DetailPane = B.frame("Frame", challenges)
	challenges.DetailPane.ScrollBar = ScrollBar(B, challenges.DetailPane)
	challenges.LegacyChallengePointSummary = B.frame("Frame", challenges)
	challenges.LegacyChallengePointSummary.ProgressBarBackground = B.texture(challenges.LegacyChallengePointSummary)
	challenges.LegacyChallengePointSummary.PointsBar = StatusBar(B, challenges.LegacyChallengePointSummary, 200, 14, 0.3)
	challenges.VerticalDivider = B.frame("Frame", challenges)
	B.texture(challenges.VerticalDivider)
	local tree = B.frame("Frame", f)
	f.TreePage = tree
	tree:Hide()
	tree.Background = B.texture(tree, "BACKGROUND")
	tree.VerticalDivider = B.frame("Frame", tree)
	tree.LegacyTreeTraitPanel = B.frame("Frame", tree)
	tree.LegacyTreeTraitPanel.ApplyButton = Button(B, tree.LegacyTreeTraitPanel, "Apply", 80)
	tree.LegacyTreeTraitPanel.SearchBox = EditBox(B, tree.LegacyTreeTraitPanel, "", 100)
	tree.LegacyTreePointSummary = B.frame("Frame", tree)
	tree.LegacyTreePointSummary.Border = B.texture(tree.LegacyTreePointSummary)
	tree.LegacyTreePointSummary.AvailablePointsLabel = B.text(tree.LegacyTreePointSummary)
	return f, { bounds = { f, f.Tabs[1] } }
end

-- An ItemButton: icon, quality border, normal texture and count.
local function ItemButton(B, parent, id, size)
	local button = Item(B, parent, id, size)
	button.NormalTexture = B.texture(button)
	button.Count = B.text(button)
	button.Count:Hide()
	return button
end

-- The loot window (Mainline/LootFrame.xml:117, 220 by 290) with its item rows.
function build.loot(env, B)
	local f = Window(B, "LootFrame", nil, 220, 290, "Loot")
	At(f, env.UIParent, 160, 160)
	f.ClosePanelButton = f.CloseButton
	f.CloseButton = nil
	f.ScrollBar = ScrollBar(B, f)
	Anchor(f.ScrollBar, f, "TOPRIGHT", -6, -TITLE_HEIGHT - 6)
	f.ScrollBar:SetHeight(240)
	local box = ScrollBox(B, f)
	f.ScrollBox = box
	Fill(box, f, 6, TITLE_HEIGHT + 6, 18, 6)
	local upper, lower = B.texture(box, "OVERLAY"), B.texture(box, "OVERLAY")
	function box.GetUpperShadowTexture()
		return upper
	end
	function box.GetLowerShadowTexture()
		return lower
	end
	local rows = {}
	for i, drop in ipairs({ { "Crocolisk Hide", "Epic", 4, ICONS[1] }, { "Riverglade Fang", "Rare", 3, ICONS[2] }, { "Rugged Hide", "Uncommon", 2, ICONS[3] }, { "Linen Cloth", "Common", 1, ICONS[4] }, { "14 Silver 32 Copper", nil, 1, ICONS[5] } }) do
		local row = Row(B, box, 44)
		row.NameFrame = B.texture(row, "BACKGROUND")
		row.BorderFrame = B.texture(row, "BORDER")
		row.IconQuestTexture = B.texture(row, "OVERLAY")
		row.IconQuestTexture:Hide()
		row.HighlightNameFrame = B.texture(row, "OVERLAY")
		row.HighlightNameFrame:Hide()
		row.PushedNameFrame = B.texture(row, "OVERLAY")
		row.Text = Text(B.text(row), drop[1], "TOPLEFT", row, "TOPLEFT", 48, -6)
		if drop[2] then
			row.QualityStripe = B.texture(row, "BACKGROUND")
			row.QualityText = Text(B.text(row), drop[2], "BOTTOMLEFT", row, "BOTTOMLEFT", 48, 6)
		end
		row.Item = ItemButton(B, row, drop[4], 36)
		Anchor(row.Item, row, "LEFT", 4, 0)
		row.Item:SetFrameLevel(row:GetFrameLevel())
		local data = { slotIndex = i, quality = drop[3] }
		function row.GetElementData()
			return data
		end
		rows[i] = row
		box.AddRow(row, data)
	end
	Stack(rows, box, 0, 4)
	return f, {}
end

-- Group loot rolls (GroupLootFrame.xml:292, 277 by 67), two of them stacked as GroupLootContainer stacks them.
function build.lootrolls(env, B)
	local rolls = {}
	local qualities = {}
	env.GetLootRollItemInfo = function(rollID)
		return ICONS[1], "Crocolisk Hide", 1, qualities[rollID]
	end
	env.GroupLootFrame_SetupItemDisplay = function() end
	for i = 1, 4 do
		local f = B.frame("Frame", nil, "GroupLootFrame" .. i)
		f:SetSize(277, 67)
		f:SetFrameLevel(1)
		Anchor(f, env.UIParent, "CENTER", 0, 200 - (i - 1) * 75)
		f.Background = B.texture(f, "BACKGROUND")
		f.Border = B.texture(f, "BORDER")
		f.Name = Text(B.text(f), ({ "Crocolisk Hide", "Riverglade Fang" })[i] or "", "TOPLEFT", f, "TOPLEFT", 56, -10)
		local icon = B.frame("Button", f)
		f.IconFrame = icon
		At(icon, f, 10, 10, 36, 36)
		icon.Icon = Icon(B, icon, ICONS[i])
		icon.Count = B.text(icon)
		icon.Count:Hide()
		icon.Border = B.texture(icon, "OVERLAY")
		local timer = B.frame("StatusBar", f)
		f.Timer = timer
		At(timer, f, 56, 36, 190, 8)
		timer.Background = B.texture(timer, "BACKGROUND")
		timer:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
		B.add(timer:GetStatusBarTexture())
		timer:SetStatusBarColor(1, 1, 0)
		timer:SetMinMaxValues(0, 60000)
		timer:SetValue(i == 1 and 38000 or 52000)
		f.LootButtonContainer = B.frame("Frame", f)
		At(f.LootButtonContainer, f, 56, 46, 190, 18)
		for n, key in ipairs({ "NeedButton", "GreedButton", "PassButton" }) do
			local button = B.frame("Button", f.LootButtonContainer)
			At(button, f.LootButtonContainer, (n - 1) * 24, 0, 18, 18)
			button.Art = Icon(B, button, ICONS[12 + n])
			f.LootButtonContainer[key] = button
		end
		f.rollID = i
		qualities[i] = ({ 4, 3 })[i]
		f:SetShown(i <= 2)
		f:Hide()
		rolls[i] = f
	end
	return rolls[1], { show = { rolls[1], rolls[2] }, bounds = { rolls[1], rolls[2] } }
end

-- A StaticPopup (GameDialog.xml:52, 320 wide) asking to destroy an item, as the game shows it.
function build.popups(env, B)
	local popups = {}
	for i = 1, 4 do
		local f = B.frame("Frame", nil, "StaticPopup" .. i)
		f:SetSize(320, 150)
		Anchor(f, env.UIParent, "TOP", 0, -140 - (i - 1) * 160)
		f.BG = B.frame("Frame", f)
		f.BG:SetAllPoints(f)
		f.BG.Top, f.BG.Bottom = B.texture(f.BG, "BACKGROUND"), B.texture(f.BG, "BACKGROUND")
		f.Text = Text(B.text(f), "Do you want to destroy Rugged Hide?", "TOP", f, "TOP", 0, -16)
		f.AlertIcon = B.texture(f)
		f.AlertIcon:Hide()
		f.CloseButton = B.frame("Button", f)
		Anchor(f.CloseButton, f, "TOPRIGHT", -4, -4)
		f.CloseButton:SetSize(CLOSE, CLOSE)
		f.CloseButton.Art = B.texture(f.CloseButton)
		f.ButtonContainer = B.frame("Frame", f)
		Anchor(f.ButtonContainer, f, "BOTTOM", 0, 14)
		f.ButtonContainer:SetSize(300, BUTTON_HEIGHT)
		for n = 1, 4 do
			local button = Button(B, f.ButtonContainer, ({ "Yes", "No" })[n] or "", 120)
			f.ButtonContainer["Button" .. n] = button
			if n <= 2 then
				Anchor(button, f.ButtonContainer, n == 1 and "LEFT" or "RIGHT", n == 1 and 20 or -20, 0)
			else
				button:Hide()
			end
		end
		f.ExtraButton = Button(B, f, "", 100)
		f.ExtraButton:Hide()
		f.EditBox = EditBox(B, f, "", 200)
		f.EditBox.Left, f.EditBox.Right = B.texture(f.EditBox), B.texture(f.EditBox)
		f.EditBox.NineSlice = B.frame("Frame", f.EditBox)
		B.texture(f.EditBox.NineSlice)
		f.EditBox:Hide()
		f.Dropdown = Dropdown(B, f, "", 120)
		f.Dropdown:Hide()
		f.MoneyInputFrame = B.frame("Frame", f)
		f.MoneyInputFrame:Hide()
		for _, key in ipairs({ "gold", "silver", "copper" }) do
			local coin = EditBox(B, f.MoneyInputFrame, "", 40)
			coin.texture = B.texture(coin)
			f.MoneyInputFrame[key] = coin
		end
		local item = B.frame("Frame", f)
		f.ItemFrame = item
		Anchor(item, f, "TOP", -40, -50)
		item:SetSize(200, 40)
		item.NameFrame = B.texture(item)
		item.Text = Text(B.text(item), "Rugged Hide", "LEFT", item, "LEFT", 48, 0)
		item.Text:SetTextColor(0.12, 1, 0)
		item.Item = ItemButton(B, item, ICONS[3], 36)
		Anchor(item.Item, item, "LEFT", 0, 0)
		f:Hide()
		popups[i] = f
	end
	return popups[1], {}
end

-- The ready check (Mainline/ReadyCheck.xml:16, 323 by 112): the listener dialog on ReadyCheckFrame.
function build.readycheck(env, B)
	local f = B.frame("Frame", nil, "ReadyCheckFrame")
	f:SetSize(323, 112)
	Anchor(f, env.UIParent, "TOP", 0, -160)
	f:Hide()
	local listener = B.frame("Frame", f, "ReadyCheckListenerFrame")
	listener:SetAllPoints(f)
	listener.Bg = B.texture(listener, "BACKGROUND")
	listener.NineSlice = B.frame("Frame", listener)
	listener.NineSlice:SetAllPoints(listener)
	B.texture(listener.NineSlice)
	listener.TitleContainer = B.frame("Frame", listener)
	At(listener.TitleContainer, listener, 0, 0, 323, TITLE_HEIGHT)
	listener.TitleContainer.TitleText = Text(B.text(listener.TitleContainer), "Ready Check", "CENTER", listener.TitleContainer)
	listener.PortraitContainer = B.frame("Frame", listener)
	listener.PortraitContainer.Portrait = B.texture(listener.PortraitContainer, "BACKGROUND")
	listener.Text = Text(B.text(listener), "Thargor has initiated a ready check.", "TOP", listener, "TOP", 0, -40)
	listener.YesButton = Button(B, listener, "Ready", 120)
	Anchor(listener.YesButton, listener, "BOTTOMLEFT", 24, 14)
	listener.NoButton = Button(B, listener, "Not Ready", 120)
	Anchor(listener.NoButton, listener, "BOTTOMRIGHT", -24, 14)
	return f, { show = { f, listener } }
end

-- Build(key, env, B) -> frame, parts for one window of Windows.LIST.
function Windows.Build(key, env, B)
	local builder = assert(build[key], "no stand-in window " .. tostring(key))
	local frame, parts = builder(env, B)
	parts = parts or {}
	parts.show = parts.show or { frame }
	parts.bounds = parts.bounds or { frame }
	return frame, parts
end

function Windows.Spec(key)
	for _, spec in ipairs(Windows.LIST) do
		if spec.key == key then
			return spec
		end
	end
	error("no window " .. tostring(key))
end

return Windows
