-- Settings.lua: the chat's settings: their defaults, the module accent and the rows of its settings page.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L
local Format = ns.Format

local NAME = "Chat"
ns.NAME = NAME

local MAX_ABBREVIATION = 6
local OPACITY_MIN, OPACITY_MAX, OPACITY_STEP = 0, 1, 0.05
local FONT_MIN, FONT_MAX = 8, 24
local TAB_FONT_MIN, TAB_FONT_MAX = 8, 16
local FADE_MIN, FADE_MAX, FADE_STEP = 10, 600, 10
local SPACING_MIN, SPACING_MAX = 0, 10
local HISTORY_MIN, HISTORY_MAX, HISTORY_STEP = 10, 500, 10
local FOLLOW = -1
ns.HISTORY_MAX = HISTORY_MAX
ns.FOLLOW = FOLLOW
ns.FONT_MIN, ns.FONT_MAX = FONT_MIN, FONT_MAX
ns.SPACING_MIN, ns.SPACING_MAX = SPACING_MIN, SPACING_MAX

local function Rgb(name)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b }
end

local _, _, _, SURFACE_ALPHA = Tokens.Color("surface")

local defaults = {
	framing = "auto",
	panelOpacity = SURFACE_ALPHA,
	shadow = true,
	buttons = false,
	sideHover = false,
	sideRight = false,
	sideWidth = 35,
	sideIcons = { menu = true, channels = true, voice = true, friends = true },
	sideStyle = "card",
	sideGap = 8,
	sideOrder = "channels,voice,menu",
	sideScale = 1,
	sideSpacing = 2,
	sideFree = false,
	sidePositions = {},
	sideScroll = false,
	copyButton = true,
	editBox = "typing",
	inputOnTop = false,
	lockSize = false,
	editHeight = 22,
	idleFade = false,
	idleDelay = 15,
	idleStrength = 0.4,
	idleWake = { emotes = false, skills = false, reputation = false, loot = false, system = false, achievements = false, npc = false },
	font = "",
	fontSize = FOLLOW,
	lineSpacing = FOLLOW,
	fontOutline = "none",
	fade = true,
	fadeTime = 120,
	history = true,
	historyLines = 100,
	tabStyle = "underline",
	tabCase = "upper",
	tabFontSize = 12,
	tabFont = "",
	tabHeight = 34,
	tabsAbove = false,
	tabSpacing = 13.5,
	tabPadding = 6,
	tabOpacity = 1,
	tabEdge = "accent",
	accentSource = "class",
	accentColor = Rgb("accentDefault"),
	timestamp = "none",
	timestampColor = Rgb("text"),
	channels = "short",
	numbers = "name",
	abbr = {
		guild = L["G"],
		officer = L["O"],
		party = L["P"],
		partyLeader = L["PL"],
		raid = L["R"],
		raidLeader = L["RL"],
		raidWarning = L["RW"],
		instance = L["I"],
		instanceLeader = L["IL"],
	},
	classNames = true,
	classMentions = false,
	urls = true,
	linkTooltips = false,
}
local IDLE_WAKE = { "emotes", "skills", "reputation", "loot", "system", "achievements", "npc" }
ns.defaults = defaults

function ns.Settings()
	return K.Store.Module(NAME)
end

function ns.TextSize(settings)
	local size = settings.fontSize
	if size == FOLLOW then
		return Tokens.TypeDefault("chatSize")
	end
	return size
end

function ns.LineSpacing(settings)
	local spacing = settings.lineSpacing
	if spacing == FOLLOW then
		return Tokens.TypeDefault("chatSpacing")
	end
	return spacing
end

local function ShownSize(value)
	return value == FOLLOW and Tokens.TypeDefault("chatSize") or value
end

local function ShownSpacing(value)
	return value == FOLLOW and Tokens.TypeDefault("chatSpacing") or value
end

local function IsUnit(v)
	return not Format.IsSecret(v) and type(v) == "number" and v >= 0 and v <= 1
end

function ns.Accent(settings)
	settings = settings or ns.Settings()
	local c = settings.accentColor
	if settings.accentSource == "custom" and type(c) == "table" and IsUnit(c.r) and IsUnit(c.g) and IsUnit(c.b) then
		return c.r, c.g, c.b
	end
	return K.Theme.Accent()
end

local TIMESTAMP_LABELS = {
	["none"] = L["None"],
	["%H:%M"] = L["24-hour, 14:31"],
	["%H:%M:%S"] = L["24-hour with seconds, 14:31:05"],
	["%I:%M %p"] = L["12-hour, 02:31 PM"],
	["%I:%M:%S %p"] = L["12-hour with seconds, 02:31:05 PM"],
	["%I:%M"] = L["12-hour, 02:31"],
	["%I:%M:%S"] = L["12-hour with seconds, 02:31:05"],
}

local ABBREVIATION_LABELS = {
	guild = L["Guild"],
	officer = L["Officer"],
	party = L["Party"],
	partyLeader = L["Party leader"],
	raid = L["Raid"],
	raidLeader = L["Raid leader"],
	raidWarning = L["Raid warning"],
	instance = L["Instance"],
	instanceLeader = L["Instance leader"],
}

local function Fades(s)
	return s.fade == true
end

local function Keeps(s)
	return s.history == true
end

local function IsShort(s)
	return s.channels == "short"
end

local function HasTimestamp(s)
	return s.timestamp ~= "none"
end

local function IsCustom(s)
	return s.accentSource == "custom"
end

local function Idles(s)
	return s.idleFade == true
end

local function Filled(s)
	return s.tabStyle == "filled"
end

local function Sided(s)
	return s.buttons == true
end

local function Beside(s)
	return s.buttons == true and (s.sideStyle == "glass" or s.sideStyle == "bare")
end

local SIDE_ICONS = { "menu", "channels", "voice", "friends" }
local ICON_LABELS = { menu = L["Chat menu button"], channels = L["Channels button"], voice = L["Voice buttons"], friends = L["Friends button"] }
local ORDER_NAMES = { channels = L["Channels"], voice = L["Voice"], menu = L["Menu"] }
local ORDERS = { "channels,voice,menu", "channels,menu,voice", "voice,channels,menu", "voice,menu,channels", "menu,channels,voice", "menu,voice,channels" }

local WAKE_LABELS = {
	emotes = L["Wake on emotes"],
	skills = L["Wake on skill-ups and experience"],
	reputation = L["Wake on reputation and honour"],
	loot = L["Wake on loot and money"],
	system = L["Wake on system messages"],
	achievements = L["Wake on achievements"],
	npc = L["Wake on NPC speech"],
}

local function Append(schema, rows)
	for _, row in ipairs(rows) do
		schema[#schema + 1] = row
	end
end

local function TabFonts()
	local list = K.Widgets.MediaOptions("font")
	table.insert(list, 1, { value = "", label = L["Caps face"] })
	return list
end

function ns.Schema()
	local timestamps = {}
	for i, choice in ipairs(Format.TIMESTAMPS) do
		timestamps[i] = { value = choice.value, label = TIMESTAMP_LABELS[choice.value] or choice.value }
	end
	local schema = {
		{ type = "header", label = L["Panel"] },
		{
			type = "dropdown", key = "framing", label = L["Framing"],
			help = L["A card with tabs, or text on a soft shadow with tabs on hover. Auto: card in Frames, bare in Orbs."],
			options = {
				{ value = "auto", label = L["Follow the HUD style"] },
				{ value = "card", label = L["Framed card"] },
				{ value = "bare", label = L["Text on a soft shadow"] },
			},
		},
		{
			type = "slider", key = "panelOpacity", label = L["Glass opacity"],
			help = L["How solid the glass behind the chat looks. The text stays fully visible."],
			min = OPACITY_MIN, max = OPACITY_MAX, step = OPACITY_STEP,
		},
		{
			type = "toggle", key = "shadow", label = L["Panel shadow"],
			help = L["Draws a soft shadow around the chat panel."],
		},
		{
			type = "toggle", key = "copyButton", label = L["Copy button"],
			help = L["A small copy glyph beside the plus in the tab row. A tab's right-click menu can copy too."],
		},
		{
			type = "dropdown", key = "editBox", label = L["Edit box"],
			help = L["Show the box you type in only while you type, or keep the game's resting box under the messages."],
			options = { { value = "typing", label = L["Only while typing"] }, { value = "always", label = L["Always shown"] } },
		},
		{
			type = "toggle", key = "buttons", label = L["Chat buttons"],
			help = L["Shows the game's chat menu, channel buttons and friends button beside the chat."],
		},
		{ type = "toggle", key = "sideHover", label = L["Chat buttons on hover"], help = L["Shows the chat buttons only while the pointer is over the chat."], showWhen = Sided },
		{ type = "toggle", key = "sideRight", label = L["Chat buttons on the right"], help = L["Puts the chat buttons on the right side of the card."], showWhen = Sided },
		{ type = "slider", key = "sideWidth", label = L["Chat button room"], help = L["The room the card keeps for the chat buttons, and their column's width, in units."], min = 32, max = 100, step = 1, showWhen = Sided },
		{
			type = "dropdown", key = "sideStyle", label = L["Chat button backing"], showWhen = Sided,
			help = L["In the card, on their own glass beside it, or beside it with no glass."],
			options = { { value = "card", label = L["In the card"] }, { value = "glass", label = L["Own glass beside the card"] }, { value = "bare", label = L["Beside the card, no glass"] } },
		},
		{ type = "slider", key = "sideGap", label = L["Chat button gap"], help = L["The gap between the card and the chat buttons beside it, in units."], min = 0, max = 30, step = 1, showWhen = Beside },
	}
	for _, key in ipairs(SIDE_ICONS) do
		schema[#schema + 1] = { type = "toggle", key = "sideIcons." .. key, label = ICON_LABELS[key], help = L["Shows this button among the chat buttons."], showWhen = Sided }
	end
	local orders = {}
	for i, order in ipairs(ORDERS) do
		local names = {}
		for id in order:gmatch("%a+") do names[#names + 1] = ORDER_NAMES[id] end
		orders[i] = { value = order, label = table.concat(names, ", ") }
	end
	Append(schema, {
		{ type = "dropdown", key = "sideOrder", label = L["Chat button order"], help = L["The order of the buttons down the column. The last one sits at the foot."], options = orders, showWhen = Sided },
		{ type = "slider", key = "sideScale", label = L["Chat button size"], help = L["Scales the chat buttons."], min = 0.5, max = 2, step = 0.05, showWhen = Sided },
		{ type = "slider", key = "sideSpacing", label = L["Chat button spacing"], help = L["The gap between stacked chat buttons, in units."], min = 0, max = 30, step = 1, showWhen = Sided },
		{ type = "toggle", key = "sideFree", label = L["Move chat buttons freely"], help = L["Shift-drag a chat button anywhere, out of combat. Off returns every button to the column."], showWhen = Sided },
		{ type = "toggle", key = "sideScroll", label = L["Scroll button with the chat buttons"], help = L["Moves the jump-to-bottom button from the card's corner to the foot of the chat buttons."], showWhen = Sided },
		{ type = "toggle", key = "inputOnTop", label = L["Input on top"], help = L["Place the typing box above chat messages, below the tabs."] },
		{ type = "slider", key = "editHeight", label = L["Edit box tile height"], help = L["The height of the tile drawn behind the text you type, in units."], min = 16, max = 30, step = 1 },
		{ type = "toggle", key = "lockSize", label = L["Lock chat size"], help = L["Hides the size grip on docked chat windows, so the chat resizes only in Layout Mode."] },
		{ type = "header", label = L["Idle fade"] },
		{ type = "toggle", key = "idleFade", label = L["Fade when idle"], help = L["The whole chat fades after a quiet spell. Hovering, typing or new player chat brings it back."] },
		{ type = "slider", key = "idleDelay", label = L["Idle after"], help = L["Seconds without new chat, hovering or typing before the chat fades."], min = 5, max = 60, step = 1, showWhen = Idles },
		{ type = "slider", key = "idleStrength", label = L["Idle fade strength"], help = L["How far the idle chat fades. 1 hides it until it wakes."], min = 0.05, max = 1, step = 0.05, showWhen = Idles },
	})
	for _, key in ipairs(IDLE_WAKE) do
		schema[#schema + 1] = { type = "toggle", key = "idleWake." .. key, label = WAKE_LABELS[key], help = L["Player chat and whispers always wake the chat; these lines wake it too."], showWhen = Idles }
	end
	Append(schema, {
		{ type = "header", label = L["Text"] },
		{
			type = "font", key = "font", label = L["Font"],
			options = K.Widgets.InheritedFontOptions,
			help = L["The font of chat messages and the edit box. Tabs use the caps face."],
		},
		{
			type = "slider", key = "fontSize", label = L["Text size"],
			help = L["The size of chat messages and the edit box."],
			min = FONT_MIN, max = FONT_MAX, step = 1, shown = ShownSize,
		},
		{
			type = "slider", key = "lineSpacing", label = L["Line spacing"],
			help = L["Extra space between chat lines, in units."],
			min = SPACING_MIN, max = SPACING_MAX, step = 0.5, shown = ShownSpacing,
		},
		{
			type = "dropdown", key = "fontOutline", label = L["Outline"],
			help = L["An outline instead of the soft shadow, for busy backgrounds."],
			options = {
				{ value = "none", label = L["None, soft shadow"] },
				{ value = "OUTLINE", label = L["Thin"] },
				{ value = "THICKOUTLINE", label = L["Thick"] },
			},
		},
		{
			type = "toggle", key = "fade", label = L["Fade old messages"],
			help = L["Old lines fade out when nothing new arrives. Scroll or hover to see them."],
		},
		{
			type = "slider", key = "fadeTime", label = L["Fade after"],
			help = L["Seconds a line stays before it fades."],
			min = FADE_MIN, max = FADE_MAX, step = FADE_STEP, showWhen = Fades,
		},
		{
			type = "toggle", key = "history", label = L["Keep chat across sessions"],
			help = L["Each window's last lines come back after a reload or relog. Turning this off forgets them."],
		},
		{
			type = "slider", key = "historyLines", label = L["Lines kept per window"],
			help = L["How many of each window's newest lines come back. The combat log is never kept."],
			min = HISTORY_MIN, max = HISTORY_MAX, step = HISTORY_STEP, showWhen = Keeps,
		},
		{ type = "header", label = L["Tabs"] },
		{
			type = "dropdown", key = "tabStyle", label = L["Tab style"],
			help = L["How the selected tab stands out."],
			options = {
				{ value = "plain", label = L["Gold text"] },
				{ value = "underline", label = L["Gilt underline"] },
				{ value = "filled", label = L["Filled tile"] },
				{ value = "minimal", label = L["Bright text only"] },
			},
		},
		{
			type = "dropdown", key = "tabCase", label = L["Tab names"],
			help = L["Shows tab names in capitals or as you typed them."],
			options = { { value = "upper", label = L["Capitals"] }, { value = "normal", label = L["As typed"] } },
		},
		{
			type = "slider", key = "tabFontSize", label = L["Tab text size"],
			help = L["The size of the tab names. The default is the caps size."],
			min = TAB_FONT_MIN, max = TAB_FONT_MAX, step = 1,
		},
		{ type = "font", key = "tabFont", label = L["Tab font"], options = TabFonts, help = L["The font of the tab names. The default is the caps face."] },
		{ type = "slider", key = "tabHeight", label = L["Tab row height"], help = L["The height of the tab row above the messages, in units."], min = 24, max = 48, step = 1 },
		{ type = "toggle", key = "tabsAbove", label = L["Tabs above the card"], help = L["The card starts below the tab row, so the tabs sit above it."] },
		{ type = "slider", key = "tabSpacing", label = L["Tab spacing"], help = L["The space after each tab name, in units."], min = 4, max = 30, step = 0.5 },
		{ type = "slider", key = "tabPadding", label = L["Tile padding"], help = L["How far the selected tab's tile reaches past its name, up to half the tab spacing."], min = 0, max = 12, step = 0.5, showWhen = Filled },
		{ type = "slider", key = "tabOpacity", label = L["Tile opacity"], help = L["How solid the selected tab's tile looks."], min = 0, max = 1, step = 0.05, showWhen = Filled },
		{
			type = "dropdown", key = "tabEdge", label = L["Tile edge"], showWhen = Filled,
			help = L["The selected tab's tile edge in the accent colour, or matching the chat card's edge."],
			options = { { value = "accent", label = L["Accent colour"] }, { value = "panel", label = L["Card edge"] } },
		},
		{ type = "header", label = L["Accent"] },
		{
			type = "dropdown", key = "accentSource", label = L["Accent colour"],
			help = L["Colours links and the chat's highlights with your class colour or a colour you pick."],
			options = { { value = "class", label = L["Class colour"] }, { value = "custom", label = L["Custom colour"] } },
		},
		{
			type = "color", key = "accentColor", label = L["Custom accent"],
			help = L["The colour the chat uses when the accent is set to a custom colour."],
			showWhen = IsCustom,
		},
		{ type = "header", label = L["Timestamps"] },
		{
			type = "dropdown", key = "timestamp", label = L["Timestamp format"],
			help = L["Off by default. A format stamps player lines and the system lines the game leaves bare."],
			options = timestamps,
		},
		{
			type = "color", key = "timestampColor", label = L["Timestamp colour"],
			help = L["The colour of the time in front of each line."],
			showWhen = HasTimestamp,
		},
		{ type = "header", label = L["Channels"] },
		{
			type = "dropdown", key = "channels", label = L["Channel names"],
			help = L["Shortens [Guild] to [G] and [1. General - Zone] to [1. General]."],
			options = { { value = "short", label = L["Short"] }, { value = "full", label = L["As the game shows them"] } },
		},
		{
			type = "dropdown", key = "numbers", label = L["Numbered channels"],
			help = L["Shows numbered channels by number and name, or by number only."],
			options = { { value = "name", label = L["[1. General]"] }, { value = "number", label = L["[1]"] } },
			showWhen = IsShort,
		},
	})
	for _, key in ipairs(Format.CHANNEL_KEYS) do
		schema[#schema + 1] = {
			type = "text", key = "abbr." .. key, label = ABBREVIATION_LABELS[key],
			help = L["The short name for this channel. Leave it empty to hide the channel."],
			maxLetters = MAX_ABBREVIATION, showWhen = IsShort,
		}
	end
	Append(schema, {
		{ type = "header", label = L["Names and links"] },
		{
			type = "toggle", key = "classNames", label = L["Class-coloured names"],
			help = L["Colours each player's name in chat with their class colour."],
		},
		{ type = "toggle", key = "classMentions", label = L["Class-coloured names in messages"], help = L["Colours your group's names inside say, yell, party, raid and instance messages."] },
		{
			type = "toggle", key = "urls", label = L["Clickable links"],
			help = L["Turns web addresses into links. Click one to copy it."],
		},
		{ type = "toggle", key = "linkTooltips", label = L["Link tooltips on hover"], help = L["Shows an item, spell or quest tooltip while the pointer is over its link in chat."] },
	})
	schema.preview = function(parent)
		return ns.Preview.Build(parent)
	end
	return schema
end
