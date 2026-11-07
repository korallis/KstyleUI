-- Settings.lua: the module's defaults, its settings page and checked reads of each setting.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local MODULE = "Tooltips"
ns.MODULE = MODULE

local SIZE_MIN, SIZE_MAX, SIZE_STEP = 8, 32, 1
local OFFSET_MIN, OFFSET_MAX, OFFSET_STEP = -64, 64, 1
local TITLE_SIZE, BODY_SIZE, SMALL_SIZE = 16, 13, 11

local FACE = Tokens.FontPath(Tokens.DEFAULT_FONT_FACE)
local accentR, accentG, accentB = Tokens.Color("accentDefault")

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
	qualityEdge = true,
	divider = true,
	softColors = true,
	accentSource = "class",
	accentColor = { r = accentR, g = accentG, b = accentB },
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
		help = L["The colour of the title divider: your class colour or one you pick."],
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
for _, row in ipairs(LOOK) do
	schema[#schema + 1] = row
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
