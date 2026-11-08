-- Settings.lua: the Cooldowns defaults, the settings page schema, and clean reads of the saved values.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local floor, max, min = math.floor, math.max, math.min

local GAP = Tokens.Size("actionGap")
local ESSENTIAL_SIZE, ESSENTIAL_GAP = 44, 6
local UTILITY_SIZE, UTILITY_GAP, UTILITY_COLUMNS = 38, 6, 4
local ESSENTIAL_TIMER, ESSENTIAL_COUNT = 15, 12
local UTILITY_TIMER, UTILITY_COUNT = 13, 11
local BAR_WIDTH, BAR_HEIGHT = 195, 20
local BAR_FILL_ALPHA = 0.15
local GROUPS = { "essential", "utility", "buffs", "bars" }
local ICON_GROUPS = { "essential", "utility", "buffs" }
local COOLDOWN_GROUPS = { essential = true, utility = true }
Settings.AURA_GROUPS = { buffs = true, bars = true }
Settings.GROUPS = GROUPS
Settings.ICON_GROUPS = ICON_GROUPS
Settings.COOLDOWN_GROUPS = COOLDOWN_GROUPS

local ICON_RANGE = {
	size = { 16, 64, 1 },
	spacing = { 0, 12, 1 },
	columns = { 1, 12, 1 },
	rows = { 1, 4, 1 },
	timerSize = { 6, 32, 1 },
	countSize = { 6, 24, 1 },
}
local BAR_RANGE = {
	width = { 80, 400, 1 },
	height = { 8, 40, 1 },
	spacing = { 0, 12, 1 },
	count = { 1, 12, 1 },
	nameSize = { 6, 24, 1 },
	timerSize = { 6, 24, 1 },
	countSize = { 6, 24, 1 },
}
local ICON_FLAGS = { "timer", "gcd", "desaturate", "usable", "readyGlow", "procGlow", "inactive" }
local BAR_FLAGS = { "reverse", "icon", "name", "timer", "inactive" }

local PATH = { auto = true, mirror = true, reskin = true }
local GROWTH = { center = true, right = true, left = true }
local WRAP = { down = true, up = true }
local BAR_GROWTH = { up = true, down = true }
local OUTLINE = { none = true, OUTLINE = true, THICKOUTLINE = true }
local ACCENT = { class = true, custom = true }
local COLOR_SOURCE = { class = true, reaction = true, custom = true }
local ORIENTATION = { HORIZONTAL = true, VERTICAL = true }
local MAX_PATH = 260

local accentR, accentG, accentB = Tokens.Color("accentDefault")
local DEFAULT_BAR_TEXTURE = Tokens.MediaList("statusbar")[1].path

local function IconDefaults(size, timerSize, countSize, cooldown, spacing, columns)
	local out = {
		size = size,
		spacing = spacing or GAP,
		columns = columns or 6,
		rows = 1,
		growth = "center",
		wrap = cooldown and "down" or "up",
		timer = true,
		timerSize = timerSize,
		countSize = countSize,
	}
	if cooldown then
		out.gcd, out.desaturate, out.usable, out.readyGlow, out.procGlow = false, false, true, false, true
	else
		out.inactive = false
	end
	return out
end

local essential = IconDefaults(ESSENTIAL_SIZE, ESSENTIAL_TIMER, ESSENTIAL_COUNT, true, ESSENTIAL_GAP)
essential.readyGlow = true

Settings.defaults = {
	path = "auto",
	accent = "class",
	accentColor = { r = accentR, g = accentG, b = accentB },
	tooltips = true,
	timerFont = "kit",
	timerOutline = "none",
	countFont = "kit",
	countOutline = "none",
	nameFont = "kit",
	nameOutline = "none",
	essential = essential,
	utility = IconDefaults(UTILITY_SIZE, UTILITY_TIMER, UTILITY_COUNT, true, UTILITY_GAP, UTILITY_COLUMNS),
	buffs = IconDefaults(Tokens.Size("cooldownUtility"), 12, 10, false),
	bars = {
		width = BAR_WIDTH,
		height = BAR_HEIGHT,
		spacing = GAP,
		count = 2,
		growth = "down",
		texture = DEFAULT_BAR_TEXTURE,
		colorSource = "class",
		color = { r = accentR, g = accentG, b = accentB },
		orientation = "HORIZONTAL",
		reverse = false,
		icon = true,
		name = true,
		timer = true,
		inactive = false,
		nameSize = 11,
		timerSize = 11,
		countSize = 9,
	},
}

local function FontOptions()
	local out = { { value = "kit", label = L["KstyleUI font"] } }
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
Settings.FontOptions = FontOptions

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
local BAR_GROWTH_OPTIONS = {
	{ value = "up", label = L["Upward"] },
	{ value = "down", label = L["Downward"] },
}
local PATH_OPTIONS = {
	{ value = "auto", label = L["Automatic"] },
	{ value = "mirror", label = L["KstyleUI icons"] },
	{ value = "reskin", label = L["Restyle Blizzard's"] },
}
local COLOR_SOURCE_OPTIONS = {
	{ value = "class", label = L["Class colour"] },
	{ value = "reaction", label = L["Reaction colour"] },
	{ value = "custom", label = L["Custom colour"] },
}
local ORIENTATION_OPTIONS = {
	{ value = "HORIZONTAL", label = L["Horizontal"] },
	{ value = "VERTICAL", label = L["Vertical"] },
}

local function IsCustomAccent(settings)
	return settings.accent == "custom"
end

local function IsCustomBar(settings)
	return type(settings.bars) == "table" and settings.bars.colorSource == "custom"
end

local function Slider(group, key, label, help, range)
	range = range[key]
	return { type = "slider", key = group .. "." .. key, label = label, help = help, min = range[1], max = range[2], step = range[3] }
end

local function Toggle(group, key, label, help)
	return { type = "toggle", key = group .. "." .. key, label = label, help = help }
end

local function Add(schema, row)
	schema[#schema + 1] = row
end

local function IconRows(schema, group, title)
	Add(schema, { type = "header", label = title })
	Add(schema, Slider(group, "size", L["Icon size"], L["The width and height of each icon."], ICON_RANGE))
	Add(schema, Slider(group, "spacing", L["Spacing"], L["The gap between icons."], ICON_RANGE))
	Add(schema, Slider(group, "columns", L["Icons per row"], L["How many icons fit on one row."], ICON_RANGE))
	Add(schema, Slider(group, "rows", L["Rows"], L["How many rows the group may use."], ICON_RANGE))
	Add(schema, { type = "dropdown", key = group .. ".growth", label = L["Growth"], help = L["Where a short row starts."], options = GROWTH_OPTIONS })
	Add(schema, { type = "dropdown", key = group .. ".wrap", label = L["Wrap"], help = L["Whether extra rows go below or above the first."], options = WRAP_OPTIONS })
	Add(schema, Toggle(group, "timer", L["Timers"], L["Show the seconds left on each icon."]))
	Add(schema, Slider(group, "timerSize", L["Timer size"], L["The size of the countdown numbers."], ICON_RANGE))
	Add(schema, Slider(group, "countSize", L["Count size"], L["The size of the charge or stack count."], ICON_RANGE))
	if COOLDOWN_GROUPS[group] then
		Add(schema, Toggle(group, "gcd", L["Global cooldown"], L["Sweep every icon during the global cooldown."]))
		Add(schema, Toggle(group, "desaturate", L["Grey while cooling"], L["Show an icon in grey while its spell is on cooldown."]))
		Add(schema, Toggle(group, "usable", L["Dim unusable"], L["Dim an icon while you cannot cast its spell."]))
		Add(schema, Toggle(group, "readyGlow", L["Ready glow"], L["A soft accent glow around a spell that is ready."]))
		Add(schema, Toggle(group, "procGlow", L["Proc glow"], L["Pulse an icon while the game highlights its spell."]))
	else
		Add(schema, Toggle(group, "inactive", L["Show inactive"], L["Keep a buff's icon, dimmed, while the buff is not on you."]))
	end
end

local function BarRows(schema)
	local group = "bars"
	Add(schema, { type = "header", label = L["Tracked buff bars"] })
	Add(schema, Slider(group, "width", L["Bar width"], L["The width of each bar, icon included."], BAR_RANGE))
	Add(schema, Slider(group, "height", L["Bar height"], L["The height of each bar."], BAR_RANGE))
	Add(schema, Slider(group, "spacing", L["Spacing"], L["The gap between bars."], BAR_RANGE))
	Add(schema, Slider(group, "count", L["Bars"], L["How many bars fit in the group."], BAR_RANGE))
	Add(schema, { type = "dropdown", key = "bars.growth", label = L["Growth"], help = L["Whether new bars stack upward or downward."], options = BAR_GROWTH_OPTIONS })
	Add(schema, { type = "texture", key = "bars.texture", label = L["Bar texture"], help = L["The texture of the bar's fill."] })
	Add(schema, { type = "dropdown", key = "bars.colorSource", label = L["Bar colour"], help = L["Fill bars with your class colour, the friendly colour or a colour you pick."], options = COLOR_SOURCE_OPTIONS })
	Add(schema, { type = "color", key = "bars.color", label = L["Custom bar colour"], help = L["The fill colour when the bar colour is custom."], showWhen = IsCustomBar })
	Add(schema, { type = "dropdown", key = "bars.orientation", label = L["Orientation"], help = L["Whether the fill runs across or up the bar."], options = ORIENTATION_OPTIONS })
	Add(schema, Toggle(group, "reverse", L["Reverse fill"], L["Drain the fill from the other end."]))
	Add(schema, Toggle(group, "icon", L["Icon"], L["Show the buff's icon at the start of the bar."]))
	Add(schema, Toggle(group, "name", L["Name"], L["Show the buff's name on the bar."]))
	Add(schema, Toggle(group, "timer", L["Timer"], L["Show the seconds left on the bar."]))
	Add(schema, Toggle(group, "inactive", L["Show inactive"], L["Keep a bar, empty, while the buff is not on you."]))
	Add(schema, Slider(group, "nameSize", L["Name size"], L["The size of the buff's name."], BAR_RANGE))
	Add(schema, Slider(group, "timerSize", L["Timer size"], L["The size of the seconds left."], BAR_RANGE))
	Add(schema, Slider(group, "countSize", L["Count size"], L["The size of the stack count."], BAR_RANGE))
end

local schema = {
	{ type = "header", label = L["Cooldown Manager"] },
	{
		type = "dropdown", key = "path", label = L["Display"],
		help = L["Automatic uses KstyleUI icons where the game allows it in combat."],
		options = PATH_OPTIONS,
	},
	{
		type = "dropdown", key = "accent", label = L["Accent"],
		help = L["Glows and hairlines use your class colour or a colour you pick."],
		options = { { value = "class", label = L["Class colour"] }, { value = "custom", label = L["Custom colour"] } },
	},
	{ type = "color", key = "accentColor", label = L["Custom accent"], help = L["The colour of glows and hairlines when the accent is custom."], showWhen = IsCustomAccent },
	{ type = "toggle", key = "tooltips", label = L["Tooltips"], help = L["Show a spell's tooltip when the pointer is over its icon."] },
	{ type = "header", label = L["Text"] },
	{ type = "dropdown", key = "timerFont", label = L["Timer font"], help = L["The font of the countdown numbers."], options = FontOptions },
	{ type = "dropdown", key = "timerOutline", label = L["Timer outline"], help = L["A soft shadow, or an outline for busy backgrounds."], options = OUTLINE_OPTIONS },
	{ type = "dropdown", key = "countFont", label = L["Count font"], help = L["The font of charge and stack counts."], options = FontOptions },
	{ type = "dropdown", key = "countOutline", label = L["Count outline"], help = L["A soft shadow, or an outline for busy backgrounds."], options = OUTLINE_OPTIONS },
	{ type = "dropdown", key = "nameFont", label = L["Name font"], help = L["The font of the names on buff bars."], options = FontOptions },
	{ type = "dropdown", key = "nameOutline", label = L["Name outline"], help = L["A soft shadow, or an outline for busy backgrounds."], options = OUTLINE_OPTIONS },
}
IconRows(schema, "essential", L["Essential cooldowns"])
IconRows(schema, "utility", L["Utility cooldowns"])
IconRows(schema, "buffs", L["Tracked buff icons"])
BarRows(schema)
Settings.schema = schema

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

local function Number(value, range, fallback)
	if type(value) ~= "number" or ns.IsSecret(value) or value ~= value then
		return fallback
	end
	value = min(range[2], max(range[1], value))
	return floor(value / range[3] + 0.5) * range[3]
end

local function Choice(value, allowed, fallback)
	if not ns.IsSecret(value) and allowed[value] then
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

local function TexturePath(value, fallback)
	if type(value) == "string" and value ~= "" and #value <= MAX_PATH and not value:find("[%c|]") then
		return value
	end
	return fallback
end

local function Color(out, prefix, value, fallback)
	if type(value) == "table" and Unit(value.r) and Unit(value.g) and Unit(value.b) then
		out[prefix .. "R"], out[prefix .. "G"], out[prefix .. "B"] = value.r, value.g, value.b
	else
		out[prefix .. "R"], out[prefix .. "G"], out[prefix .. "B"] = fallback.r, fallback.g, fallback.b
	end
end

local current = { essential = {}, utility = {}, buffs = {}, bars = { grid = {} } }
Settings.current = current

local function ReadIcons(out, saved, defaults)
	saved = type(saved) == "table" and saved or defaults
	for key, range in pairs(ICON_RANGE) do
		out[key] = Number(saved[key], range, defaults[key])
	end
	out.growth = Choice(saved.growth, GROWTH, defaults.growth)
	out.wrap = Choice(saved.wrap, WRAP, defaults.wrap)
	for _, key in ipairs(ICON_FLAGS) do
		out[key] = Bool(saved[key], defaults[key] == true)
	end
	out.cellWidth, out.cellHeight = out.size, out.size
end

local function ReadBars(out, saved, defaults)
	saved = type(saved) == "table" and saved or defaults
	for key, range in pairs(BAR_RANGE) do
		out[key] = Number(saved[key], range, defaults[key])
	end
	out.growth = Choice(saved.growth, BAR_GROWTH, defaults.growth)
	out.texture = TexturePath(saved.texture, defaults.texture)
	out.colorSource = Choice(saved.colorSource, COLOR_SOURCE, defaults.colorSource)
	out.orientation = Choice(saved.orientation, ORIENTATION, defaults.orientation)
	Color(out, "color", saved.color, defaults.color)
	for _, key in ipairs(BAR_FLAGS) do
		out[key] = Bool(saved[key], defaults[key])
	end
	local grid = out.grid
	grid.cellWidth, grid.cellHeight, grid.spacing = out.width, out.height, out.spacing
	grid.columns, grid.rows, grid.growth = 1, out.count, "right"
	grid.wrap = out.growth == "down" and "down" or "up"
end

function Settings.Read()
	local saved, defaults = Section(), Settings.defaults
	current.path = Choice(saved.path, PATH, defaults.path)
	current.accent = Choice(saved.accent, ACCENT, defaults.accent)
	Color(current, "accent", saved.accentColor, defaults.accentColor)
	current.tooltips = Bool(saved.tooltips, defaults.tooltips)
	for _, kind in ipairs({ "timer", "count", "name" }) do
		current[kind .. "Font"] = Font(saved[kind .. "Font"])
		current[kind .. "Outline"] = Choice(saved[kind .. "Outline"], OUTLINE, defaults[kind .. "Outline"])
	end
	for _, group in ipairs(ICON_GROUPS) do
		ReadIcons(current[group], saved[group], defaults[group])
	end
	ReadBars(current.bars, saved.bars, defaults.bars)
	return current
end

function Settings.Accent()
	if current.accent == "custom" and current.accentR then
		return current.accentR, current.accentG, current.accentB
	end
	return K.Theme.Accent()
end

local function BarRGB()
	local bars = current.bars
	if bars.colorSource == "custom" and bars.colorR then
		return bars.colorR, bars.colorG, bars.colorB
	elseif bars.colorSource == "reaction" then
		return K.Theme.ReactionColor(5)
	end
	local class = K.Theme.Class()
	if class then
		return K.Theme.ClassColor(class)
	end
	return K.Theme.Accent()
end

function Settings.BarColor()
	local r, g, b = BarRGB()
	return r, g, b, BAR_FILL_ALPHA
end
