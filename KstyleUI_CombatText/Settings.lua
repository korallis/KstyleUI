-- Settings.lua: CombatText's defaults, its settings page and the checked copy of the settings that the combat path reads.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local MODULE = "CombatText"
local NUMBER_FONT = (Tokens.Font("number"))
local SIZE_MIN, SIZE_MAX, SIZE_STEP = 8, 40, 1
local DURATION_MIN, DURATION_MAX, DURATION_STEP = 0.6, 3, 0.1
local PER_FRAME_MIN, PER_FRAME_MAX = 1, 8
local CRIT_MIN, CRIT_MAX, CRIT_STEP = 1, 2, 0.05

local function TokenColor(name)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b }
end

local defaults = {
	worldFont = true,
	worldFace = NUMBER_FONT,
	style = "rise",
	damage = true,
	heals = true,
	misses = true,
	format = "short",
	duration = 1.2,
	maxPerFrame = 4,
	font = NUMBER_FONT,
	size = 18,
	outline = "OUTLINE",
	colorMode = "school",
	damageColor = TokenColor("hostile"),
	healColor = TokenColor("friendly"),
	missColor = TokenColor("text"),
	critScale = 1.4,
	critColor = true,
	critTint = TokenColor("neutral"),
}
Settings.defaults = defaults

local STYLE_OPTIONS = {
	{ value = "rise", label = L["Rise"] },
	{ value = "arc", label = L["Arc"] },
	{ value = "pop", label = L["Pop"] },
}
local OUTLINE_OPTIONS = {
	{ value = "NONE", label = L["Soft shadow"] },
	{ value = "OUTLINE", label = L["Thin outline"] },
	{ value = "THICKOUTLINE", label = L["Thick outline"] },
}
local FORMAT_OPTIONS = {
	{ value = "short", label = L["Short, such as 12.3K"] },
	{ value = "full", label = L["Full, such as 12,345"] },
}
local COLOR_MODE_OPTIONS = {
	{ value = "school", label = L["By spell school"] },
	{ value = "single", label = L["One colour"] },
}

local function Set(options)
	local out = {}
	for _, option in ipairs(options) do
		out[option.value] = true
	end
	return out
end
local STYLES, OUTLINES, FORMATS, COLOR_MODES = Set(STYLE_OPTIONS), Set(OUTLINE_OPTIONS), Set(FORMAT_OPTIONS), Set(COLOR_MODE_OPTIONS)
local OUTLINE_FLAGS = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }

local function WorldFontOn(settings)
	return settings.worldFont == true
end

local function CritColorOn(settings)
	return settings.critColor == true
end

Settings.schema = {
	{ type = "header", label = L["World numbers"] },
	{
		type = "toggle", key = "worldFont", label = L["KstyleUI font for world numbers"],
		help = L["Draws the game's own damage numbers in a KstyleUI font from your next login."],
	},
	{
		type = "font", key = "worldFace", label = L["World number font"],
		help = L["The font for the game's own damage numbers; it changes at your next login."],
		showWhen = WorldFontOn,
	},
	{ type = "header", label = L["Numbers"] },
	{
		type = "dropdown", key = "style", label = L["Animation"],
		help = L["Numbers rise straight up, arc to one side, or pop in and drift."],
		options = STYLE_OPTIONS,
	},
	{ type = "toggle", key = "damage", label = L["Damage"], help = L["Shows the damage you take."] },
	{ type = "toggle", key = "heals", label = L["Heals"], help = L["Shows the healing you receive, with a plus sign."] },
	{
		type = "toggle", key = "misses", label = L["Misses and absorbs"],
		help = L["Shows words such as Dodge, Parry, Absorb and Immune."],
	},
	{
		type = "dropdown", key = "format", label = L["Number format"],
		help = L["Short numbers such as 12.3K, or full numbers such as 12,345."],
		options = FORMAT_OPTIONS,
	},
	{
		type = "slider", key = "duration", label = L["Duration"],
		help = L["How long each number stays on screen, in seconds."],
		min = DURATION_MIN, max = DURATION_MAX, step = DURATION_STEP,
	},
	{
		type = "slider", key = "maxPerFrame", label = L["Numbers at once"],
		help = L["The most numbers one place shows at a time; the oldest makes way."],
		min = PER_FRAME_MIN, max = PER_FRAME_MAX, step = 1,
	},
	{ type = "header", label = L["Text"] },
	{ type = "font", key = "font", label = L["Font"], help = L["The typeface of the numbers."] },
	{
		type = "slider", key = "size", label = L["Size"],
		help = L["The text size of the numbers."],
		min = SIZE_MIN, max = SIZE_MAX, step = SIZE_STEP,
	},
	{
		type = "dropdown", key = "outline", label = L["Outline"],
		help = L["A soft shadow, or a thin or thick outline that reads well over the game world."],
		options = OUTLINE_OPTIONS,
	},
	{ type = "header", label = L["Colours"] },
	{
		type = "dropdown", key = "colorMode", label = L["Damage colour"],
		help = L["Colour damage by its spell school, or use one colour for all damage."],
		options = COLOR_MODE_OPTIONS,
	},
	{
		type = "color", key = "damageColor", label = L["Damage"],
		help = L["The colour of damage when it does not follow the school, or the school is hidden."],
	},
	{ type = "color", key = "healColor", label = L["Heals"], help = L["The colour of healing numbers."] },
	{ type = "color", key = "missColor", label = L["Misses"], help = L["The colour of words such as Dodge and Absorb."] },
	{ type = "header", label = L["Critical hits"] },
	{
		type = "slider", key = "critScale", label = L["Critical size"],
		help = L["How much larger critical hits and heals appear; 1 turns the emphasis off."],
		min = CRIT_MIN, max = CRIT_MAX, step = CRIT_STEP,
	},
	{
		type = "toggle", key = "critColor", label = L["Colour critical hits"],
		help = L["Draws critical damage in its own colour."],
	},
	{
		type = "color", key = "critTint", label = L["Critical colour"],
		help = L["The colour of critical damage."],
		showWhen = CritColorOn,
	},
}

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local function Choice(v, allowed, default)
	if not IsSecret(v) and type(v) == "string" and allowed[v] then
		return v
	end
	return default
end

local function Number(v, low, high, default, whole)
	if IsSecret(v) or type(v) ~= "number" or v ~= v or v < low or v > high then
		return default
	end
	if whole and v ~= math.floor(v) then
		return default
	end
	return v
end

local function Bool(v, default)
	if type(v) == "boolean" then
		return v
	end
	return default
end

local function FontPath(v, default)
	if not IsSecret(v) and K.Theme.IsFontPath(v) then
		return v
	end
	return default
end

local function Unit(v)
	return not IsSecret(v) and type(v) == "number" and v >= 0 and v <= 1
end

local function Color(v, default)
	if type(v) == "table" and Unit(v.r) and Unit(v.g) and Unit(v.b) then
		return v.r, v.g, v.b
	end
	return default.r, default.g, default.b
end

local function Formatter(format)
	local short, full = AbbreviateNumbers, BreakUpLargeNumbers
	short = type(short) == "function" and short or nil
	full = type(full) == "function" and full or nil
	if format == "full" then
		return full or short
	end
	return short or full
end

function Settings.Values()
	local Store = K.Store
	if Store.IsLoaded() then
		return Store.Module(MODULE)
	end
	return defaults
end

function Settings.Snapshot(values, cfg)
	cfg = cfg or {}
	values = type(values) == "table" and values or defaults
	local d = defaults
	cfg.worldFont = Bool(values.worldFont, d.worldFont)
	cfg.worldFace = FontPath(values.worldFace, d.worldFace)
	cfg.style = Choice(values.style, STYLES, d.style)
	cfg.damage = Bool(values.damage, d.damage)
	cfg.heals = Bool(values.heals, d.heals)
	cfg.misses = Bool(values.misses, d.misses)
	cfg.neutral = cfg.damage or cfg.heals
	cfg.format = Choice(values.format, FORMATS, d.format)
	cfg.formatter = Formatter(cfg.format)
	cfg.duration = Number(values.duration, DURATION_MIN, DURATION_MAX, d.duration)
	cfg.maxPerFrame = Number(values.maxPerFrame, PER_FRAME_MIN, PER_FRAME_MAX, d.maxPerFrame, true)
	cfg.fontPath = FontPath(values.font, d.font)
	cfg.size = Number(values.size, SIZE_MIN, SIZE_MAX, d.size)
	local outline = Choice(values.outline, OUTLINES, d.outline)
	cfg.flags = OUTLINE_FLAGS[outline]
	cfg.shadow = outline == "NONE"
	cfg.fontKey = cfg.fontPath .. "|" .. cfg.size .. "|" .. cfg.flags
	cfg.colorMode = Choice(values.colorMode, COLOR_MODES, d.colorMode)
	cfg.damageR, cfg.damageG, cfg.damageB = Color(values.damageColor, d.damageColor)
	cfg.healR, cfg.healG, cfg.healB = Color(values.healColor, d.healColor)
	cfg.missR, cfg.missG, cfg.missB = Color(values.missColor, d.missColor)
	cfg.critScale = Number(values.critScale, CRIT_MIN, CRIT_MAX, d.critScale)
	cfg.critColor = Bool(values.critColor, d.critColor)
	cfg.critR, cfg.critG, cfg.critB = Color(values.critTint, d.critTint)
	return cfg
end
