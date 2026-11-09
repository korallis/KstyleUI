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
ns.HISTORY_MAX = HISTORY_MAX
ns.FONT_MIN, ns.FONT_MAX = FONT_MIN, FONT_MAX
ns.SPACING_MIN, ns.SPACING_MAX = SPACING_MIN, SPACING_MAX

local function Rgb(name)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b }
end

local _, _, _, SURFACE_ALPHA = Tokens.Color("surface")

local defaults = {
	panelOpacity = SURFACE_ALPHA,
	shadow = true,
	buttons = false,
	copyButton = true,
	editBox = "typing",
	font = Tokens.FontPath("SourceSans3Regular"),
	fontSize = 14,
	lineSpacing = 4,
	fontOutline = "none",
	fade = true,
	fadeTime = 120,
	history = true,
	historyLines = 100,
	tabStyle = "underline",
	tabCase = "upper",
	tabFontSize = 13,
	accentSource = "class",
	accentColor = Rgb("accentDefault"),
	timestamp = "%H:%M",
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
	urls = true,
}
ns.defaults = defaults

function ns.Settings()
	return K.Store.Module(NAME)
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

function ns.Schema()
	local timestamps = {}
	for i, choice in ipairs(Format.TIMESTAMPS) do
		timestamps[i] = { value = choice.value, label = TIMESTAMP_LABELS[choice.value] or choice.value }
	end
	local schema = {
		{ type = "header", label = L["Panel"] },
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
			help = L["Shows the game's chat menu and channel buttons beside the chat."],
		},
		{ type = "header", label = L["Text"] },
		{
			type = "font", key = "font", label = L["Font"],
			help = L["The font of chat messages, tabs and the edit box."],
		},
		{
			type = "slider", key = "fontSize", label = L["Text size"],
			help = L["The size of chat messages and the edit box."],
			min = FONT_MIN, max = FONT_MAX, step = 1,
		},
		{
			type = "slider", key = "lineSpacing", label = L["Line spacing"],
			help = L["Extra space between chat lines, in units."],
			min = SPACING_MIN, max = SPACING_MAX, step = 1,
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
				{ value = "underline", label = L["Accent underline"] },
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
			help = L["The size of the tab names."],
			min = TAB_FONT_MIN, max = TAB_FONT_MAX, step = 1,
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
			help = L["Same as Blizzard's chat timestamps. System and loot lines have none."],
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
	}
	for _, key in ipairs(Format.CHANNEL_KEYS) do
		schema[#schema + 1] = {
			type = "text", key = "abbr." .. key, label = ABBREVIATION_LABELS[key],
			help = L["The short name for this channel. Leave it empty to hide the channel."],
			maxLetters = MAX_ABBREVIATION, showWhen = IsShort,
		}
	end
	local tail = {
		{ type = "header", label = L["Names and links"] },
		{
			type = "toggle", key = "classNames", label = L["Class-coloured names"],
			help = L["Colours each player's name in chat with their class colour."],
		},
		{
			type = "toggle", key = "urls", label = L["Clickable links"],
			help = L["Turns web addresses into links. Click one to copy it."],
		},
	}
	for _, row in ipairs(tail) do
		schema[#schema + 1] = row
	end
	schema.preview = function(parent)
		return ns.Preview.Build(parent)
	end
	return schema
end
