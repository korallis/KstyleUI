-- Settings.lua: the action bars' defaults and the schema the settings window builds the Action Bars page from.
local _, ns = ...

local K = KstyleUI
local L, Tokens = K.L, K.Tokens

local SMALL_BUTTON = 30
local SIZE_MIN, SIZE_MAX = 16, 64
local SPACING_MAX = 16
local FADE_STEP = 0.05
local FONT_MIN, FONT_MAX = 6, 24
local COOLDOWN_TEXT = 13
local PAGING_LETTERS = 255
local COLUMN_BARS = { bar3 = true, bar4 = true, bar5 = true, bar6 = true }
local ON_BY_DEFAULT = { bar1 = true, bar2 = true, pet = true, stance = true }

ns.TEXTS = {
	{ key = "hotkey", role = "caption", label = L["Keybind text"] },
	{ key = "count", role = "number", label = L["Count text"] },
	{ key = "macro", role = "caption", label = L["Macro name text"] },
	{ key = "cooldown", role = "number", label = L["Cooldown numbers"] },
}

local function Color(name)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b }
end

local function BarDefaults(def)
	local action = def.kind == "action"
	local out = {
		enabled = ON_BY_DEFAULT[def.key] == true,
		buttons = def.max,
		rows = COLUMN_BARS[def.key] and def.max or 1,
		orientation = "HORIZONTAL",
		growth = "RIGHTDOWN",
		size = action and Tokens.Size("actionButton") or SMALL_BUTTON,
		spacing = Tokens.Size("actionGap"),
		fade = false,
		fadeAlpha = 0,
		hotkey = true,
		cooldown = true,
	}
	if def.kind ~= "stance" then
		out.showEmpty = true
	end
	if action then
		out.count = true
		out.macro = false
		out.paging = ""
	end
	if def.paged then
		out.pageForms = true
		out.pageStealth = true
		out.pagePossess = true
		out.pageKeys = true
	end
	return out
end

local defaults = {
	editBar = "bar1",
	accent = "theme",
	accentColor = Color("accentDefault"),
	rangeColor = Color("hostile"),
	powerColor = Color("rare"),
	tooltips = "always",
	text = {
		hotkey = { font = "", size = Tokens.Size("caption"), outline = "NONE" },
		count = { font = "", size = Tokens.Size("number"), outline = "NONE" },
		macro = { font = "", size = Tokens.Size("caption"), outline = "NONE" },
		cooldown = { font = "", size = COOLDOWN_TEXT, outline = "NONE" },
	},
}
for _, def in ipairs(ns.BARS) do
	defaults[def.key] = BarDefaults(def)
end
ns.defaults = defaults

local function Label(def)
	local element = K.Setup and K.Setup.Layouts and K.Setup.Layouts.Element(def.element)
	return element and element.label or def.key
end
ns.Label = Label

local function FontOptions()
	local out = { { value = "", label = L["Interface font"] } }
	local media = K.Widgets.MediaOptions and K.Widgets.MediaOptions("font") or {}
	for _, option in ipairs(media) do
		out[#out + 1] = option
	end
	return out
end

local OUTLINE_OPTIONS = {
	{ value = "NONE", label = L["Soft shadow"] },
	{ value = "OUTLINE", label = L["Thin outline"] },
	{ value = "THICK", label = L["Thick outline"] },
}
local ORIENTATION_OPTIONS = {
	{ value = "HORIZONTAL", label = L["Along rows first"] },
	{ value = "VERTICAL", label = L["Down columns first"] },
}
local GROWTH_OPTIONS = {
	{ value = "RIGHTDOWN", label = L["Right, then down"] },
	{ value = "RIGHTUP", label = L["Right, then up"] },
	{ value = "LEFTDOWN", label = L["Left, then down"] },
	{ value = "LEFTUP", label = L["Left, then up"] },
}

local function Editing(key)
	return function(settings)
		return settings.editBar == key
	end
end

local function BarRows(schema, def)
	local key = def.key
	local editing = Editing(key)
	local function Off(settings)
		return not settings[key].enabled
	end
	local function add(row)
		row.showWhen = row.showWhen or editing
		if row.type ~= "header" and row.key ~= key .. ".enabled" then
			row.disableWhen = Off
		end
		schema[#schema + 1] = row
	end
	add({ type = "header", label = Label(def) })
	add({ type = "toggle", key = key .. ".enabled", label = L["Show this bar"], help = L["Turns this bar on or off."] })
	add({ type = "slider", key = key .. ".buttons", label = L["Buttons"], help = L["How many buttons the bar shows."], min = 1, max = def.max, step = 1 })
	add({ type = "slider", key = key .. ".rows", label = L["Rows"], help = L["How many rows the buttons fill; the columns follow."], min = 1, max = def.max, step = 1 })
	add({ type = "dropdown", key = key .. ".orientation", label = L["Fill order"], help = L["Whether buttons fill each row or each column first."], options = ORIENTATION_OPTIONS })
	add({ type = "dropdown", key = key .. ".growth", label = L["Growth"], help = L["The direction the buttons grow from the first one."], options = GROWTH_OPTIONS })
	add({ type = "slider", key = key .. ".size", label = L["Button size"], help = L["The size of each button."], min = SIZE_MIN, max = SIZE_MAX, step = 1 })
	add({ type = "slider", key = key .. ".spacing", label = L["Spacing"], help = L["The gap between buttons."], min = 0, max = SPACING_MAX, step = 1 })
	if def.kind ~= "stance" then
		add({ type = "toggle", key = key .. ".showEmpty", label = L["Show empty buttons"], help = L["Shows slots with no action as empty tiles."] })
	end
	add({ type = "toggle", key = key .. ".fade", label = L["Fade until hovered"], help = L["Fades the bar until the pointer is over it."] })
	add({
		type = "slider", key = key .. ".fadeAlpha", label = L["Faded opacity"], help = L["How visible the bar stays while faded."],
		min = 0, max = 1, step = FADE_STEP,
		showWhen = function(settings)
			return settings.editBar == key and settings[key].fade
		end,
	})
	add({ type = "toggle", key = key .. ".hotkey", label = L["Keybind text"], help = L["Shows the key bound to each button."] })
	if def.kind == "action" then
		add({ type = "toggle", key = key .. ".count", label = L["Count text"], help = L["Shows item counts and spell charges."] })
		add({ type = "toggle", key = key .. ".macro", label = L["Macro names"], help = L["Shows the name of each macro."] })
	end
	add({ type = "toggle", key = key .. ".cooldown", label = L["Cooldown numbers"], help = L["Shows the time left on each cooldown."] })
	if def.paged then
		local function Custom(settings)
			return settings[key].paging ~= ""
		end
		add({ type = "header", label = L["Paging"] })
		add({ type = "toggle", key = key .. ".pageForms", label = L["Stances and forms"], help = L["Swaps the bar when you change stance or form."], disableWhen = Custom })
		add({ type = "toggle", key = key .. ".pageStealth", label = L["Stealth"], help = L["Swaps the bar while you are stealthed or prowling."], disableWhen = Custom })
		add({ type = "toggle", key = key .. ".pagePossess", label = L["Possess and vehicles"], help = L["Shows possess, vehicle and override actions on this bar."], disableWhen = Custom })
		add({ type = "toggle", key = key .. ".pageKeys", label = L["Page keys"], help = L["Follows the keys that change the action page."], disableWhen = Custom })
	end
	if def.kind == "action" then
		add({
			type = "text", key = key .. ".paging", label = L["Custom paging"], maxLetters = PAGING_LETTERS,
			help = L["Macro conditions such as [mod:alt] 2; 1. Empty uses the rules above."],
		})
	end
end

local function EditOptions()
	local out = {}
	for i, def in ipairs(ns.BARS) do
		out[i] = { value = def.key, label = Label(def) }
	end
	return out
end

function ns.Schema()
	local schema = {
		{ type = "header", label = L["Bars"] },
		{ type = "dropdown", key = "editBar", label = L["Bar to edit"], help = L["Choose the bar the settings below change."], options = EditOptions() },
	}
	for _, def in ipairs(ns.BARS) do
		BarRows(schema, def)
	end
	schema[#schema + 1] = { type = "header", label = L["Text"] }
	for _, text in ipairs(ns.TEXTS) do
		local base = "text." .. text.key
		schema[#schema + 1] = { type = "dropdown", key = base .. ".font", label = text.label .. ": " .. L["font"], help = L["The font of this text on every bar."], options = FontOptions }
		schema[#schema + 1] = { type = "slider", key = base .. ".size", label = text.label .. ": " .. L["size"], help = L["The size of this text, before the interface text size."], min = FONT_MIN, max = FONT_MAX, step = 1 }
		schema[#schema + 1] = { type = "dropdown", key = base .. ".outline", label = text.label .. ": " .. L["outline"], help = L["A soft shadow, or an outline for busy scenes."], options = OUTLINE_OPTIONS }
	end
	local function NotCustom(settings)
		return settings.accent ~= "custom"
	end
	local list = {
		{ type = "header", label = L["Colours"] },
		{
			type = "dropdown", key = "accent", label = L["Accent"], help = L["The colour of the button edges and proc glows."],
			options = {
				{ value = "theme", label = L["Interface accent"] },
				{ value = "class", label = L["Class colour"] },
				{ value = "custom", label = L["Custom colour"] },
			},
		},
		{ type = "color", key = "accentColor", label = L["Custom accent"], help = L["The accent used when Accent is set to custom."], disableWhen = NotCustom },
		{ type = "color", key = "rangeColor", label = L["Out of range"], help = L["Tints an action whose target is out of range."] },
		{ type = "color", key = "powerColor", label = L["Not enough power"], help = L["Tints an action you lack the mana, rage or energy for."] },
		{ type = "header", label = L["Tooltips"] },
		{
			type = "dropdown", key = "tooltips", label = L["Action tooltips"], help = L["When hovering a button shows its tooltip."],
			options = {
				{ value = "always", label = L["Always"] },
				{ value = "noCombat", label = L["Out of combat only"] },
				{ value = "never", label = L["Never"] },
			},
		},
	}
	for _, row in ipairs(list) do
		schema[#schema + 1] = row
	end
	return schema
end
