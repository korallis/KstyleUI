-- Settings.lua: the nameplates' defaults, settings page and checked, cached reads of each setting.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local MODULE = "Nameplates"
Settings.MODULE = MODULE

local function Color(name)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b }
end

local BAR_TEXTURE = Tokens.MediaList("statusbar")[1].path
local FONT = Tokens.FontPath(Tokens.DEFAULT_FONT_FACE)

Settings.defaults = {
	offsetY = 0,
	font = FONT,
	health = { texture = BAR_TEXTURE, orientation = "HORIZONTAL", reverse = false },
	enemy = { colorSource = "class", color = Color("hostile") },
	friendly = { colorSource = "class", color = Color("friendly"), nameOnly = false },
	name = { show = true, size = 10, outline = "OUTLINE", upper = true, classColor = true },
	level = { show = true, size = 9, outline = "OUTLINE" },
	healthText = { show = true, size = 9, outline = "OUTLINE", format = "percent" },
	cast = {
		enabled = true, height = 12, texture = BAR_TEXTURE, orientation = "HORIZONTAL", reverse = false,
		colorSource = "class", color = Color("accentDefault"), shieldColor = Color("textDisabled"),
		showIcon = true, showName = true, showTime = true, textSize = 9, outline = "OUTLINE",
	},
	debuffs = {
		enabled = true, includePlateOnly = true, size = 18, spacing = 2, columns = 5, rows = 1,
		growthX = "RIGHT", growthY = "UP", showTime = true, showCount = true, textSize = 8, outline = "OUTLINE",
	},
	threat = {
		display = "glow", role = "auto", groupOnly = true,
		safe = Color("friendly"), warning = Color("neutral"), danger = Color("hostile"),
	},
	target = { highlight = true, colorSource = "class", color = Color("accentDefault"), dimOthers = 1 },
	focus = { highlight = true, color = Color("rare") },
	markers = { classification = true, raid = true, raidSize = 16 },
	cvars = {
		enabled = false, maxDistance = 40, verticalDistance = 0, stacking = "enemy",
		selectedScale = 1.2, minScale = 0.8, clickSize = 2,
	},
}

local OUTLINES = {
	{ value = "NONE", label = L["None, soft shadow"] },
	{ value = "OUTLINE", label = L["Thin outline"] },
	{ value = "THICKOUTLINE", label = L["Thick outline"] },
}
local COLOR_SOURCES = {
	{ value = "class", label = L["Class colour for players"] },
	{ value = "reaction", label = L["Reaction colour"] },
	{ value = "custom", label = L["Custom colour"] },
}
local ACCENT_SOURCES = {
	{ value = "class", label = L["Accent (class colour)"] },
	{ value = "custom", label = L["Custom colour"] },
}
local ORIENTATIONS = {
	{ value = "HORIZONTAL", label = L["Horizontal"] },
	{ value = "VERTICAL", label = L["Vertical"] },
}
local HEALTH_FORMATS = {
	{ value = "percent", label = L["Percent"] },
	{ value = "value", label = L["Value"] },
	{ value = "both", label = L["Value and percent"] },
}
local THREAT_DISPLAYS = {
	{ value = "glow", label = L["Glow around the plate"] },
	{ value = "health", label = L["Health bar colour"] },
	{ value = "off", label = L["Off"] },
}
local THREAT_ROLES = {
	{ value = "auto", label = L["From my group role"] },
	{ value = "tank", label = L["Tank: I want aggro"] },
	{ value = "other", label = L["Damage or healing: I avoid aggro"] },
}
local GROWTH_X = {
	{ value = "RIGHT", label = L["Right"] },
	{ value = "LEFT", label = L["Left"] },
}
local GROWTH_Y = {
	{ value = "UP", label = L["Up, above the name"] },
	{ value = "DOWN", label = L["Down, under the cast bar"] },
}
local STACKING = {
	{ value = "none", label = L["Overlap"] },
	{ value = "enemy", label = L["Stack enemy plates"] },
	{ value = "all", label = L["Stack all plates"] },
}

local TEXT_MIN, TEXT_MAX = 6, 20

local function Is(key, value)
	return function(s)
		local node = s
		for part in key:gmatch("[^%.]+") do
			node = type(node) == "table" and node[part] or nil
		end
		return node == value
	end
end

local function Off(key)
	local on = Is(key, true)
	return function(s)
		return not on(s)
	end
end

local function HasCVar(name)
	return function()
		local cvars = ns.CVars
		return not (cvars and type(cvars.Exists) == "function") or cvars.Exists(name)
	end
end

local function TextRows(schema, key, label)
	schema[#schema + 1] = { type = "header", label = label }
	schema[#schema + 1] = {
		type = "toggle", key = key .. ".show", label = L["Show"],
		help = L["Shows this text on every plate."],
	}
	schema[#schema + 1] = {
		type = "slider", key = key .. ".size", label = L["Text size"],
		help = L["The size of this text, in interface units."],
		min = TEXT_MIN, max = TEXT_MAX, step = 1, disableWhen = Off(key .. ".show"),
	}
	schema[#schema + 1] = {
		type = "dropdown", key = key .. ".outline", label = L["Outline"],
		help = L["An outline keeps text readable over the game world."],
		options = OUTLINES, disableWhen = Off(key .. ".show"),
	}
end

local schema = {
	{ type = "header", label = L["Plates"] },
	{
		type = "slider", key = "offsetY", label = L["Height above the unit"],
		help = L["Moves every plate up or down from where the game places it."],
		min = -40, max = 40, step = 1,
	},
	{
		type = "font", key = "font", label = L["Font"],
		help = L["The font of every text on the plates."],
	},
	{ type = "header", label = L["Health bar"] },
	{
		type = "texture", key = "health.texture", label = L["Texture"],
		help = L["The texture that fills the health bar."],
	},
	{
		type = "dropdown", key = "health.orientation", label = L["Orientation"],
		help = L["Fills the health bar across or upward."],
		options = ORIENTATIONS,
	},
	{
		type = "toggle", key = "health.reverse", label = L["Reverse fill"],
		help = L["Fills the bar from the other end."],
	},
	{ type = "header", label = L["Enemy plates"] },
	{
		type = "dropdown", key = "enemy.colorSource", label = L["Bar colour"],
		help = L["Where the health colour of enemy plates comes from."],
		options = COLOR_SOURCES,
	},
	{
		type = "color", key = "enemy.color", label = L["Custom colour"],
		help = L["The health colour of enemy plates."],
		showWhen = Is("enemy.colorSource", "custom"),
	},
	{ type = "header", label = L["Friendly plates"] },
	{
		type = "dropdown", key = "friendly.colorSource", label = L["Bar colour"],
		help = L["Where the health colour of friendly plates comes from."],
		options = COLOR_SOURCES,
	},
	{
		type = "color", key = "friendly.color", label = L["Custom colour"],
		help = L["The health colour of friendly plates."],
		showWhen = Is("friendly.colorSource", "custom"),
	},
	{
		type = "toggle", key = "friendly.nameOnly", label = L["Name only"],
		help = L["Friendly plates show just the name, without a health bar."],
	},
}

TextRows(schema, "name", L["Name"])
schema[#schema + 1] = {
	type = "toggle", key = "name.upper", label = L["Upper case"],
	help = L["Writes names in capitals. Names hidden by the game in combat stay as they are."],
	disableWhen = Off("name.show"),
}
schema[#schema + 1] = {
	type = "toggle", key = "name.classColor", label = L["Class-coloured player names"],
	help = L["Colours players' names with their class colour."],
	disableWhen = Off("name.show"),
}
TextRows(schema, "level", L["Level"])
TextRows(schema, "healthText", L["Health text"])
schema[#schema + 1] = {
	type = "dropdown", key = "healthText.format", label = L["Format"],
	help = L["Shows health as a percent, a value, or both."],
	options = HEALTH_FORMATS, disableWhen = Off("healthText.show"),
}

local rest = {
	{ type = "header", label = L["Cast bar"] },
	{
		type = "toggle", key = "cast.enabled", label = L["Show cast bars"],
		help = L["Shows the spell a unit is casting under its health bar."],
	},
	{
		type = "slider", key = "cast.height", label = L["Height"],
		help = L["The height of the cast bar, in interface units."],
		min = 6, max = 24, step = 1, disableWhen = Off("cast.enabled"),
	},
	{
		type = "texture", key = "cast.texture", label = L["Texture"],
		help = L["The texture that fills the cast bar."],
		disableWhen = Off("cast.enabled"),
	},
	{
		type = "dropdown", key = "cast.orientation", label = L["Orientation"],
		help = L["Fills the cast bar across or upward."],
		options = ORIENTATIONS, disableWhen = Off("cast.enabled"),
	},
	{
		type = "toggle", key = "cast.reverse", label = L["Reverse fill"],
		help = L["Fills the cast bar from the other end."],
		disableWhen = Off("cast.enabled"),
	},
	{
		type = "dropdown", key = "cast.colorSource", label = L["Bar colour"],
		help = L["Interruptible casts follow the accent or use your own colour."],
		options = ACCENT_SOURCES, disableWhen = Off("cast.enabled"),
	},
	{
		type = "color", key = "cast.color", label = L["Custom colour"],
		help = L["The colour of casts you can interrupt."],
		showWhen = Is("cast.colorSource", "custom"), disableWhen = Off("cast.enabled"),
	},
	{
		type = "color", key = "cast.shieldColor", label = L["Uninterruptible colour"],
		help = L["The colour of casts nothing can interrupt."],
		disableWhen = Off("cast.enabled"),
	},
	{
		type = "toggle", key = "cast.showIcon", label = L["Spell icon"],
		help = L["Shows the spell's icon at the left of the cast bar."],
		disableWhen = Off("cast.enabled"),
	},
	{
		type = "toggle", key = "cast.showName", label = L["Spell name"],
		help = L["Shows the spell's name on the cast bar."],
		disableWhen = Off("cast.enabled"),
	},
	{
		type = "toggle", key = "cast.showTime", label = L["Time left"],
		help = L["Shows the seconds left on the cast bar."],
		disableWhen = Off("cast.enabled"),
	},
	{
		type = "slider", key = "cast.textSize", label = L["Text size"],
		help = L["The size of the cast bar's text, in interface units."],
		min = TEXT_MIN, max = TEXT_MAX, step = 1, disableWhen = Off("cast.enabled"),
	},
	{
		type = "dropdown", key = "cast.outline", label = L["Outline"],
		help = L["An outline keeps text readable over the game world."],
		options = OUTLINES, disableWhen = Off("cast.enabled"),
	},
	{ type = "header", label = L["Debuffs"] },
	{
		type = "toggle", key = "debuffs.enabled", label = L["Show my debuffs"],
		help = L["Shows the debuffs you put on each unit."],
	},
	{
		type = "toggle", key = "debuffs.includePlateOnly", label = L["Nameplate-only debuffs"],
		help = L["Also shows your debuffs that the game marks for nameplates only."],
		disableWhen = Off("debuffs.enabled"),
	},
	{
		type = "slider", key = "debuffs.size", label = L["Icon size"],
		help = L["The size of each debuff icon, in interface units."],
		min = 10, max = 40, step = 1, disableWhen = Off("debuffs.enabled"),
	},
	{
		type = "slider", key = "debuffs.spacing", label = L["Spacing"],
		help = L["The gap between debuff icons."],
		min = 0, max = 10, step = 1, disableWhen = Off("debuffs.enabled"),
	},
	{
		type = "slider", key = "debuffs.columns", label = L["Icons per row"],
		help = L["Shows up to this many debuffs in a row."],
		min = 1, max = 10, step = 1, disableWhen = Off("debuffs.enabled"),
	},
	{
		type = "slider", key = "debuffs.rows", label = L["Rows"],
		help = L["Shows up to icons per row times rows debuffs."],
		min = 1, max = 4, step = 1, disableWhen = Off("debuffs.enabled"),
	},
	{
		type = "dropdown", key = "debuffs.growthX", label = L["Grow across"],
		help = L["Which way a row of debuffs grows."],
		options = GROWTH_X, disableWhen = Off("debuffs.enabled"),
	},
	{
		type = "dropdown", key = "debuffs.growthY", label = L["Grow"],
		help = L["Whether rows of debuffs stack upward above the name or downward under the cast bar."],
		options = GROWTH_Y, disableWhen = Off("debuffs.enabled"),
	},
	{
		type = "toggle", key = "debuffs.showTime", label = L["Time left"],
		help = L["Shows the time left under each debuff."],
		disableWhen = Off("debuffs.enabled"),
	},
	{
		type = "toggle", key = "debuffs.showCount", label = L["Stacks"],
		help = L["Shows how many times a debuff has stacked."],
		disableWhen = Off("debuffs.enabled"),
	},
	{
		type = "slider", key = "debuffs.textSize", label = L["Text size"],
		help = L["The size of the debuffs' text, in interface units."],
		min = TEXT_MIN, max = TEXT_MAX, step = 1, disableWhen = Off("debuffs.enabled"),
	},
	{
		type = "dropdown", key = "debuffs.outline", label = L["Outline"],
		help = L["An outline keeps text readable over the game world."],
		options = OUTLINES, disableWhen = Off("debuffs.enabled"),
	},
	{ type = "header", label = L["Threat"] },
	{
		type = "dropdown", key = "threat.display", label = L["Threat display"],
		help = L["How a plate shows that its unit is attacking you or about to."],
		options = THREAT_DISPLAYS,
	},
	{
		type = "dropdown", key = "threat.role", label = L["Role"],
		help = L["Tanks want aggro; everyone else wants to avoid it."],
		options = THREAT_ROLES, disableWhen = Is("threat.display", "off"),
	},
	{
		type = "toggle", key = "threat.groupOnly", label = L["Only in a group"],
		help = L["Shows threat only while you are in a party or raid."],
		disableWhen = Is("threat.display", "off"),
	},
	{
		type = "color", key = "threat.safe", label = L["Safe colour"],
		help = L["A tank holds aggro."],
		disableWhen = Is("threat.display", "off"),
	},
	{
		type = "color", key = "threat.warning", label = L["Warning colour"],
		help = L["Aggro is about to change hands."],
		disableWhen = Is("threat.display", "off"),
	},
	{
		type = "color", key = "threat.danger", label = L["Danger colour"],
		help = L["A damage dealer or healer has aggro, or a tank lost it."],
		disableWhen = Is("threat.display", "off"),
	},
	{ type = "header", label = L["Target and focus"] },
	{
		type = "toggle", key = "target.highlight", label = L["Highlight the target"],
		help = L["Draws a glow and an edge around your target's plate."],
	},
	{
		type = "dropdown", key = "target.colorSource", label = L["Target colour"],
		help = L["The target highlight follows the accent or uses your own colour."],
		options = ACCENT_SOURCES, disableWhen = Off("target.highlight"),
	},
	{
		type = "color", key = "target.color", label = L["Custom target colour"],
		help = L["The colour of the target highlight."],
		showWhen = Is("target.colorSource", "custom"), disableWhen = Off("target.highlight"),
	},
	{
		type = "slider", key = "target.dimOthers", label = L["Other plates' opacity"],
		help = L["Fades plates that are not your target while you have one."],
		min = 0.2, max = 1, step = 0.05,
	},
	{
		type = "toggle", key = "focus.highlight", label = L["Mark the focus"],
		help = L["Gives your focus's plate a coloured edge."],
	},
	{
		type = "color", key = "focus.color", label = L["Focus colour"],
		help = L["The edge colour of your focus's plate."],
		disableWhen = Off("focus.highlight"),
	},
	{ type = "header", label = L["Markers"] },
	{
		type = "toggle", key = "markers.classification", label = L["Elite and rare markers"],
		help = L["A gold diamond marks elites and bosses, a blue one rares."],
	},
	{
		type = "toggle", key = "markers.raid", label = L["Raid markers"],
		help = L["Shows the raid marker a unit carries."],
	},
	{
		type = "slider", key = "markers.raidSize", label = L["Raid marker size"],
		help = L["The size of the raid marker, in interface units."],
		min = 8, max = 32, step = 1, disableWhen = Off("markers.raid"),
	},
	{ type = "header", label = L["Game nameplate settings"] },
	{
		type = "toggle", key = "cvars.enabled", label = L["Manage these settings"],
		help = L["Applies the settings below out of combat. Off returns them to the game's defaults."],
	},
	{
		type = "slider", key = "cvars.maxDistance", label = L["Distance"],
		help = L["How far away, in yards, plates show."],
		min = 10, max = 60, step = 1, disableWhen = Off("cvars.enabled"), showWhen = HasCVar("nameplateMaxDistance"),
	},
	{
		type = "slider", key = "cvars.verticalDistance", label = L["Height difference"],
		help = L["Hides plates this far above or below you. 0 shows them at any height."],
		min = 0, max = 100, step = 5, disableWhen = Off("cvars.enabled"), showWhen = HasCVar("nameplateMaxVerticalDistance"),
	},
	{
		type = "dropdown", key = "cvars.stacking", label = L["Stacking"],
		help = L["Stacked plates move apart so they never overlap."],
		options = STACKING, disableWhen = Off("cvars.enabled"),
	},
	{
		type = "slider", key = "cvars.selectedScale", label = L["Target plate scale"],
		help = L["How much larger your target's plate is drawn."],
		min = 1, max = 1.6, step = 0.05, disableWhen = Off("cvars.enabled"),
	},
	{
		type = "slider", key = "cvars.minScale", label = L["Distant plate scale"],
		help = L["How small plates shrink with distance."],
		min = 0.5, max = 1, step = 0.05, disableWhen = Off("cvars.enabled"),
	},
	{
		type = "slider", key = "cvars.clickSize", label = L["Click area size"],
		help = L["The game's own plate size, which sets where you can click and how plates stack."],
		min = 1, max = 5, step = 1, disableWhen = Off("cvars.enabled"),
	},
}
for _, row in ipairs(rest) do
	schema[#schema + 1] = row
end

Settings.schema = schema

local rows = {}
for _, row in ipairs(schema) do
	if row.key then
		rows[row.key] = row
	end
end

local function Lookup(root, key)
	local node = root
	for part in key:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

local function IsUnit(v)
	return not ns.Logic.IsSecret(v) and type(v) == "number" and v >= 0 and v <= 1
end

local function Allowed(row, value)
	if ns.Logic.IsSecret(value) then
		return nil
	end
	local kind = row.type
	if kind == "toggle" then
		if type(value) == "boolean" then
			return value
		end
		return nil
	elseif kind == "slider" then
		if type(value) ~= "number" or value ~= value then
			return nil
		end
		return math.min(row.max, math.max(row.min, value))
	elseif kind == "dropdown" then
		for _, option in ipairs(row.options) do
			if option.value == value then
				return value
			end
		end
		return nil
	elseif kind == "color" then
		if type(value) == "table" and IsUnit(value.r) and IsUnit(value.g) and IsUnit(value.b) then
			return value
		end
		return nil
	end
	return type(value) == "string" and value ~= "" and value or nil
end

local cache = {}
local logged = {}

local function Read(key)
	local row = rows[key]
	local default = Lookup(Settings.defaults, key)
	if not row and default == nil then
		error("KstyleUI_Nameplates: unknown setting " .. tostring(key), 3)
	end
	local Store = K.Store
	if not Store.IsLoaded() then
		return default
	end
	local stored = Lookup(Store.Module(MODULE), key)
	if row then
		local value = Allowed(row, stored)
		if value ~= nil then
			return value
		end
	elseif type(stored) == type(default) then
		return stored
	end
	if stored ~= nil and not logged[key] then
		logged[key] = true
		K.DevTest.Log(MODULE, "the saved value of " .. key .. " is not allowed; using the default")
	end
	return default
end

function Settings.Get(key)
	local value = cache[key]
	if value == nil then
		value = Read(key)
		cache[key] = value
	end
	return value
end

function Settings.Invalidate()
	for key in pairs(cache) do
		cache[key] = nil
	end
end

function Settings.Row(key)
	return rows[key]
end
