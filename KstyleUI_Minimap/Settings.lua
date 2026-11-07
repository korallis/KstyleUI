-- Settings.lua: the minimap's settings: their defaults, the rows of its settings page and checked reads.
local _, ns = ...

local K = KstyleUI
local L, Tokens = K.L, K.Tokens

local Settings = {}
ns.Settings = Settings

local MODULE = "Minimap"
Settings.MODULE = MODULE

local TEXT_MIN, TEXT_MAX, TEXT_STEP = 6, 24, 1
local DELAY_MIN, DELAY_MAX, DELAY_STEP = 3, 30, 1
local OPACITY_MIN, OPACITY_MAX, OPACITY_STEP = 0, 1, 0.05
local BUTTON_MIN, BUTTON_MAX, BUTTON_STEP = 14, 32, 1
local SPACING_MIN, SPACING_MAX, SPACING_STEP = 0, 12, 1
local ICON_MIN, ICON_MAX, ICON_STEP = 16, 40, 1
local COLUMNS_MIN, COLUMNS_MAX, COLUMNS_STEP = 1, 12, 1

local accentR, accentG, accentB = Tokens.Color("accentDefault")

Settings.defaults = {
	enabled = false,
	accent = { source = "class", color = { r = accentR, g = accentG, b = accentB } },
	column = { side = "inside", size = 16, spacing = 9, growth = "down", tracking = true, mail = true, calendar = true, queue = true, drawer = true },
	drawer = { behaviour = "click", direction = "auto", size = 24, spacing = 4, columns = 6, autoClose = true, compartment = true, hideEmpty = true },
	zoom = { wheel = true, reset = false, delay = 10 },
	compass = true,
	strip = { opacity = 0.8 },
	zone = { shown = true, color = "plain", font = "", size = 9, outline = "" },
	clock = { shown = true, mode = "game", font = "", size = 9, outline = "" },
	coords = { shown = false, precision = 1, position = "top", font = "", size = 10, outline = "" },
}

local ACCENT_OPTIONS = {
	{ value = "class", label = L["Class colour"] },
	{ value = "custom", label = L["Custom colour"] },
}
local SIDE_OPTIONS = {
	{ value = "inside", label = L["Inside, on the right edge"] },
	{ value = "left", label = L["Left"] },
	{ value = "right", label = L["Right"] },
}
local BEHAVIOUR_OPTIONS = {
	{ value = "click", label = L["Open on click"] },
	{ value = "hover", label = L["Open on mouseover"] },
	{ value = "open", label = L["Always open"] },
}
local DIRECTION_OPTIONS = {
	{ value = "auto", label = L["Away from the map"] },
	{ value = "left", label = L["Left"] },
	{ value = "right", label = L["Right"] },
	{ value = "up", label = L["Up"] },
	{ value = "down", label = L["Down"] },
}
local GROWTH_OPTIONS = {
	{ value = "down", label = L["From the top, downward"] },
	{ value = "up", label = L["From the bottom, upward"] },
}
local ZONE_COLOR_OPTIONS = {
	{ value = "plain", label = L["Plain"] },
	{ value = "pvp", label = L["By PvP status"] },
	{ value = "accent", label = L["Accent colour"] },
}
local CLOCK_OPTIONS = {
	{ value = "game", label = L["Game clock settings"] },
	{ value = "local24", label = L["Local time, 24-hour"] },
	{ value = "local12", label = L["Local time, 12-hour"] },
	{ value = "realm24", label = L["Realm time, 24-hour"] },
	{ value = "realm12", label = L["Realm time, 12-hour"] },
}
local PRECISION_OPTIONS = {
	{ value = 0, label = L["Whole numbers (45, 62)"] },
	{ value = 1, label = L["Tenths (45.3, 62.1)"] },
	{ value = 2, label = L["Hundredths (45.32, 62.18)"] },
}
local POSITION_OPTIONS = {
	{ value = "top", label = L["Top of the map"] },
	{ value = "bottom", label = L["Above the strip"] },
}
local OUTLINE_OPTIONS = {
	{ value = "", label = L["None, with a soft shadow"] },
	{ value = "OUTLINE", label = L["Thin outline"] },
	{ value = "THICKOUTLINE", label = L["Thick outline"] },
}

function Settings.FontOptions()
	local out = { { value = "", label = L["Interface font"] } }
	local Widgets = K.Widgets
	if Widgets and Widgets.MediaOptions then
		for _, option in ipairs(Widgets.MediaOptions("font")) do
			out[#out + 1] = option
		end
	end
	return out
end

local function Custom(settings)
	return settings.accent.source == "custom"
end

local function TextRows(prefix, labels, name)
	return {
		{
			type = "dropdown", key = prefix .. ".font", label = labels[1], options = Settings.FontOptions,
			help = L["The typeface of the %s."]:format(name),
		},
		{
			type = "slider", key = prefix .. ".size", label = labels[2],
			min = TEXT_MIN, max = TEXT_MAX, step = TEXT_STEP,
			help = L["The size of the %s, before the interface text size."]:format(name),
		},
		{
			type = "dropdown", key = prefix .. ".outline", label = labels[3], options = OUTLINE_OPTIONS,
			help = L["An outline helps the %s read over bright terrain."]:format(name),
		},
	}
end

local schema = {
	{ type = "header", label = L["Frame"] },
	{
		type = "dropdown", key = "accent.source", label = L["Hairline colour"], options = ACCENT_OPTIONS,
		help = L["The thin line round the map follows your class colour or your own colour."],
	},
	{
		type = "color", key = "accent.color", label = L["Custom colour"], showWhen = Custom,
		help = L["The hairline colour when it does not follow your class."],
	},
	{ type = "header", label = L["Button column"] },
	{
		type = "dropdown", key = "column.side", label = L["Button column side"], options = SIDE_OPTIONS,
		help = L["Where the small buttons sit: inside the map's right edge, or beside the map."],
	},
	{
		type = "dropdown", key = "column.growth", label = L["Button order"], options = GROWTH_OPTIONS,
		help = L["Whether the buttons start at the top or the bottom of the column."],
	},
	{
		type = "slider", key = "column.size", label = L["Button size"],
		min = BUTTON_MIN, max = BUTTON_MAX, step = BUTTON_STEP,
		help = L["The width and height of each button in the column."],
	},
	{
		type = "slider", key = "column.spacing", label = L["Button spacing"],
		min = SPACING_MIN, max = SPACING_MAX, step = SPACING_STEP,
		help = L["The gap between the buttons, and between the column and the map."],
	},
	{
		type = "toggle", key = "column.tracking", label = L["Tracking button"],
		help = L["Picks what the map tracks, such as herbs or the nearest innkeeper."],
	},
	{
		type = "toggle", key = "column.mail", label = L["Mail indicator"],
		help = L["Shows an envelope while you have unread mail."],
	},
	{
		type = "toggle", key = "column.calendar", label = L["Calendar button"],
		help = L["Opens the calendar; right-click for the clock options."],
	},
	{
		type = "toggle", key = "column.queue", label = L["Group finder status"],
		help = L["Shows an eye while you are queued, in place of Blizzard's queue eye."],
	},
	{
		type = "toggle", key = "column.drawer", label = L["Addon drawer button"],
		help = L["Gathers minimap buttons from other addons into a drawer."],
	},
	{ type = "header", label = L["Addon drawer"] },
	{
		type = "dropdown", key = "drawer.behaviour", label = L["Drawer opens"], options = BEHAVIOUR_OPTIONS,
		help = L["Open the drawer with a click, on mouseover, or keep it open."],
	},
	{
		type = "dropdown", key = "drawer.direction", label = L["Drawer direction"], options = DIRECTION_OPTIONS,
		help = L["Which way the drawer opens from its button."],
	},
	{
		type = "slider", key = "drawer.size", label = L["Drawer icon size"],
		min = ICON_MIN, max = ICON_MAX, step = ICON_STEP,
		help = L["The size of each addon button in the drawer."],
	},
	{
		type = "slider", key = "drawer.spacing", label = L["Drawer spacing"],
		min = SPACING_MIN, max = SPACING_MAX, step = SPACING_STEP,
		help = L["The gap between addon buttons in the drawer."],
	},
	{
		type = "slider", key = "drawer.columns", label = L["Drawer columns"],
		min = COLUMNS_MIN, max = COLUMNS_MAX, step = COLUMNS_STEP,
		help = L["How many addon buttons sit in each row before a new row starts."],
	},
	{
		type = "toggle", key = "drawer.autoClose", label = L["Close after a click"],
		help = L["Closes the drawer when you click one of its buttons."],
	},
	{
		type = "toggle", key = "drawer.compartment", label = L["Addon compartment"],
		help = L["Right-click the drawer button for Blizzard's addon compartment list."],
	},
	{
		type = "toggle", key = "drawer.hideEmpty", label = L["Hide when empty"],
		help = L["Hides the drawer button while no addon has a button to show."],
	},
	{ type = "header", label = L["Zoom"] },
	{
		type = "toggle", key = "zoom.wheel", label = L["Zoom with the mouse wheel"],
		help = L["Scroll over the map to zoom in and out."],
	},
	{
		type = "toggle", key = "zoom.reset", label = L["Zoom back out"],
		help = L["Returns the map to its widest view a few seconds after you zoom."],
	},
	{
		type = "slider", key = "zoom.delay", label = L["Zoom-out delay"],
		min = DELAY_MIN, max = DELAY_MAX, step = DELAY_STEP,
		showWhen = function(settings)
			return settings.zoom.reset == true
		end,
		help = L["Seconds before the map zooms back out."],
	},
	{
		type = "toggle", key = "compass", label = L["North mark"],
		help = L["Shows N at the top of the map while the map does not rotate."],
	},
	{ type = "header", label = L["Zone and clock strip"] },
	{
		type = "slider", key = "strip.opacity", label = L["Strip opacity"],
		min = OPACITY_MIN, max = OPACITY_MAX, step = OPACITY_STEP,
		help = L["How dark the band behind the zone name and clock is."],
	},
	{
		type = "toggle", key = "zone.shown", label = L["Zone name"],
		help = L["Shows the zone name on the strip."],
	},
	{
		type = "dropdown", key = "zone.color", label = L["Zone colour"], options = ZONE_COLOR_OPTIONS,
		help = L["Colours the zone name plainly, by PvP status or with the accent."],
	},
}
for _, row in ipairs(TextRows("zone", { L["Zone font"], L["Zone text size"], L["Zone outline"] }, L["zone name"])) do
	schema[#schema + 1] = row
end
schema[#schema + 1] = {
	type = "toggle", key = "clock.shown", label = L["Clock"],
	help = L["Shows the time on the strip."],
}
schema[#schema + 1] = {
	type = "dropdown", key = "clock.mode", label = L["Clock format"], options = CLOCK_OPTIONS,
	help = L["Follow the game's clock settings, or pick local or realm time."],
}
for _, row in ipairs(TextRows("clock", { L["Clock font"], L["Clock text size"], L["Clock outline"] }, L["clock"])) do
	schema[#schema + 1] = row
end
schema[#schema + 1] = { type = "header", label = L["Coordinates"] }
schema[#schema + 1] = {
	type = "toggle", key = "coords.shown", label = L["Coordinates"],
	help = L["Shows your position on the zone map."],
}
schema[#schema + 1] = {
	type = "dropdown", key = "coords.precision", label = L["Coordinate format"], options = PRECISION_OPTIONS,
	help = L["How many decimals the coordinates show."],
}
schema[#schema + 1] = {
	type = "dropdown", key = "coords.position", label = L["Coordinate position"], options = POSITION_OPTIONS,
	help = L["Where the coordinates sit on the map."],
}
for _, row in ipairs(TextRows("coords", { L["Coordinate font"], L["Coordinate text size"], L["Coordinate outline"] }, L["coordinates"])) do
	schema[#schema + 1] = row
end
Settings.schema = schema

local rows = {}
for _, row in ipairs(schema) do
	if row.key then
		rows[row.key] = row
	end
end

local cache = {}
local function Split(key)
	local parts = cache[key]
	if not parts then
		parts = {}
		for part in key:gmatch("[^%.]+") do
			parts[#parts + 1] = part
		end
		cache[key] = parts
	end
	return parts
end

local function Lookup(root, key)
	local node = root
	for _, part in ipairs(Split(key)) do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function IsChannel(value)
	return not IsSecret(value) and type(value) == "number" and value >= 0 and value <= 1
end

local function InOptions(options, value)
	for _, option in ipairs(options) do
		if option.value == value then
			return true
		end
	end
	return false
end

local function Valid(row, value, default)
	if IsSecret(value) or type(value) ~= type(default) then
		return false
	end
	if not row then
		return true
	end
	if row.type == "slider" then
		return value == value and value >= row.min and value <= row.max
	elseif row.type == "dropdown" and type(row.options) == "table" then
		return InOptions(row.options, value)
	elseif row.type == "dropdown" then
		return value == "" or K.Theme.IsFontPath(value)
	elseif row.type == "color" then
		return IsChannel(value.r) and IsChannel(value.g) and IsChannel(value.b)
	end
	return true
end

local logged = {}

function Settings.Get(key)
	local default = Lookup(Settings.defaults, key)
	if default == nil then
		error("KstyleUI_Minimap Settings.Get: unknown setting " .. tostring(key), 2)
	end
	local Store = K.Store
	if not Store.IsLoaded() then
		return default
	end
	local value = Lookup(Store.Module(MODULE), key)
	if value == nil or Valid(rows[key], value, default) then
		return value == nil and default or value
	end
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log(MODULE, "ignored the saved " .. key .. ", which is not allowed; using the default")
	end
	return default
end
