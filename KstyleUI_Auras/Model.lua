-- Model.lua: the aura rows' settings, defaults and limits, and the pure maths that turn them into engine options and sizes.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L
local floor, max, min = math.floor, math.max, math.min

local Model = {}
ns.Model = Model

Model.MODULE = "Auras"
Model.GROUPS = { "buffs", "debuffs" }
Model.KEYS = { buffs = "auras.buffs", debuffs = "auras.debuffs" }
Model.FILTERS = { buffs = "HELPFUL", debuffs = "HARMFUL" }

local LINE_SLACK = 0.5
Model.TIMER_GAP = 3
Model.DECIMAL_BELOW = K.Widgets.Duration.DECIMAL_BELOW
Model.LABELS = { buffs = 40, debuffs = 24 }

Model.LIMITS = {
	iconSize = { min = 16, max = 64, step = 0.5 },
	spacing = { min = 0, max = 24, step = 0.5 },
	rows = { min = 1, max = 8, step = 1 },
	columns = { min = 1, max = 24, step = 1 },
	timerSize = { min = 6, max = 24, step = 1 },
	countSize = { min = 6, max = 24, step = 1 },
	expiring = { min = 0, max = 30, step = 1 },
}
local LIMITS = Model.LIMITS

local ar, ag, ab = Tokens.Color("accentDefault")

Model.defaults = {
	enabled = false,
	hideBlizzard = true,
	buffs = {
		iconSize = 27.5, spacing = 3.5, rowSpacing = 4, rows = 1, columns = 10,
		growth = "RIGHT_DOWN", sort = "use", reverse = false, enchants = true, cancel = true, tracked = "cdm",
	},
	debuffs = {
		iconSize = 27.5, spacing = 3.5, rowSpacing = 4, rows = 1, columns = 10,
		growth = "RIGHT_DOWN", sort = "priority", reverse = false, dispel = true,
	},
	timer = { format = "short", position = "below", font = "", size = 11, outline = "NONE", expiring = 5 },
	count = { font = "", size = 10, outline = "OUTLINE" },
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
	{ value = "use", label = L["By use (yours, then ones you can cast, then soonest to end)"] },
	{ value = "time", label = L["Time left"] },
	{ value = "name", label = L["Name"] },
	{ value = "applied", label = L["Order applied"] },
	{ value = "blizzard", label = L["Yours first (Blizzard)"] },
	{ value = "priority", label = L["Priority (boss, important, yours first)"] },
}
Model.TRACKED_OPTIONS = {
	{ value = "cdm", label = L["Cooldown Manager only"] },
	{ value = "both", label = L["Here as well"] },
}
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
local HANG = { TOPRIGHT = "TOPRIGHT", BOTTOMRIGHT = "BOTTOMRIGHT", TOPLEFT = "TOPRIGHT", BOTTOMLEFT = "BOTTOMRIGHT" }
local LAST_CELL = { TOPRIGHT = "BOTTOMLEFT", BOTTOMRIGHT = "TOPLEFT", TOPLEFT = "BOTTOMRIGHT", BOTTOMLEFT = "TOPRIGHT" }
local SORT = { use = "Expiration", time = "ExpirationOnly", name = "NameOnly", applied = "AuraInstanceIDOnly", blizzard = "Default", priority = "UnitFrameDebuff" }
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
local TRACKED_SET = allowed(Model.TRACKED_OPTIONS)

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
	if K.HudStyle.Current() == "orbs" then
		g.growth = (g.growth:gsub("_DOWN$", "_UP"))
	end
	if base.enchants ~= nil then
		g.enchants = boolean(s.enchants, base.enchants)
		g.cancel = boolean(s.cancel, base.cancel)
		g.tracked = choice(s.tracked, TRACKED_SET, base.tracked)
	end
	if base.dispel ~= nil then
		g.dispel = boolean(s.dispel, base.dispel)
	end
	return g
end

local function font(value, default)
	if not K.Theme.FollowsKit(value) then
		return value
	end
	return default
end

function Model.Timer(settings)
	local base, s = defaults.timer, section(settings, "timer")
	return {
		format = choice(s.format, TIMER_FORMAT_SET, base.format),
		position = choice(s.position, TIMER_POSITION_SET, base.position),
		font = font(s.font, (Tokens.Font("timer"))),
		size = number(s.size, base.size, LIMITS.timerSize),
		outline = choice(s.outline, FLAGS, base.outline),
		expiring = number(s.expiring, base.expiring, LIMITS.expiring),
	}
end

function Model.Count(settings)
	local base, s = defaults.count, section(settings, "count")
	return {
		font = font(s.font, (Tokens.Font("number"))),
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

function Model.Hang(growth)
	return HANG[(Model.Growth(growth))]
end

function Model.LastCell(growth)
	return LAST_CELL[(Model.Growth(growth))]
end

function Model.Sort(sort, reverse)
	return SORT[sort] or SORT[defaults.buffs.sort], reverse == true and "Reverse" or "Normal"
end

function Model.TimerArea(timer)
	if timer.position == "below" and timer.format ~= "none" then
		local scale = K and K.Scale
		local least = scale and scale.TextFloor and scale.TextFloor() * scale.Pixel(1) or 0
		return math.max(timer.size, least) + Model.TIMER_GAP
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

function Model.Gaps(group, timer, snap)
	snap = snap or same
	local w, h = Model.ElementSize(group, timer, snap)
	return snap(group.iconSize + group.spacing) - w, snap(h + group.rowSpacing) - h
end

function Model.LineSize(group, timer, snap)
	snap = snap or same
	local w = Model.ElementSize(group, timer, snap)
	local gap = Model.Gaps(group, timer, snap)
	return group.columns * w + (group.columns - 1) * gap + LINE_SLACK
end

function Model.Footprint(group, timer, snap)
	snap = snap or same
	local w, h = Model.ElementSize(group, timer, snap)
	local gap, rowGap = Model.Gaps(group, timer, snap)
	return group.columns * w + (group.columns - 1) * gap, group.rows * h + (group.rows - 1) * rowGap
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

function Model.FormatTime(seconds, timerFormat)
	return KstyleUI.Widgets.Duration.Format(seconds, timerFormat)
end
