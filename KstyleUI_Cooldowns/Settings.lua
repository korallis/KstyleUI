-- Settings.lua: the Cooldowns defaults, the settings page schema, and clean reads of the saved values.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local floor, max, min = math.floor, math.max, math.min

local GAP = Tokens.Size("actionGap")
local ICON_GROUPS = { "essential", "utility" }
Settings.ICON_GROUPS = ICON_GROUPS

local RANGE = {
	size = { 16, 64, 1 },
	spacing = { 0, 12, 1 },
	columns = { 1, 12, 1 },
	rows = { 1, 4, 1 },
	timerSize = { 6, 32, 1 },
	countSize = { 6, 24, 1 },
}

local GROWTH = { center = true, right = true, left = true }
local WRAP = { down = true, up = true }
local OUTLINE = { none = true, OUTLINE = true, THICKOUTLINE = true }
local ACCENT = { class = true, custom = true }

local accentR, accentG, accentB = Tokens.Color("accentDefault")

local function IconDefaults(size, timerSize, countSize, readyGlow)
	return {
		size = size,
		spacing = GAP,
		columns = 6,
		rows = 1,
		growth = "center",
		wrap = "down",
		timer = true,
		timerSize = timerSize,
		countSize = countSize,
		gcd = false,
		desaturate = true,
		usable = true,
		readyGlow = readyGlow,
		procGlow = true,
	}
end

Settings.defaults = {
	accent = "class",
	accentColor = { r = accentR, g = accentG, b = accentB },
	tooltips = true,
	timerFont = "kit",
	timerOutline = "none",
	countFont = "kit",
	countOutline = "none",
	essential = IconDefaults(Tokens.Size("cooldownEssential"), 16, 12, true),
	utility = IconDefaults(Tokens.Size("cooldownUtility"), 12, 10, false),
}

local function FontOptions()
	local out = { { value = "kit", label = L["KstyleUI number font"] } }
	local media = K.Widgets and K.Widgets.MediaOptions
	if media then
		local ok, list = pcall(media, "font")
		if ok and type(list) == "table" then
			for _, option in ipairs(list) do
				if type(option.value) == "string" then
					out[#out + 1] = { value = option.value, label = tostring(option.label) }
				end
			end
		end
	end
	return out
end

local OUTLINE_OPTIONS = {
	{ value = "none", label = L["Soft shadow"] },
	{ value = "OUTLINE", label = L["Thin outline"] },
	{ value = "THICKOUTLINE", label = L["Thick outline"] },
}
local GROWTH_OPTIONS = {
	{ value = "center", label = L["Centred"] },
	{ value = "right", label = L["Left to right"] },
	{ value = "left", label = L["Right to left"] },
}
local WRAP_OPTIONS = {
	{ value = "down", label = L["New rows below"] },
	{ value = "up", label = L["New rows above"] },
}

local function IsCustomAccent(settings)
	return settings.accent == "custom"
end

local function Slider(group, key, label, help)
	local range = RANGE[key]
	return { type = "slider", key = group .. "." .. key, label = label, help = help, min = range[1], max = range[2], step = range[3] }
end

local function Toggle(group, key, label, help)
	return { type = "toggle", key = group .. "." .. key, label = label, help = help }
end

local function IconRows(schema, group, title)
	schema[#schema + 1] = { type = "header", label = title }
	schema[#schema + 1] = Slider(group, "size", L["Icon size"], L["The width and height of each icon."])
	schema[#schema + 1] = Slider(group, "spacing", L["Spacing"], L["The gap between icons."])
	schema[#schema + 1] = Slider(group, "columns", L["Icons per row"], L["How many icons fit on one row."])
	schema[#schema + 1] = Slider(group, "rows", L["Rows"], L["How many rows the group may use."])
	schema[#schema + 1] = { type = "dropdown", key = group .. ".growth", label = L["Growth"], help = L["Where a short row starts."], options = GROWTH_OPTIONS }
	schema[#schema + 1] = { type = "dropdown", key = group .. ".wrap", label = L["Wrap"], help = L["Whether extra rows go below or above the first."], options = WRAP_OPTIONS }
	schema[#schema + 1] = Toggle(group, "timer", L["Timers"], L["Show the seconds left on each cooldown."])
	schema[#schema + 1] = Slider(group, "timerSize", L["Timer size"], L["The size of the cooldown numbers."])
	schema[#schema + 1] = Slider(group, "countSize", L["Charge size"], L["The size of the charge count."])
	schema[#schema + 1] = Toggle(group, "gcd", L["Global cooldown"], L["Sweep every icon during the global cooldown."])
	schema[#schema + 1] = Toggle(group, "desaturate", L["Grey while cooling"], L["Show an icon in grey while its spell is on cooldown."])
	schema[#schema + 1] = Toggle(group, "usable", L["Dim unusable"], L["Dim an icon while you cannot cast its spell."])
	schema[#schema + 1] = Toggle(group, "readyGlow", L["Ready glow"], L["A soft accent glow around a spell that is ready."])
	schema[#schema + 1] = Toggle(group, "procGlow", L["Proc glow"], L["Pulse an icon while the game highlights its spell."])
end

local schema = {
	{ type = "header", label = L["Cooldown Manager"] },
	{
		type = "dropdown", key = "accent", label = L["Accent"],
		help = L["Glows and hairlines use your class colour or a colour you pick."],
		options = { { value = "class", label = L["Class colour"] }, { value = "custom", label = L["Custom colour"] } },
	},
	{ type = "color", key = "accentColor", label = L["Custom accent"], help = L["The colour of glows and hairlines when the accent is custom."], showWhen = IsCustomAccent },
	{ type = "toggle", key = "tooltips", label = L["Tooltips"], help = L["Show a spell's tooltip when the pointer is over its icon."] },
	{ type = "header", label = L["Text"] },
	{ type = "dropdown", key = "timerFont", label = L["Timer font"], help = L["The font of the cooldown numbers."], options = FontOptions },
	{ type = "dropdown", key = "timerOutline", label = L["Timer outline"], help = L["A soft shadow, or an outline for busy backgrounds."], options = OUTLINE_OPTIONS },
	{ type = "dropdown", key = "countFont", label = L["Count font"], help = L["The font of charge and stack counts."], options = FontOptions },
	{ type = "dropdown", key = "countOutline", label = L["Count outline"], help = L["A soft shadow, or an outline for busy backgrounds."], options = OUTLINE_OPTIONS },
}
IconRows(schema, "essential", L["Essential cooldowns"])
IconRows(schema, "utility", L["Utility cooldowns"])
Settings.schema = schema
Settings.FontOptions = FontOptions

local function Section()
	local Store = K.Store
	if Store and Store.IsLoaded and Store.IsLoaded() then
		local ok, section = pcall(Store.Module, ns.MODULE)
		if ok and type(section) == "table" then
			return section
		end
	end
	return Settings.defaults
end

local function Number(value, key, fallback)
	local range = RANGE[key]
	if type(value) ~= "number" or ns.IsSecret(value) or value ~= value then
		return fallback
	end
	value = min(range[2], max(range[1], value))
	return floor(value / range[3] + 0.5) * range[3]
end

local function Choice(value, allowed, fallback)
	if allowed[value] then
		return value
	end
	return fallback
end

local function Bool(value, fallback)
	if type(value) == "boolean" then
		return value
	end
	return fallback
end

local function Unit(value)
	return type(value) == "number" and not ns.IsSecret(value) and value >= 0 and value <= 1
end

local function Font(value)
	if value == "kit" then
		return value
	end
	if type(value) == "string" and K.Theme.IsFontPath(value) then
		return value
	end
	return "kit"
end

local current = { essential = {}, utility = {} }
Settings.current = current

local function ReadIcons(out, saved, defaults)
	saved = type(saved) == "table" and saved or defaults
	for key in pairs(RANGE) do
		out[key] = Number(saved[key], key, defaults[key])
	end
	out.growth = Choice(saved.growth, GROWTH, defaults.growth)
	out.wrap = Choice(saved.wrap, WRAP, defaults.wrap)
	for _, key in ipairs({ "timer", "gcd", "desaturate", "usable", "readyGlow", "procGlow" }) do
		out[key] = Bool(saved[key], defaults[key])
	end
	out.cellWidth, out.cellHeight = out.size, out.size
end

function Settings.Read()
	local saved, defaults = Section(), Settings.defaults
	current.accent = Choice(saved.accent, ACCENT, defaults.accent)
	local color = saved.accentColor
	if type(color) == "table" and Unit(color.r) and Unit(color.g) and Unit(color.b) then
		current.accentR, current.accentG, current.accentB = color.r, color.g, color.b
	else
		local d = defaults.accentColor
		current.accentR, current.accentG, current.accentB = d.r, d.g, d.b
	end
	current.tooltips = Bool(saved.tooltips, defaults.tooltips)
	current.timerFont = Font(saved.timerFont)
	current.countFont = Font(saved.countFont)
	current.timerOutline = Choice(saved.timerOutline, OUTLINE, defaults.timerOutline)
	current.countOutline = Choice(saved.countOutline, OUTLINE, defaults.countOutline)
	for _, group in ipairs(ICON_GROUPS) do
		ReadIcons(current[group], saved[group], defaults[group])
	end
	return current
end

function Settings.Accent()
	if current.accent == "custom" and current.accentR then
		return current.accentR, current.accentG, current.accentB
	end
	return K.Theme.Accent()
end
