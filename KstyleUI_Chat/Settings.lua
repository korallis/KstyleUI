-- Settings.lua: the chat's settings: their defaults, the module accent and the rows of its settings page.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L
local Format = ns.Format

local NAME = "Chat"
ns.NAME = NAME

local MAX_ABBREVIATION = 6

local function Rgb(name)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b }
end

local defaults = {
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
			help = L["Shows the time in front of each new line."],
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
	return schema
end
