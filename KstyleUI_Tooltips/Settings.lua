-- Settings.lua: the module's defaults, its settings page and checked reads of each setting.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local MODULE = "Tooltips"
ns.MODULE = MODULE

local SIZE_MIN, SIZE_MAX, SIZE_STEP = 8, 32, 1
local BAR_MIN, BAR_MAX, BAR_STEP, BAR_SIZE = 2, 16, 1, 6
local ICON_MIN, ICON_MAX, ICON_STEP, ICON_SIZE = 20, 64, 1, 44
local OFFSET_MIN, OFFSET_MAX, OFFSET_STEP = -64, 64, 1
local TITLE_SIZE, BODY_SIZE, SMALL_SIZE = 16, 13, 11

local FACE = Tokens.FontPath(Tokens.DEFAULT_FONT_FACE)
local accentR, accentG, accentB = Tokens.Color("accentDefault")
local barR, barG, barB = Tokens.Color("friendly")
local BAR_TEXTURE = Tokens.MediaList("statusbar")[1].path

local function Text(size)
	return { font = FACE, size = size, outline = "NONE" }
end

Settings.defaults = {
	anchor = "fixed",
	cursorX = 0,
	cursorY = 0,
	followFont = true,
	title = Text(TITLE_SIZE),
	body = Text(BODY_SIZE),
	small = Text(SMALL_SIZE),
	qualityEdge = false,
	divider = true,
	softColors = true,
	accentSource = "class",
	accentColor = { r = accentR, g = accentG, b = accentB },
	classNames = true,
	guildLine = true,
	guildRank = false,
	targetLine = true,
	unitEdge = false,
	healthBar = true,
	bar = {
		texture = BAR_TEXTURE,
		color = "class",
		custom = { r = barR, g = barG, b = barB },
		orientation = "HORIZONTAL",
		reverse = false,
		size = BAR_SIZE,
	},
	itemID = false,
	spellID = false,
	iconID = false,
	icon = true,
	iconSize = ICON_SIZE,
}

local OUTLINES = {
	{ value = "NONE", label = L["None"] },
	{ value = "OUTLINE", label = L["Thin"] },
	{ value = "THICKOUTLINE", label = L["Thick"] },
}

local function Cursor(settings)
	return settings.anchor == "cursor"
end

local function OwnFont(settings)
	return settings.followFont == false
end

local function TextRows(rows, role, name)
	rows[#rows + 1] = {
		type = "font", key = role .. ".font", label = string.format(L["%s font"], name),
		help = L["The typeface for these lines while Use KstyleUI's font is off."],
		showWhen = OwnFont,
	}
	rows[#rows + 1] = {
		type = "slider", key = role .. ".size", label = string.format(L["%s size"], name),
		help = L["The text size in KstyleUI units; Appearance's text size scales it too."],
		min = SIZE_MIN, max = SIZE_MAX, step = SIZE_STEP,
	}
	rows[#rows + 1] = {
		type = "dropdown", key = role .. ".outline", label = string.format(L["%s outline"], name),
		help = L["An outline instead of the soft shadow, for busy backgrounds."],
		options = OUTLINES,
	}
end

local schema = {
	{ type = "header", label = L["Position"] },
	{
		type = "dropdown", key = "anchor", label = L["Tooltip position"],
		help = L["At the tooltip anchor, which you move in Layout Mode, or beside the mouse."],
		options = {
			{ value = "fixed", label = L["Tooltip anchor"] },
			{ value = "cursor", label = L["Mouse cursor"] },
		},
	},
	{
		type = "slider", key = "cursorX", label = L["Cursor offset X"],
		help = L["How far right of the mouse the tooltip sits."],
		min = OFFSET_MIN, max = OFFSET_MAX, step = OFFSET_STEP, showWhen = Cursor,
	},
	{
		type = "slider", key = "cursorY", label = L["Cursor offset Y"],
		help = L["How far above the mouse the tooltip sits."],
		min = OFFSET_MIN, max = OFFSET_MAX, step = OFFSET_STEP, showWhen = Cursor,
	},
	{ type = "header", label = L["Text"] },
	{
		type = "toggle", key = "followFont", label = L["Use KstyleUI's font"],
		help = L["Tooltips use the font from Appearance. Turn off to pick a font for each kind of line."],
	},
}
TextRows(schema, "title", L["Title"])
TextRows(schema, "body", L["Line"])
TextRows(schema, "small", L["Small line"])
local LOOK = {
	{ type = "header", label = L["Look"] },
	{
		type = "toggle", key = "qualityEdge", label = L["Item quality edge"],
		help = L["Lights the tooltip's edge in the item's quality colour, from uncommon up."],
	},
	{
		type = "toggle", key = "divider", label = L["Title divider"],
		help = L["Draws an accent line under the tooltip's title."],
	},
	{
		type = "toggle", key = "softColors", label = L["Soft line colours"],
		help = L["Turns Blizzard's gold and white lines into KstyleUI's greys. Coloured lines stay."],
	},
	{
		type = "dropdown", key = "accentSource", label = L["Accent colour"],
		help = L["The colour of the title divider and the You target: your class colour or one you pick."],
		options = {
			{ value = "class", label = L["Class colour"] },
			{ value = "custom", label = L["Custom colour"] },
		},
	},
	{
		type = "color", key = "accentColor", label = L["Custom accent"],
		help = L["The tooltip accent when Accent colour is set to custom."],
		showWhen = function(settings)
			return settings.accentSource == "custom"
		end,
	},
}
local function GuildShown(settings)
	return settings.guildLine ~= false
end

local function BarShown(settings)
	return settings.healthBar ~= false
end

local function CustomBar(settings)
	return settings.healthBar ~= false and type(settings.bar) == "table" and settings.bar.color == "custom"
end

local function IconShown(settings)
	return settings.icon ~= false
end

local MORE = {
	{ type = "header", label = L["Units"] },
	{
		type = "toggle", key = "classNames", label = L["Class colours"],
		help = L["Colours player names by class and other names by reaction."],
	},
	{
		type = "toggle", key = "guildLine", label = L["Guild line"],
		help = L["Shows a player's guild in angle brackets, green for your own guild."],
	},
	{
		type = "toggle", key = "guildRank", label = L["Guild rank"],
		help = L["Adds the player's guild rank after the guild name."],
		showWhen = GuildShown,
	},
	{
		type = "toggle", key = "targetLine", label = L["Target line"],
		help = L["Adds a line naming the unit's target, or You in the accent colour."],
	},
	{
		type = "toggle", key = "unitEdge", label = L["Unit edge"],
		help = L["Lights the tooltip's edge in the unit's class or reaction colour."],
	},
	{ type = "header", label = L["Health bar"] },
	{
		type = "toggle", key = "healthBar", label = L["Health bar"],
		help = L["Shows the unit's health on a KstyleUI bar under the tooltip."],
	},
	{
		type = "texture", key = "bar.texture", label = L["Bar texture"],
		help = L["The fill texture of the health bar."], showWhen = BarShown,
	},
	{
		type = "dropdown", key = "bar.color", label = L["Bar colour"],
		help = L["Class colour for players, reaction colour for everyone, or a colour you pick."],
		options = {
			{ value = "class", label = L["Class colour"] },
			{ value = "reaction", label = L["Reaction colour"] },
			{ value = "custom", label = L["Custom colour"] },
		},
		showWhen = BarShown,
	},
	{
		type = "color", key = "bar.custom", label = L["Custom bar colour"],
		help = L["The health bar colour when Bar colour is set to custom."], showWhen = CustomBar,
	},
	{
		type = "dropdown", key = "bar.orientation", label = L["Bar orientation"],
		help = L["A horizontal bar under the tooltip, or a vertical bar beside it."],
		options = {
			{ value = "HORIZONTAL", label = L["Horizontal"] },
			{ value = "VERTICAL", label = L["Vertical"] },
		},
		showWhen = BarShown,
	},
	{
		type = "toggle", key = "bar.reverse", label = L["Reverse fill"],
		help = L["Fills the bar from the right, or from the top when it is vertical."], showWhen = BarShown,
	},
	{
		type = "slider", key = "bar.size", label = L["Bar thickness"],
		help = L["How thick the health bar is, in KstyleUI units."],
		min = BAR_MIN, max = BAR_MAX, step = BAR_STEP, showWhen = BarShown,
	},
	{ type = "header", label = L["Extra lines"] },
	{
		type = "toggle", key = "itemID", label = L["Item ID"],
		help = L["Adds the item's ID to item tooltips."],
	},
	{
		type = "toggle", key = "spellID", label = L["Spell ID"],
		help = L["Adds the spell's ID to spell and aura tooltips."],
	},
	{
		type = "toggle", key = "iconID", label = L["Icon ID"],
		help = L["Adds the icon's file ID to item, spell and aura tooltips."],
	},
	{
		type = "toggle", key = "icon", label = L["Icon"],
		help = L["Shows the item or spell icon in the tooltip's top left corner."],
	},
	{
		type = "slider", key = "iconSize", label = L["Icon size"],
		help = L["The size of that icon, in KstyleUI units."],
		min = ICON_MIN, max = ICON_MAX, step = ICON_STEP, showWhen = IconShown,
	},
}

for _, list in ipairs({ LOOK, MORE }) do
	for _, row in ipairs(list) do
		schema[#schema + 1] = row
	end
end
Settings.schema = schema

local rows = {}
for _, row in ipairs(schema) do
	if row.key then
		rows[row.key] = row
	end
end

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local paths = {}

local function Lookup(root, key)
	local parts = paths[key]
	if not parts then
		parts = {}
		for part in key:gmatch("[^%.]+") do
			parts[#parts + 1] = part
		end
		paths[key] = parts
	end
	for i = 1, #parts do
		if type(root) ~= "table" then
			return nil
		end
		root = root[parts[i]]
	end
	return root
end

local function Unit(v)
	return not IsSecret(v) and type(v) == "number" and v >= 0 and v <= 1
end

local VALID = {
	toggle = function(_, v)
		return type(v) == "boolean"
	end,
	slider = function(row, v)
		return not IsSecret(v) and type(v) == "number" and v == v and v >= row.min and v <= row.max
	end,
	dropdown = function(row, v)
		for _, option in ipairs(row.options) do
			if option.value == v then
				return true
			end
		end
		return false
	end,
	color = function(_, v)
		return type(v) == "table" and Unit(v.r) and Unit(v.g) and Unit(v.b)
	end,
	font = function(_, v)
		return type(v) == "string" and v ~= ""
	end,
	texture = function(_, v)
		return type(v) == "string" and v ~= ""
	end,
}

local logged = {}

function Settings.Get(key)
	local default = Lookup(Settings.defaults, key)
	if default == nil then
		error("KstyleUI_Tooltips Settings.Get: unknown setting " .. tostring(key), 2)
	end
	local Store = K.Store
	if not Store.IsLoaded() then
		return default
	end
	local value = Lookup(Store.Module(MODULE), key)
	local row = rows[key]
	if IsSecret(value) then
		value = nil
	end
	if row and value ~= nil and VALID[row.type](row, value) then
		return value
	end
	if not row and type(value) == type(default) then
		return value
	end
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log(MODULE, "ignored the saved " .. key .. ", which is not allowed; using the default")
	end
	return default
end

function Settings.Accent()
	if Settings.Get("accentSource") == "custom" then
		local c = Settings.Get("accentColor")
		return c.r, c.g, c.b
	end
	return K.Theme.Accent()
end

function Settings.Log(message)
	K.DevTest.Log(MODULE, message)
end

local once = {}
function Settings.LogOnce(id, message)
	if not once[id] then
		once[id] = true
		Settings.Log(message)
	end
end
