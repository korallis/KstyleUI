-- Settings.lua: the Meters module's defaults, its settings schema, checked setting reads, and the colour and font rules every meter shares.
local _, ns = ...

local K = KstyleUI
local L, Tokens, Theme = K.L, K.Tokens, K.Theme

ns.MODULE = "Meters"

local MIN_TEXT, MAX_TEXT = 6, 24
local MIN_ROW, MAX_ROW = 10, 40
local MAX_SPACING = 12
local MIN_WARN, MAX_WARN, WARN_STEP = 50, 100, 5
local NO_OUTLINE = ""
local CHANNELS = { "r", "g", "b" }

local function Rgb(name)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b }
end

local function DefaultTexture()
	for _, item in ipairs(Tokens.MediaList("statusbar")) do
		if item.key == "Glass" then
			return item.path
		end
	end
	return (Tokens.Texture("barGlass"))
end

local function Bars(fill)
	return {
		texture = DefaultTexture(),
		colorSource = "class",
		color = Rgb("accentDefault"),
		fill = fill,
	}
end

local function Text(size)
	return { font = "", fontSize = size, outline = NO_OUTLINE }
end

local function Merge(...)
	local out = {}
	for i = 1, select("#", ...) do
		for k, v in pairs((select(i, ...))) do
			out[k] = v
		end
	end
	return out
end

local BODY, CAPTION = Tokens.Size("body"), Tokens.Size("caption")
local ROW, SPACING = Tokens.Size("buffBarHeight"), Tokens.Size("gapTiny")

ns.defaults = {
	accent = "class",
	accentColor = Rgb("accentDefault"),
	damage = Merge(Bars("left"), Text(BODY), {
		shown = true,
		group = false,
		mode = "window",
		meter = "DamageDone",
		session = "Current",
		rowHeight = ROW,
		spacing = SPACING,
		title = true,
		titleSize = CAPTION,
		percent = true,
	}),
	threat = Merge(Bars("left"), Text(BODY), {
		shown = true,
		group = true,
		pets = true,
		value = "both",
		rowHeight = ROW,
		spacing = SPACING,
		title = true,
		titleSize = CAPTION,
		warnings = true,
		warnAt = 80,
		dangerAt = 95,
	}),
	swing = Merge(Bars(nil), Text(CAPTION), {
		shown = true,
		mainHand = true,
		offHand = true,
		ranged = true,
		hideIdle = true,
		range = true,
		orientation = "HORIZONTAL",
		reverse = false,
		spacing = 1,
		time = false,
	}),
}

ns.METER_TYPES = {
	{ value = "DamageDone", label = L["Damage done"] },
	{ value = "Dps", label = L["Damage per second"], perSecond = true },
	{ value = "HealingDone", label = L["Healing done"] },
	{ value = "Hps", label = L["Healing per second"], perSecond = true },
	{ value = "Absorbs", label = L["Absorbs"] },
	{ value = "Interrupts", label = L["Interrupts"] },
	{ value = "Dispels", label = L["Dispels"] },
	{ value = "DamageTaken", label = L["Damage taken"] },
	{ value = "AvoidableDamageTaken", label = L["Avoidable damage taken"] },
	{ value = "Deaths", label = L["Deaths"], deaths = true },
	{ value = "EnemyDamageTaken", label = L["Enemy damage taken"] },
}
ns.SESSIONS = {
	{ value = "Current", label = L["Current fight"] },
	{ value = "Overall", label = L["Overall"] },
}

local COLOR_SOURCES = {
	{ value = "class", label = L["Class colour"] },
	{ value = "reaction", label = L["Reaction colour"] },
	{ value = "custom", label = L["Custom colour"] },
}
local OUTLINES = {
	{ value = NO_OUTLINE, label = L["Soft shadow"] },
	{ value = "OUTLINE", label = L["Thin outline"] },
	{ value = "THICKOUTLINE", label = L["Thick outline"] },
}
local FILLS = {
	{ value = "left", label = L["From the left"] },
	{ value = "right", label = L["From the right"] },
}
local ORIENTATIONS = {
	{ value = "HORIZONTAL", label = L["Horizontal"] },
	{ value = "VERTICAL", label = L["Vertical"] },
}

local function FontOptions()
	local out = { { value = "", label = L["Interface font"] } }
	for _, item in ipairs(K.Widgets.MediaOptions("font")) do
		out[#out + 1] = item
	end
	return out
end

local function Is(path, value)
	local section, key = path:match("^(%w+)%.(%w+)$")
	return function(settings)
		local node = section and settings[section] or settings
		return type(node) == "table" and node[key or path] == value
	end
end

local function Off(section)
	return function(settings)
		return type(settings[section]) == "table" and settings[section].shown == false
	end
end

local function TextRows(section, rows)
	local off = Off(section)
	rows[#rows + 1] = {
		type = "dropdown", key = section .. ".font", label = L["Font"], disableWhen = off,
		help = L["The typeface of the text. The interface font follows the Appearance page."], options = FontOptions,
	}
	rows[#rows + 1] = {
		type = "slider", key = section .. ".fontSize", label = L["Text size"], disableWhen = off,
		help = L["How large the text is, in units at the 1080 reference."], min = MIN_TEXT, max = MAX_TEXT, step = 1,
	}
	rows[#rows + 1] = {
		type = "dropdown", key = section .. ".outline", label = L["Text outline"], disableWhen = off,
		help = L["A soft shadow, or an outline for text over bright scenes."], options = OUTLINES,
	}
end

local function BarRows(section, rows)
	local off = Off(section)
	rows[#rows + 1] = {
		type = "texture", key = section .. ".texture", label = L["Bar texture"], disableWhen = off,
		help = L["The fill texture of the bars."],
	}
	rows[#rows + 1] = {
		type = "dropdown", key = section .. ".colorSource", label = L["Bar colour"], disableWhen = off,
		help = L["Colour bars by class, by friend or foe, or with one colour you pick."], options = COLOR_SOURCES,
	}
	rows[#rows + 1] = {
		type = "color", key = section .. ".color", label = L["Custom bar colour"], disableWhen = off,
		help = L["The colour of every bar when the bar colour is custom."], showWhen = Is(section .. ".colorSource", "custom"),
	}
end

local function ListRows(section, rows)
	local off = Off(section)
	BarRows(section, rows)
	rows[#rows + 1] = {
		type = "dropdown", key = section .. ".fill", label = L["Bar direction"], disableWhen = off,
		help = L["The side the bars grow from."], options = FILLS,
	}
	rows[#rows + 1] = {
		type = "slider", key = section .. ".rowHeight", label = L["Row height"], disableWhen = off,
		help = L["The height of each row. Taller rows show fewer at once."], min = MIN_ROW, max = MAX_ROW, step = 1,
	}
	rows[#rows + 1] = {
		type = "slider", key = section .. ".spacing", label = L["Row spacing"], disableWhen = off,
		help = L["The gap between rows."], min = 0, max = MAX_SPACING, step = 1,
	}
	rows[#rows + 1] = {
		type = "toggle", key = section .. ".title", label = L["Show the title"], disableWhen = off,
		help = L["Shows the meter's name and column heading above the rows."],
	}
	rows[#rows + 1] = {
		type = "slider", key = section .. ".titleSize", label = L["Title size"], disableWhen = off,
		help = L["How large the title and column heading are."], min = MIN_TEXT, max = MAX_TEXT, step = 1,
	}
	TextRows(section, rows)
end

local schema = {
	{ type = "header", label = L["Accent"] },
	{
		type = "dropdown", key = "accent", label = L["Accent colour"],
		help = L["The colour of the meters' title marks: the class colour or one you pick."],
		options = { { value = "class", label = L["Class colour"] }, { value = "custom", label = L["Custom colour"] } },
	},
	{
		type = "color", key = "accentColor", label = L["Custom accent"], showWhen = Is("accent", "custom"),
		help = L["The accent colour the meters use when the accent is custom."],
	},
	{ type = "header", label = L["Damage meter"] },
	{ type = "toggle", key = "damage.shown", label = L["Show the damage meter"], help = L["Shows the Damage Meter in KstyleUI's style."] },
	{
		type = "dropdown", key = "damage.mode", label = L["Style"], disableWhen = Off("damage"),
		help = L["KstyleUI's own window, or Blizzard's window restyled where Edit Mode puts it."],
		options = { { value = "window", label = L["KstyleUI window"] }, { value = "skin", label = L["Restyle Blizzard's window"] } },
	},
	{
		type = "dropdown", key = "damage.meter", label = L["Show"], disableWhen = Off("damage"), showWhen = Is("damage.mode", "window"),
		help = L["What the window measures. Click its title to change it in game."], options = ns.METER_TYPES,
	},
	{
		type = "dropdown", key = "damage.session", label = L["Fight"], disableWhen = Off("damage"), showWhen = Is("damage.mode", "window"),
		help = L["The current fight or every fight since the last reset. Right-click the title to switch."], options = ns.SESSIONS,
	},
	{
		type = "toggle", key = "damage.group", label = L["Only in a group"], disableWhen = Off("damage"), showWhen = Is("damage.mode", "window"),
		help = L["Hides the window while you play alone."],
	},
	{
		type = "toggle", key = "damage.percent", label = L["Show percentages"], disableWhen = Off("damage"), showWhen = Is("damage.mode", "window"),
		help = L["Shows each share of the total, when the game lets addons read it."],
	},
}
ListRows("damage", schema)

schema[#schema + 1] = { type = "header", label = L["Threat meter"] }
schema[#schema + 1] = { type = "toggle", key = "threat.shown", label = L["Show the threat meter"], help = L["Shows your group's threat on your target."] }
schema[#schema + 1] = {
	type = "toggle", key = "threat.group", label = L["Only in a group"], disableWhen = Off("threat"),
	help = L["Hides the meter while you play alone."],
}
schema[#schema + 1] = {
	type = "toggle", key = "threat.pets", label = L["Include pets"], disableWhen = Off("threat"),
	help = L["Lists the group's pets as well as its players."],
}
schema[#schema + 1] = {
	type = "dropdown", key = "threat.value", label = L["Numbers"], disableWhen = Off("threat"),
	help = L["Threat as a percentage of pulling aggro, as threat points, or both."],
	options = { { value = "both", label = L["Threat and percentage"] }, { value = "percent", label = L["Percentage"] }, { value = "threat", label = L["Threat"] } },
}
schema[#schema + 1] = {
	type = "toggle", key = "threat.warnings", label = L["Threat warnings"], disableWhen = Off("threat"),
	help = L["Lights the meter when you near aggro, or when a tank is about to lose it."],
}
schema[#schema + 1] = {
	type = "slider", key = "threat.warnAt", label = L["Warn at"], disableWhen = Off("threat"), showWhen = Is("threat.warnings", true),
	help = L["The threat percentage that turns the meter yellow."], min = MIN_WARN, max = MAX_WARN, step = WARN_STEP,
}
schema[#schema + 1] = {
	type = "slider", key = "threat.dangerAt", label = L["Danger at"], disableWhen = Off("threat"), showWhen = Is("threat.warnings", true),
	help = L["The threat percentage that turns the meter red and makes it pulse."], min = MIN_WARN, max = MAX_WARN, step = WARN_STEP,
}
ListRows("threat", schema)

schema[#schema + 1] = { type = "header", label = L["Swing timer"] }
schema[#schema + 1] = {
	type = "toggle", key = "swing.shown", label = L["Show the swing timer"],
	help = L["Replaces Blizzard's swing timer with KstyleUI's bars."],
}
for _, slot in ipairs({
	{ "mainHand", L["Main hand"], L["Shows a bar for your main-hand swings."] },
	{ "offHand", L["Off hand"], L["Shows a bar for your off-hand swings."] },
	{ "ranged", L["Ranged"], L["Shows a bar for your ranged attacks."] },
}) do
	schema[#schema + 1] = { type = "toggle", key = "swing." .. slot[1], label = slot[2], help = slot[3], disableWhen = Off("swing") }
end
schema[#schema + 1] = {
	type = "toggle", key = "swing.hideIdle", label = L["Hide when idle"], disableWhen = Off("swing"),
	help = L["Hides the bars out of combat while no swing is running."],
}
schema[#schema + 1] = {
	type = "toggle", key = "swing.range", label = L["Dim out of range"], disableWhen = Off("swing"),
	help = L["Dims a bar while your target is out of reach of that attack."],
}
BarRows("swing", schema)
schema[#schema + 1] = {
	type = "dropdown", key = "swing.orientation", label = L["Orientation"], disableWhen = Off("swing"),
	help = L["Bars that fill across, or bars that fill upward side by side."], options = ORIENTATIONS,
}
schema[#schema + 1] = {
	type = "toggle", key = "swing.reverse", label = L["Reverse fill"], disableWhen = Off("swing"),
	help = L["Fills the bars from the other end."],
}
schema[#schema + 1] = {
	type = "slider", key = "swing.spacing", label = L["Bar spacing"], disableWhen = Off("swing"),
	help = L["The gap between the main-hand, off-hand and ranged bars."], min = 0, max = MAX_SPACING, step = 1,
}
schema[#schema + 1] = {
	type = "toggle", key = "swing.time", label = L["Show the time"], disableWhen = Off("swing"),
	help = L["Shows the seconds left until the next swing."],
}
TextRows("swing", schema)

ns.schema = schema

local rows = {}
for _, row in ipairs(schema) do
	if row.key then
		rows[row.key] = row
	end
end

local paths = {}

local function Lookup(root, key)
	local path = paths[key]
	if not path then
		path = {}
		for part in key:gmatch("[^%.]+") do
			path[#path + 1] = part
		end
		paths[key] = path
	end
	local node = root
	for i = 1, #path do
		if type(node) ~= "table" then
			return nil
		end
		node = node[path[i]]
	end
	return node
end

local function Allowed(row, value)
	if row.type == "slider" then
		if type(value) ~= "number" or value ~= value then
			return false
		end
		return value >= row.min and value <= row.max
	elseif row.type == "dropdown" and type(row.options) == "table" then
		for _, option in ipairs(row.options) do
			if option.value == value then
				return true
			end
		end
		return false
	elseif row.type == "color" then
		if type(value) ~= "table" then
			return false
		end
		for i = 1, #CHANNELS do
			local v = value[CHANNELS[i]]
			if type(v) ~= "number" or v ~= v or v < 0 or v > 1 then
				return false
			end
		end
		return true
	end
	return type(value) == type((Lookup(ns.defaults, row.key)))
end

local warned = {}

function ns.Get(key)
	local default = Lookup(ns.defaults, key)
	if default == nil then
		error("KstyleUI_Meters: unknown setting " .. tostring(key), 2)
	end
	if not K.Store.IsLoaded() then
		return default
	end
	local value = Lookup(K.Store.Module(ns.MODULE), key)
	local row = rows[key]
	if value == nil or (row and not Allowed(row, value)) or (not row and type(value) ~= type(default)) then
		if value ~= nil and not warned[key] then
			warned[key] = true
			ns.Log("the saved value of " .. key .. " is not allowed; using the default")
		end
		return default
	end
	return value
end

function ns.Log(message)
	K.DevTest.Log(ns.MODULE, message)
end

local logged = {}
function ns.LogOnce(id, message)
	if not logged[id] then
		logged[id] = true
		ns.Log(message)
	end
end

local function Custom(color)
	return color.r, color.g, color.b
end

function ns.Accent()
	if ns.Get("accent") == "custom" then
		return Custom(ns.Get("accentColor"))
	end
	return Theme.Accent()
end

function ns.BarColor(section, classFile, reaction)
	local source = ns.Get(section .. ".colorSource")
	if source == "custom" then
		return Custom(ns.Get(section .. ".color"))
	end
	if source == "class" and not ns.Logic.IsSecret(classFile) and type(classFile) == "string" and classFile ~= "" then
		return Theme.ClassColor(classFile)
	end
	return Tokens.Color(reaction or "friendly")
end

function ns.FontPath(section)
	local font = ns.Get(section .. ".font")
	if font == "" then
		return (Tokens.Font("body"))
	end
	return font
end

function ns.ApplyFont(text, section, sizeKey)
	local path = ns.FontPath(section)
	local size = ns.Get(section .. "." .. (sizeKey or "fontSize")) * Theme.FontScale()
	local flags = ns.Get(section .. ".outline")
	if text:SetFont(path, size, flags) == false then
		local fallback, _, fallbackFlags = Tokens.Font("body")
		text:SetFont(fallback, size, fallbackFlags)
		ns.LogOnce("font:" .. tostring(path), "the font " .. tostring(path) .. " did not load; the meters use the interface font")
	end
	if flags ~= NO_OUTLINE then
		text:SetShadowOffset(0, 0)
	else
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	end
end
