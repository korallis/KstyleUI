-- Model.lua: the aura panel's settings, defaults and limits, and the pure maths that turn them into engine options and sizes.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L
local floor, ceil, max, min, format = math.floor, math.ceil, math.max, math.min, string.format

local Model = {}
ns.Model = Model

Model.MODULE = "Auras"
Model.GROUPS = { "buffs", "debuffs" }
Model.KEYS = { buffs = "auras.buffs", debuffs = "auras.debuffs" }
Model.FILTERS = { buffs = "HELPFUL", debuffs = "HARMFUL" }

local TIMER_GAP = 1
local LINE_SLACK = 0.5
local SECONDS_BAND = 91
local MINUTES_BAND = 5401
local HOURS_BAND = 129601
local MINUTE, HOUR, DAY = 60, 3600, 86400
local DECIMAL_BELOW = 3
Model.DECIMAL_BELOW = DECIMAL_BELOW

Model.LIMITS = {
	iconSize = { min = 16, max = 64, step = 1 },
	spacing = { min = 0, max = 24, step = 1 },
	rows = { min = 1, max = 8, step = 1 },
	columns = { min = 1, max = 24, step = 1 },
	timerSize = { min = 6, max = 24, step = 1 },
	countSize = { min = 6, max = 24, step = 1 },
	expiring = { min = 0, max = 30, step = 1 },
}
local LIMITS = Model.LIMITS

local NUMBER_FONT = (Tokens.Font("number"))
local ar, ag, ab = Tokens.Color("accentDefault")

Model.defaults = {
	enabled = false,
	hideBlizzard = true,
	buffs = {
		iconSize = 38, spacing = 10, rowSpacing = 0, rows = 2, columns = 6,
		growth = "LEFT_DOWN", sort = "time", reverse = false, enchants = true, cancel = true,
	},
	debuffs = {
		iconSize = 38, spacing = 10, rowSpacing = 0, rows = 2, columns = 6,
		growth = "LEFT_DOWN", sort = "priority", reverse = false, dispel = true, dispelFirst = true,
	},
	card = { docked = true },
	timer = { format = "short", position = "below", font = NUMBER_FONT, size = 12, outline = "OUTLINE", expiring = 5 },
	count = { font = NUMBER_FONT, size = 11, outline = "OUTLINE" },
	accent = { source = "class", color = { r = ar, g = ag, b = ab } },
}
local defaults = Model.defaults

Model.GROWTH_OPTIONS = {
	{ value = "LEFT_DOWN", label = L["Left, then down"] },
	{ value = "LEFT_UP", label = L["Left, then up"] },
	{ value = "RIGHT_DOWN", label = L["Right, then down"] },
	{ value = "RIGHT_UP", label = L["Right, then up"] },
}
Model.SORT_OPTIONS = {
	{ value = "time", label = L["Time left"] },
	{ value = "name", label = L["Name"] },
	{ value = "applied", label = L["Order applied"] },
	{ value = "blizzard", label = L["Yours first (Blizzard)"] },
	{ value = "priority", label = L["Priority (boss, important, yours first)"] },
}
Model.DISPEL_TYPES = { "Magic", "Curse", "Poison", "Disease" }
Model.MORE = { iconSize = 28, spacing = 6, columns = 8, buffs = 48, debuffs = 24 }
Model.TIMER_FORMATS = {
	{ value = "short", label = L["Short (8m, 24s)"] },
	{ value = "long", label = L["Long (8m 12s)"] },
	{ value = "decimal", label = L["Tenths under 3 seconds"] },
	{ value = "none", label = L["Hidden"] },
}
Model.TIMER_POSITIONS = {
	{ value = "below", label = L["Under the icon"] },
	{ value = "inside", label = L["On the icon"] },
}
Model.OUTLINES = {
	{ value = "NONE", label = L["Soft shadow"] },
	{ value = "OUTLINE", label = L["Thin outline"] },
	{ value = "THICKOUTLINE", label = L["Thick outline"] },
}
Model.ACCENT_SOURCES = {
	{ value = "class", label = L["Class colour"] },
	{ value = "custom", label = L["Custom colour"] },
}

local GROWTH = {
	LEFT_DOWN = { "TOPRIGHT", "Left", "Down" },
	LEFT_UP = { "BOTTOMRIGHT", "Left", "Up" },
	RIGHT_DOWN = { "TOPLEFT", "Right", "Down" },
	RIGHT_UP = { "BOTTOMLEFT", "Right", "Up" },
}
local SORT = { time = "ExpirationOnly", name = "NameOnly", applied = "AuraInstanceIDOnly", blizzard = "Default", priority = "UnitFrameDebuff" }
local FLAGS = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }

local function allowed(options)
	local set = {}
	for _, option in ipairs(options) do
		set[option.value] = true
	end
	return set
end
local TIMER_FORMAT_SET = allowed(Model.TIMER_FORMATS)
local TIMER_POSITION_SET = allowed(Model.TIMER_POSITIONS)
local ACCENT_SET = allowed(Model.ACCENT_SOURCES)

local function number(value, default, limit, whole)
	if type(value) ~= "number" or value ~= value then
		return default
	end
	if whole then
		value = floor(value)
	end
	return max(limit.min, min(limit.max, value))
end

local function choice(value, set, default)
	if type(value) == "string" and set[value] then
		return value
	end
	return default
end

local function boolean(value, default)
	if type(value) == "boolean" then
		return value
	end
	return default
end

local function section(settings, name)
	local t = type(settings) == "table" and settings[name]
	return type(t) == "table" and t or {}
end

function Model.Group(settings, name)
	local base = defaults[name]
	local s = section(settings, name)
	local g = {
		name = name,
		iconSize = number(s.iconSize, base.iconSize, LIMITS.iconSize),
		spacing = number(s.spacing, base.spacing, LIMITS.spacing),
		rowSpacing = number(s.rowSpacing, base.rowSpacing, LIMITS.spacing),
		rows = number(s.rows, base.rows, LIMITS.rows, true),
		columns = number(s.columns, base.columns, LIMITS.columns, true),
		growth = choice(s.growth, GROWTH, base.growth),
		sort = choice(s.sort, SORT, base.sort),
		reverse = s.reverse == true,
	}
	if base.enchants ~= nil then
		g.enchants = boolean(s.enchants, base.enchants)
		g.cancel = boolean(s.cancel, base.cancel)
	end
	if base.dispel ~= nil then
		g.dispel = boolean(s.dispel, base.dispel)
		g.dispelFirst = boolean(s.dispelFirst, base.dispelFirst)
	end
	return g
end

local function font(value, default)
	if type(value) == "string" and value ~= "" then
		return value
	end
	return default
end

function Model.Timer(settings)
	local base, s = defaults.timer, section(settings, "timer")
	return {
		format = choice(s.format, TIMER_FORMAT_SET, base.format),
		position = choice(s.position, TIMER_POSITION_SET, base.position),
		font = font(s.font, base.font),
		size = number(s.size, base.size, LIMITS.timerSize),
		outline = choice(s.outline, FLAGS, base.outline),
		expiring = number(s.expiring, base.expiring, LIMITS.expiring),
	}
end

function Model.Count(settings)
	local base, s = defaults.count, section(settings, "count")
	return {
		font = font(s.font, base.font),
		size = number(s.size, base.size, LIMITS.countSize),
		outline = choice(s.outline, FLAGS, base.outline),
	}
end

function Model.TextScale()
	local Theme = K.Theme
	local scale = Theme and type(Theme.FontScale) == "function" and Theme.FontScale()
	if type(scale) ~= "number" or scale ~= scale or scale <= 0 then
		return 1
	end
	return scale
end

function Model.Flags(outline)
	return FLAGS[outline] or ""
end

function Model.Growth(growth)
	local entry = GROWTH[growth] or GROWTH[defaults.buffs.growth]
	return entry[1], entry[2], entry[3]
end

function Model.ContainerAnchor(growth)
	return (Model.Growth(growth))
end

function Model.Sort(sort, reverse)
	return SORT[sort] or SORT[defaults.buffs.sort], reverse == true and "Reverse" or "Normal"
end

function Model.TimerArea(timer)
	if timer.position == "below" and timer.format ~= "none" then
		return timer.size + TIMER_GAP
	end
	return 0
end

local function same(units)
	return units
end

function Model.ElementSize(group, timer, snap)
	snap = snap or same
	local icon = snap(group.iconSize)
	local area = Model.TimerArea(timer)
	return icon, icon + (area > 0 and snap(area) or 0)
end

function Model.LineSize(group, timer, snap)
	snap = snap or same
	local w = Model.ElementSize(group, timer, snap)
	return group.columns * w + (group.columns - 1) * snap(group.spacing) + LINE_SLACK
end

function Model.Footprint(group, timer, snap)
	snap = snap or same
	local w, h = Model.ElementSize(group, timer, snap)
	return group.columns * w + (group.columns - 1) * snap(group.spacing), group.rows * h + (group.rows - 1) * snap(group.rowSpacing)
end

local CARD_PAD = 20
local CARD_GAP = 8
local HAIRLINE = 1
Model.CARD_PAD = CARD_PAD
Model.CARD_GAP = CARD_GAP

function Model.Docked(settings)
	return boolean(section(settings, "card").docked, defaults.card.docked)
end

function Model.Card(buffs, debuffs, pad, gap)
	local cap = KstyleUI.Widgets.SECTION_CAP_HEIGHT
	local card = { width = buffs.width + 2 * pad, contentTop = pad + cap + gap }
	local bottom = card.contentTop + buffs.height
	if debuffs then
		card.width = max(card.width, debuffs.width + 2 * pad)
		card.ruleTop = bottom + gap
		card.debuffTop = card.ruleTop + HAIRLINE + gap
		bottom = card.debuffTop + debuffs.height
	end
	card.height = bottom + pad
	return card
end

function Model.Capacity(group, enchants)
	return max(0, group.rows * group.columns - (enchants or 0))
end

local function channel(value)
	return type(value) == "number" and value == value and value >= 0 and value <= 1
end

function Model.AccentColor(settings)
	local s = section(settings, "accent")
	local c = s.color
	if choice(s.source, ACCENT_SET, defaults.accent.source) == "custom" and type(c) == "table" and channel(c.r) and channel(c.g) and channel(c.b) then
		return c.r, c.g, c.b
	end
	return K.Theme.Accent()
end

local function short(seconds)
	if seconds < SECONDS_BAND then
		return format("%ds", floor(seconds))
	elseif seconds < MINUTES_BAND then
		return format("%dm", ceil(seconds / MINUTE))
	elseif seconds < HOURS_BAND then
		return format("%dh", ceil(seconds / HOUR))
	end
	return format("%dd", ceil(seconds / DAY))
end

local function long(seconds)
	seconds = floor(seconds)
	if seconds < MINUTE then
		return format("%ds", seconds)
	elseif seconds < HOUR then
		return format("%dm %ds", floor(seconds / MINUTE), seconds % MINUTE)
	elseif seconds < DAY then
		return format("%dh %dm", floor(seconds / HOUR), floor(seconds % HOUR / MINUTE))
	end
	return format("%dd %dh", floor(seconds / DAY), floor(seconds % DAY / HOUR))
end

function Model.FormatTime(seconds, timerFormat)
	if timerFormat == "none" or type(seconds) ~= "number" or seconds ~= seconds then
		return ""
	end
	seconds = max(0, seconds)
	if timerFormat == "long" then
		return long(seconds)
	elseif timerFormat == "decimal" and seconds < DECIMAL_BELOW then
		return format("%.1f", floor(seconds * 10) / 10)
	end
	return short(seconds)
end
