-- Model.lua: the aura rows' settings, defaults and limits, and the pure maths that turn them into engine options and sizes.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L
local floor, max, min = math.floor, math.max, math.min

local Model = {}
ns.Model = Model

Model.MODULE = "Auras"
Model.GROUPS = { "buffs", "debuffs", "extraBuffs", "extraDebuffs" }
Model.KIND = { buffs = "buffs", debuffs = "debuffs", extraBuffs = "buffs", extraDebuffs = "debuffs" }
Model.KEYS = { buffs = "auras.buffs", debuffs = "auras.debuffs", extraBuffs = "auras.extraBuffs", extraDebuffs = "auras.extraDebuffs" }
Model.FILTERS = { buffs = "HELPFUL", debuffs = "HARMFUL", extraBuffs = "HELPFUL", extraDebuffs = "HARMFUL" }

local LINE_SLACK = 0.5
Model.TIMER_GAP = 3
Model.DECIMAL_BELOW = K.Widgets.Duration.DECIMAL_BELOW
Model.LABELS = { buffs = 40, debuffs = 24, extraBuffs = 40, extraDebuffs = 24 }

Model.LIMITS = {
	iconSize = { min = 16, max = 64, step = 0.1 },
	spacing = { min = 0, max = 24, step = 0.5 },
	rows = { min = 1, max = 8, step = 1 },
	columns = { min = 1, max = 24, step = 1 },
	timerSize = { min = 6, max = 24, step = 1 },
	countSize = { min = 6, max = 24, step = 1 },
	offset = { min = -50, max = 50, step = 1 },
	iconZoom = { min = 0, max = 0.2, step = 0.01 },
	expiring = { min = 0, max = 30, step = 1 },
	hiddenAlpha = { min = 0, max = 1, step = 0.05 },
	precise = { min = 0, max = 90, step = 1 },
	typeIconSize = { min = 6, max = 24, step = 1 },
}
local LIMITS = Model.LIMITS

local function rgb(name)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b }
end

Model.defaults = {
	medallionsIcons = true,
	enabled = false,
	hideBlizzard = true,
	iconZoom = 0.07,
	hiddenAlpha = 0,
	buffs = {
		iconSize = 27.6, spacing = 3.5, rowSpacing = 4, rows = 1, columns = 10,
		onlyMine = false, dispellable = false, swipe = false,
		growth = "RIGHT_DOWN", sort = "use", reverse = false, enchants = true, cancel = true, tracked = "cdm",
		allowSpells = "", blockSpells = "", show = "all", timed = false, tooltips = "always", swipeReverse = true, refresh = false, glow = false,
	},
	debuffs = {
		iconSize = 27.6, spacing = 3.5, rowSpacing = 4, rows = 1, columns = 10,
		onlyMine = false, dispellable = false, swipe = false,
		growth = "RIGHT_DOWN", sort = "priority", reverse = false, dispel = true, typeIcon = "none", typeIconSize = 10,
		show = "all", timed = false, tooltips = "always", swipeReverse = true, refresh = false, glow = false,
	},
	extraBuffs = {
		enabled = false, iconSize = 36, spacing = 3.5, rowSpacing = 4, rows = 1, columns = 6,
		onlyMine = false, dispellable = false, swipe = false,
		growth = "RIGHT_DOWN", sort = "use", reverse = false, cancel = true, tracked = "cdm",
		allowSpells = "", blockSpells = "", show = "important", timed = false, tooltips = "always", swipeReverse = true, refresh = false, glow = false,
	},
	extraDebuffs = {
		enabled = false, iconSize = 36, spacing = 3.5, rowSpacing = 4, rows = 1, columns = 6,
		onlyMine = false, dispellable = false, swipe = false,
		growth = "RIGHT_DOWN", sort = "priority", reverse = false, dispel = true, typeIcon = "none", typeIconSize = 10,
		show = "crowdControl", timed = false, tooltips = "always", swipeReverse = true, refresh = false, glow = false,
	},
	timer = {
		format = "short", position = "below", font = "", size = 11, outline = "INHERIT", expiring = 5, x = 0, y = 0,
		seconds = true, precise = 0, customColor = false, color = rgb("timerText"),
	},
	count = { shown = true, font = "", size = 10, outline = "OUTLINE", x = 0, y = 0, position = "TOPRIGHT", customColor = false, color = rgb("textEmphasis") },
	accent = { source = "class", color = rgb("accentDefault") },
	reminder = { enabled = false, font = "", size = 13, outline = "INHERIT" },
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
	{ value = "top", label = L["On the icon's top edge"] },
	{ value = "center", label = L["Centre of the icon"] },
	{ value = "TOPLEFT", label = L["Top left"] },
	{ value = "TOPRIGHT", label = L["Top right"] },
	{ value = "LEFT", label = L["Left"] },
	{ value = "RIGHT", label = L["Right"] },
	{ value = "BOTTOMLEFT", label = L["Bottom left"] },
	{ value = "BOTTOMRIGHT", label = L["Bottom right"] },
}
Model.SHOW_OPTIONS = {
	buffs = {
		{ value = "all", label = L["All buffs"] },
		{ value = "important", label = L["Important (Blizzard's list)"] },
		{ value = "bigDefensive", label = L["Big defensives"] },
		{ value = "external", label = L["External defensives"] },
		{ value = "cancelable", label = L["Ones you can cancel"] },
	},
	debuffs = {
		{ value = "all", label = L["All debuffs"] },
		{ value = "crowdControl", label = L["Crowd control"] },
		{ value = "dispellable", label = L["Dispellable by anyone"] },
	},
}
Model.SHOW_TOKENS = {
	important = "IMPORTANT", bigDefensive = "BIG_DEFENSIVE", external = "EXTERNAL_DEFENSIVE", cancelable = "CANCELABLE",
	crowdControl = "CROWD_CONTROL", dispellable = "DISPELLABLE",
}
Model.TOOLTIP_OPTIONS = {
	{ value = "always", label = L["Always"] },
	{ value = "noCombat", label = L["Out of combat"] },
	{ value = "never", label = L["Never"] },
}
Model.CORNERS = {
	{ value = "TOPLEFT", label = L["Top left"] },
	{ value = "TOP", label = L["Top"] },
	{ value = "TOPRIGHT", label = L["Top right"] },
	{ value = "LEFT", label = L["Left"] },
	{ value = "CENTER", label = L["Centre"] },
	{ value = "RIGHT", label = L["Right"] },
	{ value = "BOTTOMLEFT", label = L["Bottom left"] },
	{ value = "BOTTOM", label = L["Bottom"] },
	{ value = "BOTTOMRIGHT", label = L["Bottom right"] },
}
Model.TYPE_ICON_OPTIONS = { { value = "none", label = L["Hidden"] } }
for i = 1, #Model.CORNERS do
	Model.TYPE_ICON_OPTIONS[i + 1] = Model.CORNERS[i]
end
Model.CORNER_SIGNS = {
	TOPRIGHT = { -1, -1, "RIGHT" }, TOPLEFT = { 1, -1, "LEFT" }, BOTTOMRIGHT = { -1, 1, "RIGHT" }, BOTTOMLEFT = { 1, 1, "LEFT" }, CENTER = { 0, 0, "CENTER" },
	TOP = { 0, -1, "CENTER" }, BOTTOM = { 0, 1, "CENTER" }, LEFT = { 1, 0, "LEFT" }, RIGHT = { -1, 0, "RIGHT" },
}
Model.OUTLINES = {
	{ value = "INHERIT", label = L["Use readability setting"] },
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
local FLAGS = { INHERIT = "", NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }

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
local SHOW_SETS = { buffs = allowed(Model.SHOW_OPTIONS.buffs), debuffs = allowed(Model.SHOW_OPTIONS.debuffs) }
local TOOLTIP_SET = allowed(Model.TOOLTIP_OPTIONS)

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
		swipe = boolean(s.swipe, base.swipe),
		show = choice(s.show, SHOW_SETS[Model.KIND[name]], base.show),
		timed = s.timed == true,
		dispellable = s.dispellable == true,
		tooltips = choice(s.tooltips, TOOLTIP_SET, base.tooltips),
		swipeReverse = boolean(s.swipeReverse, base.swipeReverse),
		refresh = s.refresh == true,
		glow = s.glow == true,
		enabled = boolean(s.enabled, base.enabled ~= false),
	}
	if base.enchants ~= nil then
		g.enchants = boolean(s.enchants, base.enchants)
	end
	if base.cancel ~= nil then
		g.cancel = boolean(s.cancel, base.cancel)
		g.tracked = choice(s.tracked, TRACKED_SET, base.tracked)
	end
	if base.dispel ~= nil then
		g.dispel = boolean(s.dispel, base.dispel)
		g.typeIcon = choice(s.typeIcon, Model.CORNER_SIGNS, base.typeIcon)
		g.typeIconSize = number(s.typeIconSize, base.typeIconSize, LIMITS.typeIconSize)
	end
	return g
end

local function channel(value)
	return type(value) == "number" and value == value and value >= 0 and value <= 1
end

local function customColor(s)
	local c = s.color
	if s.customColor == true and type(c) == "table" and channel(c.r) and channel(c.g) and channel(c.b) then
		return { r = c.r, g = c.g, b = c.b }
	end
end

local function font(value, default)
	if not K.Theme.FollowsKit(value) then
		return value
	end
	return default
end

function Model.Timer(settings)
	local base, s = defaults.timer, section(settings, "timer")
	local outline = choice(s.outline, FLAGS, base.outline)
	if outline == "INHERIT" then outline = K.Widgets.Readability("worldText") and "OUTLINE" or "NONE" end
	return {
		format = choice(s.format, TIMER_FORMAT_SET, base.format),
		position = choice(s.position, TIMER_POSITION_SET, base.position),
		font = font(s.font, (Tokens.Font("timer"))),
		size = number(s.size, base.size, LIMITS.timerSize),
		outline = outline,
		expiring = number(s.expiring, base.expiring, LIMITS.expiring),
		x = number(s.x, base.x, LIMITS.offset), y = number(s.y, base.y, LIMITS.offset),
		seconds = boolean(s.seconds, base.seconds),
		precise = number(s.precise, base.precise, LIMITS.precise, true),
		color = customColor(s),
	}
end

function Model.Count(settings)
	local base, s = defaults.count, section(settings, "count")
	return {
		shown = boolean(s.shown, base.shown),
		font = font(s.font, (Tokens.Font("number"))),
		size = number(s.size, base.size, LIMITS.countSize),
		outline = choice(s.outline, FLAGS, base.outline),
		x = number(s.x, base.x, LIMITS.offset), y = number(s.y, base.y, LIMITS.offset),
		position = choice(s.position, Model.CORNER_SIGNS, base.position),
		color = customColor(s),
	}
end

function Model.IconZoom(settings)
	return number(settings.iconZoom, defaults.iconZoom, LIMITS.iconZoom)
end

function Model.HiddenAlpha(settings)
	return number(settings.hiddenAlpha, defaults.hiddenAlpha, LIMITS.hiddenAlpha)
end

local SECONDS_BAND, MINUTE_BAND, HOUR_BAND = 91, 5401, 129601

function Model.PlainTimer(timer)
	return (timer.seconds and timer.precise == 0) or (timer.format ~= "short" and timer.format ~= "decimal")
end

function Model.Breakpoints(timer, units, R, roundUp)
	local whole = roundUp and R.Up or R.Down
	local list, from = {}, 0
	if timer.format == "decimal" then
		list[1] = { threshold = 0, step = 0.1, rounding = R.Down, format = "%.1f" }
		from = Model.DECIMAL_BELOW
	end
	list[#list + 1] = { threshold = from, step = 1, rounding = whole, format = timer.seconds and units.s or "%d" }
	local minutes = max(SECONDS_BAND, timer.precise * 60)
	if timer.precise > 1 then
		list[#list + 1] = { threshold = 60, step = 1, rounding = whole, format = "%d:%02d", components = { { div = 60, step = 1, rounding = R.Down }, { mod = 60, step = 1, rounding = R.Down } } }
	end
	for _, band in ipairs({ { minutes, 60, units.m }, { MINUTE_BAND, 3600, units.h }, { HOUR_BAND, 86400, units.d } }) do
		list[#list + 1] = { threshold = band[1], format = band[3], components = { { div = band[2], step = 1, rounding = R.Up } } }
	end
	return list
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
	if outline == "INHERIT" then return K.Widgets.Readability("worldText") and "OUTLINE" or "" end
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
