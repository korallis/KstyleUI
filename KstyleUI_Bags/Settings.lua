-- Settings.lua: KstyleUI_Bags' defaults, its settings page and checked reads of each setting.
local _, ns = ...

local K = KstyleUI
local L, Tokens = ns.L, K.Tokens
local floor, max, min = math.floor, math.max, math.min

local Settings = {}
ns.Settings = Settings

Settings.MODULE = "Bags"

local COLUMNS_MIN, COLUMNS_MAX = 4, 24
local SLOT_MIN, SLOT_MAX = 24, 48
local SPACING_MIN, SPACING_MAX = 0, 12
local ROWS_MAX = 20
local FONT_MIN, FONT_MAX = 6, 20
local QUALITY = { POOR = 0, COMMON = 1, UNCOMMON = 2, RARE = 3, EPIC = 4, LEGENDARY = 5 }

local accentR, accentG, accentB = Tokens.Color("accentDefault")
local numberFont = Tokens.Font("number")

Settings.LIMITS = {
	columns = { COLUMNS_MIN, COLUMNS_MAX },
	bankColumns = { COLUMNS_MIN, COLUMNS_MAX },
	slotSize = { SLOT_MIN, SLOT_MAX },
	spacing = { SPACING_MIN, SPACING_MAX },
	rows = { 0, ROWS_MAX },
	fontSize = { FONT_MIN, FONT_MAX },
}

Settings.defaults = {
	enabled = false,
	layout = "categories",
	emptySlots = "packed",
	columns = 10,
	slotSize = Tokens.Size("actionButton"),
	spacing = Tokens.Size("gapSmall"),
	rows = 0,
	growth = "RIGHT_DOWN",
	showCount = true,
	showItemLevel = true,
	showQuality = true,
	qualityMin = QUALITY.UNCOMMON,
	showNewGlow = true,
	showJunk = true,
	showKeyring = true,
	font = numberFont,
	fontSize = Tokens.Size("number"),
	fontOutline = "NONE",
	accentSource = "class",
	accentColor = { r = accentR, g = accentG, b = accentB },
	sortDirection = "LEFT",
	bankColumns = 14,
	bankOpensBags = true,
	replaceBank = true,
	autoSellJunk = false,
	altCounts = true,
	custom1 = { name = "", rule = "" },
	custom2 = { name = "", rule = "" },
	custom3 = { name = "", rule = "" },
}

Settings.CUSTOM = { "custom1", "custom2", "custom3" }
local CUSTOM_LETTERS = 60

local GROWTH_OPTIONS = {
	{ value = "RIGHT_DOWN", label = L["Right, then down"] },
	{ value = "LEFT_DOWN", label = L["Left, then down"] },
	{ value = "RIGHT_UP", label = L["Right, then up"] },
	{ value = "LEFT_UP", label = L["Left, then up"] },
}
local QUALITY_OPTIONS = {
	{ value = QUALITY.POOR, label = L["Poor and better"] },
	{ value = QUALITY.COMMON, label = L["Common and better"] },
	{ value = QUALITY.UNCOMMON, label = L["Uncommon and better"] },
	{ value = QUALITY.RARE, label = L["Rare and better"] },
	{ value = QUALITY.EPIC, label = L["Epic and better"] },
	{ value = QUALITY.LEGENDARY, label = L["Legendary and better"] },
}
local OUTLINE_OPTIONS = {
	{ value = "NONE", label = L["Soft shadow"] },
	{ value = "OUTLINE", label = L["Thin outline"] },
	{ value = "THICKOUTLINE", label = L["Thick outline"] },
}
local ACCENT_OPTIONS = {
	{ value = "class", label = L["Class colour"] },
	{ value = "custom", label = L["Custom colour"] },
}
local LAYOUT_OPTIONS = {
	{ value = "categories", label = L["Sections by item type"] },
	{ value = "grid", label = L["One grid"] },
}
local EMPTY_OPTIONS = {
	{ value = "packed", label = L["One slot per bag"] },
	{ value = "all", label = L["Every empty slot"] },
}
local SORT_OPTIONS = {
	{ value = "LEFT", label = L["Left to right"] },
	{ value = "RIGHT", label = L["Right to left"] },
}

local function Choices(list)
	local set = {}
	for _, option in ipairs(list) do
		set[option.value] = true
	end
	return set
end

local CHOICES = {
	layout = Choices(LAYOUT_OPTIONS),
	emptySlots = Choices(EMPTY_OPTIONS),
	growth = Choices(GROWTH_OPTIONS),
	qualityMin = Choices(QUALITY_OPTIONS),
	fontOutline = Choices(OUTLINE_OPTIONS),
	accentSource = Choices(ACCENT_OPTIONS),
	sortDirection = Choices(SORT_OPTIONS),
}

local function isOff(settings)
	return not settings.enabled
end

local function customAccent(settings)
	return settings.accentSource == "custom"
end

local function qualityOn(settings)
	return settings.showQuality == true
end

Settings.schema = {
	{ type = "header", label = L["Bags"] },
	{ type = "toggle", key = "enabled", label = L["KstyleUI bags"], help = L["Replace Blizzard's bags with one KstyleUI bag window."] },
	{ type = "header", label = L["Slots"] },
	{
		type = "dropdown", key = "layout", label = L["Layout"], help = L["Sort items into sections by type, or show one grid."],
		options = LAYOUT_OPTIONS, disableWhen = isOff,
	},
	{
		type = "dropdown", key = "emptySlots", label = L["Empty slots"], help = L["In sections, show one empty slot per bag to drop onto, or every empty slot."],
		options = EMPTY_OPTIONS, disableWhen = isOff,
	},
	{
		type = "slider", key = "columns", label = L["Columns"], help = L["How many slots sit in each row of the bag window."],
		min = COLUMNS_MIN, max = COLUMNS_MAX, step = 1, disableWhen = isOff,
	},
	{
		type = "slider", key = "rows", label = L["Rows shown"], help = L["How many rows show before the grid or the sections scroll; 0 fits the screen."],
		min = 0, max = ROWS_MAX, step = 1, disableWhen = isOff,
	},
	{
		type = "slider", key = "slotSize", label = L["Slot size"], help = L["The size of each item slot."],
		min = SLOT_MIN, max = SLOT_MAX, step = 1, disableWhen = isOff,
	},
	{
		type = "slider", key = "spacing", label = L["Spacing"], help = L["The gap between item slots."],
		min = SPACING_MIN, max = SPACING_MAX, step = 1, disableWhen = isOff,
	},
	{
		type = "dropdown", key = "growth", label = L["Growth"], help = L["The way the grid fills from its first slot."],
		options = GROWTH_OPTIONS, disableWhen = isOff,
	},
	{ type = "header", label = L["Custom categories"] },
	{ type = "header", label = L["Slot text"] },
	{ type = "toggle", key = "showCount", label = L["Stack counts"], help = L["Show how many items are in each stack."], disableWhen = isOff },
	{ type = "toggle", key = "showItemLevel", label = L["Item levels"], help = L["Show the item level of weapons and armour."], disableWhen = isOff },
	{ type = "font", key = "font", label = L["Font"], help = L["The font of stack counts and item levels."], disableWhen = isOff },
	{
		type = "slider", key = "fontSize", label = L["Font size"], help = L["The size of stack counts and item levels."],
		min = FONT_MIN, max = FONT_MAX, step = 1, disableWhen = isOff,
	},
	{
		type = "dropdown", key = "fontOutline", label = L["Font outline"], help = L["A soft shadow or an outline behind slot text."],
		options = OUTLINE_OPTIONS, disableWhen = isOff,
	},
	{ type = "header", label = L["Markers"] },
	{ type = "toggle", key = "showQuality", label = L["Quality borders"], help = L["Colour each slot's border by the item's quality."], disableWhen = isOff },
	{
		type = "dropdown", key = "qualityMin", label = L["Coloured from"], help = L["The lowest quality whose border is coloured."],
		options = QUALITY_OPTIONS, showWhen = qualityOn, disableWhen = isOff,
	},
	{ type = "toggle", key = "showNewGlow", label = L["New item glow"], help = L["Make items you just got glow until you point at them."], disableWhen = isOff },
	{ type = "toggle", key = "showJunk", label = L["Junk marker"], help = L["Mark grey items that sell for money."], disableWhen = isOff },
	{ type = "toggle", key = "showKeyring", label = L["Keyring"], help = L["Show the keyring's slots under your bags."], disableWhen = isOff },
	{ type = "header", label = L["Junk"] },
	{
		type = "toggle", key = "autoSellJunk", label = L["Sell junk by itself"],
		help = L["Sell grey items as soon as you open a merchant, out of combat only."], disableWhen = isOff,
	},
	{ type = "header", label = L["Other characters"] },
	{
		type = "toggle", key = "altCounts", label = L["Counts in tooltips"],
		help = L["Show how many of an item your other characters hold, from the bags and bank KstyleUI last saw."], disableWhen = isOff,
	},
	{ type = "header", label = L["Accent"] },
	{
		type = "dropdown", key = "accentSource", label = L["Accent colour"], help = L["The colour of the window's hairlines and the new item glow."],
		options = ACCENT_OPTIONS, disableWhen = isOff,
	},
	{
		type = "color", key = "accentColor", label = L["Custom accent"], help = L["The accent colour when it does not follow your class."],
		showWhen = customAccent, disableWhen = isOff,
	},
	{ type = "header", label = L["Bank"] },
	{
		type = "toggle", key = "replaceBank", label = L["KstyleUI bank"],
		help = L["Replace Blizzard's bank window; a change takes effect after a reload."], disableWhen = isOff,
	},
	{
		type = "slider", key = "bankColumns", label = L["Bank columns"], help = L["How many slots sit in each row of the bank window."],
		min = COLUMNS_MIN, max = COLUMNS_MAX, step = 1, disableWhen = isOff,
	},
	{ type = "toggle", key = "bankOpensBags", label = L["Bank opens bags"], help = L["Open your bags beside the bank when you visit a banker."], disableWhen = isOff },
	{ type = "header", label = L["Sorting"] },
	{
		type = "dropdown", key = "sortDirection", label = L["Sort direction"], help = L["The way Sort packs items across your bags."],
		options = SORT_OPTIONS, disableWhen = isOff,
	},
}

do
	local at
	for i, row in ipairs(Settings.schema) do
		if row.type == "header" and row.label == L["Custom categories"] then
			at = i
		end
	end
	local CUSTOM_LABELS = { L["Category 1"], L["Category 2"], L["Category 3"] }
	for i = #Settings.CUSTOM, 1, -1 do
		local key = Settings.CUSTOM[i]
		table.insert(Settings.schema, at + 1, {
			type = "text", key = key .. ".rule", label = L["Rule"], maxLetters = CUSTOM_LETTERS,
			help = L["Items this search matches fill the section: & both, | either, ! not, type:, ilvl>30, junk, bound."],
			disableWhen = isOff,
		})
		table.insert(Settings.schema, at + 1, {
			type = "text", key = key .. ".name", label = CUSTOM_LABELS[i], maxLetters = CUSTOM_LETTERS,
			help = L["The section's name. A named category with a rule sorts before the built-in sections."],
			disableWhen = isOff,
		})
	end
end

local function Plain(value, kind)
	return ns.Data.Plain(value, kind)
end

function Settings.Custom()
	local all = Settings.All()
	local list = {}
	for _, key in ipairs(Settings.CUSTOM) do
		local entry = all[key]
		local name = type(entry) == "table" and Plain(entry.name, "string") or nil
		local rule = type(entry) == "table" and ns.Data.Query(entry.rule) or nil
		if name and name ~= "" and rule then
			list[#list + 1] = { key = key, label = name, rule = rule }
		end
	end
	return list
end

function Settings.All()
	local Store = K.Store
	if Store and Store.IsLoaded and Store.IsLoaded() then
		return Store.Module(Settings.MODULE)
	end
	return Settings.defaults
end

function Settings.Get(key)
	local default = Settings.defaults[key]
	if default == nil then
		error("KstyleUI_Bags Settings.Get: unknown setting " .. tostring(key), 2)
	end
	local value = Settings.All()[key]
	local limits = Settings.LIMITS[key]
	if limits then
		value = Plain(value, "number")
		if not value then
			return default
		end
		return max(limits[1], min(limits[2], floor(value + 0.5)))
	end
	local choices = CHOICES[key]
	if choices then
		return choices[value] and value or default
	end
	if type(value) ~= type(default) then
		return default
	end
	return value
end

local function Channel(value)
	value = Plain(value, "number")
	if not value or value < 0 or value > 1 then
		return nil
	end
	return value
end

function Settings.Accent()
	if Settings.Get("accentSource") == "custom" then
		local color = Settings.Get("accentColor")
		local r, g, b = Channel(color.r), Channel(color.g), Channel(color.b)
		if r and g and b then
			return r, g, b
		end
	end
	return K.Theme.Accent()
end

function Settings.Font()
	local outline = Settings.Get("fontOutline")
	local path = Settings.Get("font")
	if path == "" then
		path = numberFont
	end
	return path, Settings.Get("fontSize"), outline == "NONE" and "" or outline
end
