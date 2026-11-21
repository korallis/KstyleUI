-- Settings.lua: the unit frames' defaults, the choices each setting allows, and the settings page rows.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local MODULE = "UnitFrames"
local THEME_FONT = "theme"
local FONT_SIZE_MIN, FONT_SIZE_MAX, FONT_SIZE_STEP = 6, 32, 1
local POWER_HEIGHT_MIN, POWER_HEIGHT_MAX = 2, 24
local ICON_SIZE_MIN, ICON_SIZE_MAX = 8, 32
local CAST_HEIGHT_MIN, CAST_HEIGHT_MAX = 6, 40
local AURA_SIZE_MIN, AURA_SIZE_MAX = 12, 48
local AURA_SPACING_MAX = 12
local AURA_ROWS_MAX, AURA_COLUMNS_MAX = 6, 16
local SPACING_MIN, SPACING_MAX = 0, 12
local ALPHA_MIN, ALPHA_STEP = 0.1, 0.05
local ZOOM_MAX, ZOOM_STEP = 0.3, 0.01
local NUDGE = 50
local BOSS_GAP_MAX = 20

Settings.MODULE = MODULE
Settings.THEME_FONT = THEME_FONT

local KINDS = { "player", "target", "targettarget", "focus", "focustarget", "pet", "boss" }
Settings.KINDS = KINDS

Settings.LABELS = {
	player = L["Player"],
	target = L["Target"],
	targettarget = L["Target of target"],
	focus = L["Focus"],
	focustarget = L["Focus target"],
	pet = L["Pet"],
	boss = L["Boss"],
}

Settings.ELEMENTS = {
	player = "unitframes.player",
	target = "unitframes.target",
	targettarget = "unitframes.targettarget",
	focus = "unitframes.focus",
	focustarget = "unitframes.focustarget",
	pet = "unitframes.pet",
	boss = "unitframes.boss",
}

Settings.TEXTS = { "name", "health", "power", "level" }

Settings.FORMS = {
	player = "vitals",
	target = "sigil",
	targettarget = "row",
	focus = "card",
	focustarget = "row",
	pet = "row",
	boss = "card",
}

Settings.CAP_LABELS = { focus = L["Focus"], boss = L["Boss"] }

Settings.COLUMN = { player = true, target = true }

Settings.CASTBAR = { player = true, target = true, focus = true, boss = true }
Settings.CAST_ELEMENTS = { player = "unitframes.castbar.player", target = "unitframes.castbar.target" }
Settings.AURAS = { player = true, target = true, focus = true, boss = true, pet = true }

local function Color(token)
	local r, g, b = Tokens.Color(token)
	return { r = r, g = g, b = b }
end

local BAR_TEXTURE = Tokens.MediaList("statusbar")[1].path

local function TextStyle(size)
	return { font = THEME_FONT, size = size, outline = "INHERIT" }
end

local COMPACT_TEXT = { 12, 12, 9, 10 }

local function ExtraText()
	return { font = "", size = 12, outline = "OUTLINE", colorMode = "", color = Color("textEmphasis"),
		textFormat = "", position = "CENTER", x = 0, y = 0 }
end

local function Kind(full, overrides, castHeight, castFont, aura, text)
	text = text or COMPACT_TEXT
	local d = {
		enabled = true,
		extra1 = ExtraText(), extra2 = ExtraText(),
		style = "lumen",
		portrait = full,
		portraitStyle = "portrait",
		portraitShape = "round",
		portraitSide = "LEFT",
		portraitMirror = false,
		portraitZoom = 0,
		level = full,
		levelFriendly = false,
		name = true,
		nameCaps = true,
		healthTexture = BAR_TEXTURE,
		healthColor = "class",
		healthCustom = Color("friendly"),
		healthOrientation = "RIGHT",
		healthText = full and "both" or "percent",
		healthAlpha = 1,
		healthGradient = "",
		healPrediction = true,
		absorbs = true,
		healAbsorbs = false,
		incomingAlpha = 0.45,
		absorbAlpha = 0.35,
		healAbsorbAlpha = 0.7,
		levelDifficulty = false,
		power = full,
		powerHeight = full and 7 or 3,
		powerTexture = BAR_TEXTURE,
		powerColor = "power",
		powerCustom = Color("rare"),
		powerOrientation = "RIGHT",
		powerAlpha = 1,
		powerGradient = "",
		powerText = "none",
		powerSeparate = true,
		percentLead = true,
		raidMarker = true,
		leader = full,
		role = full,
		pvp = full,
		pvpEnemyOnly = false,
		pvpPlayersOnly = false,
		elite = false,
		combat = false,
		resting = false,
		threat = full,
		hoverBorder = false,
		targetBorder = false,
		iconSize = 12,
		castbar = castHeight ~= nil,
		castbarHeight = castHeight or 20,
		castbarIcon = true,
		castbarText = true,
		castbarCaps = true,
		castbarTimer = true,
		castbarSpark = true,
		castbarLatency = false,
		castbarLockedColor = Color("textDisabled"),
		castbarTexture = BAR_TEXTURE,
		castbarColor = "class",
		castbarCustom = Color("rare"),
		castbarOrientation = "RIGHT",
		castbarInside = false,
		castbarAlpha = 1,
		castbarIconRight = false,
		castbarIconX = 0, castbarIconY = 0, castbarTextX = 0, castbarTextY = 0, castbarTimerX = 0, castbarTimerY = 0,
		castbarTarget = false,
		castbarImportant = false,
		castbarImportantColor = Color("legendary"),
		auras = aura ~= nil and aura.on or false,
		auraFilter = "mine",
		auraFilters = { onlyMine = false, dispellable = false, sort = "" },
		auraSize = aura and aura.size or 20,
		auraSpacing = 2,
		auraRows = aura and aura.rows or 1,
		auraColumns = aura and aura.columns or 8,
		auraGrowth = "RIGHT_DOWN",
		auraPosition = aura and aura.position or "BELOW",
		auraTimer = true,
		auraZoom = 0.07,
		auraTooltipCombat = true,
		auraX = 0, auraY = 0, auraTimerX = 0, auraTimerY = 0,
		auraCountSize = 0, auraCountPoint = "TOPRIGHT", auraCountX = 0, auraCountY = 0,
		auraDispel = true, auraBuffDispel = false, auraStealable = false,
		fonts = {
			name = TextStyle(text[1]),
			health = TextStyle(text[2]),
			power = { font = THEME_FONT, size = full and 12 or text[3], outline = "OUTLINE" },
			level = TextStyle(text[4]),
			cast = TextStyle(castFont or 10),
			aura = { font = THEME_FONT, size = 8, outline = "OUTLINE" },
		},
	}
	for _, element in ipairs({ "name", "health" }) do
		local style = d.fonts[element]
		style.colorMode, style.color, style.textFormat = "", Color("textEmphasis"), ""
	end
	for key, value in pairs(overrides or {}) do
		d[key] = value
	end
	return d
end

Settings.defaults = {
	auraLayout = "rows",
	stableSlabNames = true,
	singleSlabLevel = true,
	hideBlizzard = true,
	castOutcomes = true,
	healthDecimal = false,
	unitTooltip = "always",
	castbarRaise = false,
	accent = "class",
	accentColor = Color("accentDefault"),
	dangerEdge = true,
	cleanLowRing = true,
	orbGlass = true,
	orbLedge = true,
	orbCastRoom = true,
	edit = "player",
	player = Kind(true, {
		medallionsAuras = true, medallionsAuraFilter = "buffs",
		castbarSmooth = false, castbarChannelOverride = false, castbarChannelColor = Color("rare"), castbarTotal = false,
		powerText = "auto",
		style = "column", combat = true, resting = true, castbarIcon = true, castbarCaps = true, castbarColor = "gold", castbarInside = true,
		healthColor = "hud",
	}, 20, 12, { on = false, size = 22, position = "BELOW" }, { 22, 15, 10, 14 }),
	target = Kind(true, {
		crestDebuffs = true, transitions = true,
		style = "column", rangeFade = true, portraitSide = "RIGHT", healthColor = "hud", castbarColor = "gold", castbarCaps = true, castbarIcon = false, castbarInside = true,
		power = false, auraSpacing = 4,
	}, 14, 12, { on = true, size = 27.6, columns = 4, rows = 1, position = "SIDE" }, { 22, 15, 10, 14 }),
	targettarget = Kind(false),
	focus = Kind(true, { power = false, castbarColor = "gold", castbarCaps = false }, 16, 12, { on = true, size = 20, position = "ABOVE" }, { 16, 14, 9, 12 }),
	focustarget = Kind(false),
	pet = Kind(false, { happiness = false, auraPosition = "ABOVE", auraColumns = 5, auraFilter = "debuffs" }),
	boss = Kind(true, { power = false, castbarColor = "gold", castbarCaps = true, auraGrowth = "LEFT_DOWN", growth = "DOWN", gap = 6 }, 10, 12, { on = true, size = 22, columns = 4, rows = 1, position = "LEFT" }, { 13, 13, 9, 12 }),
	resource = {
		enabled = true,
		comboPoints = true,
		druidMana = true,
		comboColor = "class",
		comboCustom = Color("neutral"),
		manaColor = "power",
		manaCustom = Color("rare"),
		manaTexture = BAR_TEXTURE,
		manaOrientation = "RIGHT",
		spacing = 3,
	},
}

Settings.defaults.target.fonts.aura.size = 12

for _, kind in ipairs({ "targettarget", "focustarget", "pet" }) do
	local fonts = Settings.defaults[kind].fonts
	fonts.name.outline, fonts.health.outline = "OUTLINE", "OUTLINE"
end

local function Options(list)
	local out = {}
	for i, item in ipairs(list) do
		out[i] = { value = item[1], label = item[2] }
	end
	return out
end

Settings.CHOICES = {
	powerText = Options({
		{ "auto", L["Automatic: mana percent, other resources current"] },
		{ "legacy", L["Previous display"] },
		{ "percent", L["Percentage"] }, { "current", L["Current"] }, { "currentMax", L["Current and max"] },
		{ "both", L["Current, max and percentage"] }, { "none", L["None"] },
	}),
	style = Options({ { "column", L["Column"] }, { "lumen", L["Vitals line"] }, { "plate", L["Plate"] } }),
	styleLumen = Options({ { "lumen", L["Standard"] }, { "plate", L["Plate"] } }),
	styleTarget = Options({ { "column", L["Column"] }, { "bar", L["Wide bar"] }, { "lumen", L["Sigil"] }, { "plate", L["Plate"] } }),
	portraitStyle = Options({ { "portrait", L["Character portrait"] }, { "class", L["Class icon"] } }),
	portraitShape = Options({ { "chamfered", L["Chamfered"] }, { "round", L["Round"] } }),
	portraitSide = Options({ { "LEFT", L["Left"] }, { "RIGHT", L["Right"] } }),
	healthColor = Options({ { "hud", L["KstyleUI colours"] }, { "class", L["Class, or reaction for NPCs"] }, { "reaction", L["Reaction"] }, { "health", L["By health left"] }, { "custom", L["Custom colour"] } }),
	gradient = Options({ { "", L["None"] }, { "HORIZONTAL", L["Left to right"] }, { "VERTICAL", L["Bottom to top"] } }),
	unitTooltip = Options({ { "always", L["Always"] }, { "noCombat", L["Out of combat"] }, { "never", L["Never"] } }),
	powerColor = Options({ { "power", L["Power type"] }, { "class", L["Class, or reaction for NPCs"] }, { "reaction", L["Reaction"] }, { "custom", L["Custom colour"] } }),
	orientation = Options({ { "RIGHT", L["Left to right"] }, { "LEFT", L["Right to left"] }, { "UP", L["Bottom to top"] }, { "DOWN", L["Top to bottom"] } }),
	text = Options({
		{ "percent", L["Percentage"] }, { "current", L["Current"] }, { "currentMax", L["Current and max"] },
		{ "both", L["Current, max and percentage"] }, { "none", L["None"] },
	}),
	outline = Options({ { "INHERIT", L["Use readability setting"] }, { "NONE", L["None (soft shadow)"] }, { "OUTLINE", L["Thin outline"] }, { "THICKOUTLINE", L["Thick outline"] } }),
	accent = Options({ { "class", L["Class colour"] }, { "custom", L["Custom colour"] } }),
	manaColor = Options({ { "power", L["Power type"] }, { "class", L["Class colour"] }, { "custom", L["Custom colour"] } }),
	castbarColor = Options({ { "class", L["Class colour"] }, { "gold", L["Gilt"] }, { "reaction", L["Reaction"] }, { "custom", L["Custom colour"] } }),
	auraFilter = Options({ { "mine", L["Your debuffs"] }, { "debuffs", L["All debuffs"] }, { "buffs", L["Buffs"] }, { "both", L["Debuffs and buffs"] } }),
	auraGrowth = Options({ { "RIGHT_DOWN", L["Right, then down"] }, { "RIGHT_UP", L["Right, then up"] }, { "LEFT_DOWN", L["Left, then down"] }, { "LEFT_UP", L["Left, then up"] } }),
	growth = Options({ { "DOWN", L["Downward"] }, { "UP", L["Upward"] } }),
	countPoint = Options({ { "TOPRIGHT", L["Top right"] }, { "TOPLEFT", L["Top left"] }, { "CENTER", L["Centre"] } }),
	auraPosition = Options({ { "CENTER", L["Centred below the frame"] }, { "BELOW", L["Below the frame"] }, { "ABOVE", L["Above the frame"] }, { "RIGHT", L["Right of the frame"] }, { "LEFT", L["Left of the frame"] }, { "SIDE", L["Right of the portrait"] } }),
}
local CHOICES = Settings.CHOICES

local CHOICE_OF = {
	style = "style",
	portraitStyle = "portraitStyle",
	portraitShape = "portraitShape",
	portraitSide = "portraitSide",
	healthColor = "healthColor",
	healthGradient = "gradient",
	powerGradient = "gradient",
	auraCountPoint = "countPoint",
	powerColor = "powerColor",
	healthOrientation = "orientation",
	powerOrientation = "orientation",
	healthText = "text",
	powerText = "powerText",
	castbarColor = "castbarColor",
	castbarOrientation = "orientation",
	auraFilter = "auraFilter",
	medallionsAuraFilter = "auraFilter",
	auraGrowth = "auraGrowth",
	auraPosition = "auraPosition",
	growth = "growth",
}

local function Allowed(list, value)
	for _, option in ipairs(list) do
		if option.value == value then
			return true
		end
	end
	return false
end

local function FontOptions()
	local out = { { value = THEME_FONT, label = L["KstyleUI font"] } }
	local media = K.Widgets and K.Widgets.MediaOptions and K.Widgets.MediaOptions("font") or {}
	for _, option in ipairs(media) do
		out[#out + 1] = { value = option.value, label = option.label }
	end
	return out
end
Settings.FontOptions = FontOptions

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end

local function Saved()
	local Store = K.Store
	if Store.IsLoaded() then
		return Store.Module(MODULE)
	end
	return nil
end

function Settings.Module()
	return Saved() or Settings.defaults
end

local function Kinds(kind)
	local d = Settings.defaults[kind]
	if not d then
		error("UnitFrames.Settings: unknown frame " .. tostring(kind), 3)
	end
	local s = Saved()
	local own = s and type(s[kind]) == "table" and s[kind] or d
	return own, d
end

local RANGES = {
	powerHeight = { POWER_HEIGHT_MIN, POWER_HEIGHT_MAX },
	iconSize = { ICON_SIZE_MIN, ICON_SIZE_MAX },
	castbarHeight = { CAST_HEIGHT_MIN, CAST_HEIGHT_MAX },
	auraSize = { AURA_SIZE_MIN, AURA_SIZE_MAX },
	auraSpacing = { 0, AURA_SPACING_MAX },
	auraRows = { 1, AURA_ROWS_MAX },
	auraColumns = { 1, AURA_COLUMNS_MAX },
	healthAlpha = { ALPHA_MIN, 1 },
	incomingAlpha = { ALPHA_MIN, 1 },
	absorbAlpha = { ALPHA_MIN, 1 },
	healAbsorbAlpha = { ALPHA_MIN, 1 },
	castbarAlpha = { ALPHA_MIN, 1 },
	portraitZoom = { 0, ZOOM_MAX },
	auraZoom = { 0, ZOOM_MAX },
	powerAlpha = { ALPHA_MIN, 1 },
	auraCountSize = { 0, FONT_SIZE_MAX },
	gap = { 0, BOSS_GAP_MAX },
}
for _, key in ipairs({ "auraX", "auraY", "auraTimerX", "auraTimerY", "auraCountX", "auraCountY",
	"castbarIconX", "castbarIconY", "castbarTextX", "castbarTextY", "castbarTimerX", "castbarTimerY" }) do
	RANGES[key] = { -NUDGE, NUDGE }
end

local function IsNumber(v)
	return not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v == v
end

local SLAB_DEFAULTS = { target = { auraSize = 22, auraSpacing = 2, auraColumns = 6, auraGrowth = "LEFT_DOWN" } }
local ROW_DEFAULTS = {
	player = { auraPosition = "ABOVE", auraGrowth = "RIGHT_UP", auraSize = 28, auraSpacing = 2, auraColumns = 6, auraRows = 2 },
	target = { auraPosition = "ABOVE", auraGrowth = "LEFT_UP", auraSize = 28, auraSpacing = 2, auraColumns = 6, auraRows = 2 },
}

local DERIVED = { auras = true, auraFilter = true }
for _, list in pairs({ SLAB_DEFAULTS, ROW_DEFAULTS }) do
	for _, keys in pairs(list) do
		for key in pairs(keys) do DERIVED[key] = true end
	end
end

function Settings.AuraRows(kind)
	return ROW_DEFAULTS[kind] ~= nil and K.HudStyle.Current() == "medallions" and Settings.Module().auraLayout ~= "fan"
end

function Settings.Value(kind, key)
	if kind == "player" and (key == "auras" or key == "auraFilter") and Settings.AuraRows(kind) then key = key == "auras" and "medallionsAuras" or "medallionsAuraFilter" end
	local own, d = Kinds(kind)
	local default = d[key]
	if default == nil then
		error("UnitFrames.Settings.Value: unknown setting " .. tostring(key), 2)
	end
	local value = own[key]
	local rows = ROW_DEFAULTS[kind]
	if rows and rows[key] ~= nil and (value == nil or value == default) and Settings.AuraRows(kind) then return rows[key] end
	local slab = SLAB_DEFAULTS[kind] and SLAB_DEFAULTS[kind][key]
	if slab ~= nil and (value == nil or value == default) and Settings.Form(kind) == "slab" then
		return slab
	end
	if value == default or type(value) ~= type(default) then
		return default
	end
	local choice = kind == "target" and key == "style" and "styleTarget" or CHOICE_OF[key]
	if choice and not Allowed(CHOICES[choice], value) then
		LogOnce(kind .. "." .. key .. "=" .. tostring(value), kind .. "." .. key .. ": " .. tostring(value) .. " is not a choice; using " .. tostring(default))
		return default
	end
	local range = RANGES[key]
	if range and not (IsNumber(value) and value >= range[1] and value <= range[2]) then
		LogOnce(kind .. "." .. key, kind .. "." .. key .. " is out of range; using " .. default)
		return default
	end
	return value
end

local RESOURCE_CHOICES = { comboColor = "accent", manaColor = "manaColor", manaOrientation = "orientation" }

function Settings.Resource(key)
	local d = Settings.defaults.resource
	local default = d[key]
	if default == nil then
		error("UnitFrames.Settings.Resource: unknown setting " .. tostring(key), 2)
	end
	local s = Saved()
	local own = s and type(s.resource) == "table" and s.resource or d
	local value = own[key]
	if type(value) ~= type(default) then
		return default
	end
	local choice = RESOURCE_CHOICES[key]
	if choice and not Allowed(CHOICES[choice], value) then
		LogOnce("resource." .. key, "resource." .. key .. ": " .. tostring(value) .. " is not a choice; using " .. tostring(default))
		return default
	end
	if key == "spacing" and not (IsNumber(value) and value >= SPACING_MIN and value <= SPACING_MAX) then
		return default
	end
	return value
end

local function OutlineFlags(outline)
	if outline == "OUTLINE" or outline == "THICKOUTLINE" then
		return outline
	end
	return ""
end

local LUMEN_ROLES = { name = "names", health = "number", power = "number", level = "number", aura = "timer" }
local SLAB_TEXT = { name = { 10, "InterSemiBold" }, health = { 15 }, power = { 12, role = "number" }, level = { 10, "InterSemiBold" }, aura = { 10 } }
local SLAB_MINI_NAME = 9
local SLAB_MINI = { targettarget = true, focustarget = true }

function Settings.Role(kind, element)
	local role = LUMEN_ROLES[element]
	if role == "names" and Settings.Form(kind) == "column" then
		role = "unit"
	end
	return role and Settings.Form(kind) ~= "plate" and role or "body"
end

function Settings.Font(kind, element)
	local own, d = Kinds(kind)
	local default = d.fonts[element]
	if not default then
		error("UnitFrames.Settings.Font: unknown text " .. tostring(element), 2)
	end
	local style = type(own.fonts) == "table" and type(own.fonts[element]) == "table" and own.fonts[element] or default
	local themePath = Tokens.Font(Settings.Role(kind, element))
	local path = themePath
	local font = style.font
	if not K.Theme.FollowsKit(font) then
		if K.Theme.IsFontPath(font) then
			path = font
		else
			LogOnce("font:" .. font, kind .. " " .. element .. " font " .. font .. " is not a font file; using KstyleUI's font")
		end
	end
	local size = style.size
	if not (IsNumber(size) and size >= FONT_SIZE_MIN and size <= FONT_SIZE_MAX) then
		size = default.size
	end
	local slab = SLAB_TEXT[element]
	if slab and Settings.Form(kind) == "slab" then
		local base = SLAB_MINI[kind] and element == "name" and SLAB_MINI_NAME or slab[1]
		size = base * size / default.size
		if path == themePath and slab[2] then
			path = Tokens.FontPath(slab[2]) or path
		elseif path == themePath and slab.role then
			path = Tokens.Font(slab.role)
		end
	end
	return path, size * K.Theme.FontScale(), OutlineFlags(style.outline == "INHERIT" and (K.Widgets.Readability("worldText") and "OUTLINE" or "NONE") or style.outline), style.outline
end

function Settings.ThemeFont(kind, element)
	local own, d = Kinds(kind)
	local style = type(own.fonts) == "table" and type(own.fonts[element]) == "table" and own.fonts[element] or d.fonts[element]
	local font = style and style.font
	return K.Theme.FollowsKit(font) or not K.Theme.IsFontPath(font)
end

function Settings.FontSize(kind, element)
	local _, size = Settings.Font(kind, element)
	return size
end

function Settings.Accent()
	local s = Settings.Module()
	if s.accent == "custom" then
		local c = s.accentColor
		if type(c) == "table" and IsNumber(c.r) and IsNumber(c.g) and IsNumber(c.b) then
			return c.r, c.g, c.b
		end
	end
	return K.Theme.Accent()
end

function Settings.Form(kind)
	local style = Settings.Value(kind, "style")
	if style == "plate" then
		return "plate"
	end
	if K.HudStyle.Current() == "medallions" then
		return "slab"
	end
	if kind == "target" and (style == "bar" or style == "column" and K.HudStyle.Current() == "orbs") then
		return "bar"
	end
	if style == "column" and Settings.COLUMN[kind] then
		return "column"
	end
	return Settings.FORMS[kind]
end

function Settings.Snapshot(kind)
	local fonts = {}
	local own, d = Kinds(kind)
	for _, element in ipairs(Settings.TEXTS) do
		local style = type(own.fonts) == "table" and type(own.fonts[element]) == "table" and own.fonts[element] or d.fonts[element]
		fonts[element] = { size = Settings.FontSize(kind, element) / K.Theme.FontScale(),
			colorMode = style.colorMode or "", color = style.color or d.fonts[element].color,
			textFormat = type(style.textFormat) == "string" and style.textFormat or "" }
	end
	fonts.cast = { size = Settings.FontSize(kind, "cast") / K.Theme.FontScale() }
	local form = Settings.Form(kind)
	local s = { fonts = fonts, form = form, kind = kind, rowsAbove = Settings.AuraRows(kind), inlineCast = form == "column" and kind ~= "player" }
	s.healthDecimal = Settings.Module().healthDecimal == true
	s.textOptions = fonts.name.textFormat ~= "" or fonts.health.textFormat ~= "" or fonts.name.colorMode ~= "" or fonts.health.colorMode ~= ""
	for key, default in pairs(d) do
		if key ~= "fonts" then
			local value = own[key]
			if DERIVED[key] or (value ~= nil and value ~= default) then default = Settings.Value(kind, key) end
			s[key] = default
		end
	end
	return s
end

local function Shows(kind, extra)
	return function(settings)
		if settings.edit ~= kind then
			return false
		end
		return extra == nil or extra(settings[kind] or Settings.defaults[kind]) ~= false
	end
end

local IconRows, ResourceRows, CastRows, AuraRows

local function Scope(kind)
	return { key = "edit", value = kind }
end

local function Header(kind, label)
	return { type = "header", label = Settings.LABELS[kind] .. ": " .. label, showWhen = Shows(kind), scope = Scope(kind) }
end

local function Row(kind, row, extra)
	row.key = kind .. "." .. row.key
	row.showWhen = Shows(kind, extra)
	row.scope = Scope(kind)
	return row
end

local function BarRows(schema, kind, bar)
	local function on(s)
		return bar == "health" or s.power ~= false
	end
	local custom = function(s)
		return on(s) and s[bar .. "Color"] == "custom"
	end
	K.Widgets.BarRows(schema, "", {
		keys = { texture = bar .. "Texture", colorSource = bar .. "Color", color = bar .. "Custom" },
		options = bar == "health" and CHOICES.healthColor or CHOICES.powerColor,
		height = bar == "power" and { POWER_HEIGHT_MIN, POWER_HEIGHT_MAX, 1, key = "powerHeight" } or nil,
		row = function(row)
			local show = row.type == "color" and custom or on
			if row.type == "slider" then show = function(s) return on(s) and s.style ~= "column" end end
			return Row(kind, row, show)
		end,
	})
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = bar .. "Orientation", label = L["Fill direction"],
		help = L["Which way the bar fills."], options = CHOICES.orientation,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = bar .. "Text", label = L["Text"],
		help = bar == "health" and L["How the health text reads."] or L["How the power text reads."],
		options = bar == "power" and CHOICES.powerText or CHOICES.text,
	}, on)
end

local function Nudges(schema, kind, prefix, label, show, crest)
	for _, axis in ipairs({ { "X", L["Horizontal offset"], L["Moves it left or right."], L["Moves it left or right. Not the Medallions crest."] },
		{ "Y", L["Vertical offset"], L["Moves it up or down."], L["Moves it up or down. Not the Medallions crest."] } }) do
		schema[#schema + 1] = Row(kind, { type = "slider", key = prefix .. axis[1], label = label .. ": " .. axis[2], help = crest and axis[4] or axis[3],
			min = -NUDGE, max = NUDGE, step = 1 }, show)
	end
end

local TEXT_LABELS = {
	name = L["Name text"],
	health = L["Health text"],
	power = L["Power text"],
	level = L["Level text"],
	cast = L["Cast bar text"],
	aura = L["Aura text"],
}

local function TextRows(schema, kind, element)
	local prefix = "fonts." .. element
	K.Widgets.TextRows(schema, prefix, {
		fontType = "dropdown", fonts = FontOptions, outlines = CHOICES.outline,
		step = kind == "target" and element == "level" and 0.5 or FONT_SIZE_STEP,
		tags = element == "name" or element == "health",
		row = function(row)
			row.label = TEXT_LABELS[element] .. ": " .. row.label
			return Row(kind, row, row.type == "color" and function(s)
				return s.fonts[element].colorMode == "custom"
			end or nil)
		end,
	})
end

local ICON_ROWS = {
	{ "raidMarker", L["Raid marker"], L["Shows the raid marker set on the unit."] },
	{ "leader", L["Leader icon"], L["Shows a crown when the unit leads the group."] },
	{ "role", L["Role icon"], L["Shows the unit's group role."] },
	{ "pvp", L["PvP icon"], L["Shows the faction badge while the unit is flagged for PvP."] },
	{ "pvpEnemyOnly", L["Other faction only"], L["Shows the PvP badge only on units of the other faction."], nil, "pvp" },
	{ "pvpPlayersOnly", L["Players only"], L["Hides the PvP badge on NPCs such as guards."], nil, "pvp" },
	{ "elite", L["Elite and rare icon"], L["Marks elite, rare and boss units with the game's dragon badge."], "-player-pet" },
	{ "combat", L["Combat icon"], L["Shows crossed swords while the unit is in combat."] },
	{ "resting", L["Resting"], L["Shows Zz while you rest in an inn or a city."], "player" },
	{ "threat", L["Threat glow"], L["Glows in the threat colour when the unit has or causes threat."] },
	{ "hoverBorder", L["Hover highlight"], L["Outlines the frame in the accent colour while the mouse is over it."] },
	{ "targetBorder", L["Target highlight"], L["Outlines the frame in the accent colour while this unit is your target."], "-target" },
	{ "happiness", L["Pet happiness"], L["Shows your hunter pet's happiness."], "pet" },
}

IconRows = function(schema, kind)
	if kind == "target" then
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "rangeFade", label = L["Fade target out of range"], help = L["Fades the target name and portrait to 55 percent out of range. Off keeps them fully visible."] })
	end
	schema[#schema + 1] = Header(kind, L["icons"])
	for _, spec in ipairs(ICON_ROWS) do
		local only = spec[4]
		if only == nil or only == kind or only:sub(1, 1) == "-" and not ("-" .. only .. "-"):find("-" .. kind .. "-", 1, true) then
			local parent = spec[5]
			schema[#schema + 1] = Row(kind, { type = "toggle", key = spec[1], label = spec[2], help = spec[3] },
				parent and function() return Settings.Value(kind, parent) == true end or nil)
		end
	end
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "iconSize", label = L["Icon size"],
		help = L["The size of the status icons on the frame's top edge."],
		min = ICON_SIZE_MIN, max = ICON_SIZE_MAX, step = 1,
	})
end

CastRows = function(schema, kind)
	local function on(s)
		return s.castbar ~= false
	end
	schema[#schema + 1] = Header(kind, L["cast bar"])
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbar", label = L["Cast bar"],
		help = L["Shows the unit's casts and channels."],
	})
	if Settings.CAST_ELEMENTS[kind] then
		schema[#schema + 1] = Row(kind, {
			type = "toggle", key = "castbarInside", label = L["Spell name inside the bar"],
			help = L["Frames: the spell name and timer sit inside the cast bar. Off puts them on their own line."],
		}, on)
	end
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbarIcon", label = L["Spell icon"],
		help = L["Shows the spell's icon beside the cast bar."],
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbarText", label = L["Spell name"],
		help = L["Shows the spell's name on the cast bar."],
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbarCaps", label = L["Spell name in capitals"],
		help = L["Capitals spaced wide, like the frame's name. Off, the name reads as the game writes it."],
	}, function(settings)
		return on(settings) and settings.castbarText ~= false
	end)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbarTimer", label = L["Timer"],
		help = L["Shows the seconds left on the cast bar."],
	}, on)
	K.Widgets.BarRows(schema, "", {
		keys = { texture = "castbarTexture", colorSource = "castbarColor", color = "castbarCustom" },
		options = CHOICES.castbarColor,
		height = not Settings.CAST_ELEMENTS[kind] and { CAST_HEIGHT_MIN, CAST_HEIGHT_MAX, 1, key = "castbarHeight" } or nil,
		row = function(row)
			return Row(kind, row, row.type == "color" and function(s) return on(s) and s.castbarColor == "custom" end or on)
		end,
	})
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "castbarOrientation", label = L["Fill direction"],
		help = L["Which way the cast bar fills. A bar taller than it is wide stacks its icon on top."],
		options = CHOICES.orientation,
	}, on)
	local function iconShown(s)
		local form = Settings.Form(kind)
		return on(s) and Settings.Value(kind, "castbarIcon") and K.HudStyle.Current() ~= "medallions" and (form == "plate" or form == "column" or form == "bar" and Settings.CAST_ELEMENTS[kind] ~= nil)
	end
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarIconRight", label = L["Icon on the right"],
		help = L["Put the spell icon at the right end of the cast bar."] }, iconShown)
	for _, spec in ipairs({ { "castbarIcon", L["Spell icon"] }, { "castbarText", L["Spell name"] }, { "castbarTimer", L["Timer"] } }) do
		local part = spec[1]
		Nudges(schema, kind, part, spec[2], part == "castbarIcon" and iconShown or function(s) return on(s) and s[part] ~= false end)
	end
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarTarget", label = L["Spell target"],
		help = L["Adds who the spell is cast on after its name, when the game shows it."] }, function(s) return on(s) and s.castbarText ~= false end)
	if kind ~= "player" then
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarImportant", label = L["Important cast outline"],
			help = L["Outlines the cast bar while the unit casts a spell the game marks as important."] }, on)
		schema[#schema + 1] = Row(kind, { type = "color", key = "castbarImportantColor", label = L["Outline colour"],
			help = L["The colour of the important cast outline."] }, function(s) return on(s) and s.castbarImportant == true end)
	end
	schema[#schema + 1] = Row(kind, { type = "slider", key = "castbarAlpha", label = L["Fill opacity"],
		help = L["How solid the cast fill is. Lower lets the track show through."], min = ALPHA_MIN, max = 1, step = ALPHA_STEP }, on)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarSpark", label = L["Cast spark"], help = L["Shows the current style's bright cast progress edge."] }, on)
	schema[#schema + 1] = Row(kind, { type = "color", key = "castbarLockedColor", label = L["Uninterruptible colour"], help = L["The colour of casts nothing can interrupt."] }, on)
	if kind == "player" then
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarSmooth", label = L["Smooth cast progress"],
			help = L["Use the game's smoothing for cast and channel progress."] }, on)
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarChannelOverride", label = L["Separate channel colour"],
			help = L["Use a separate fill colour while you channel a spell."] }, on)
		schema[#schema + 1] = Row(kind, { type = "color", key = "castbarChannelColor", label = L["Channel colour"],
			help = L["The fill colour for channels. Uninterruptible colour still takes priority."] }, function(s) return on(s) and s.castbarChannelOverride == true end)
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarLatency", label = L["Latency zone"],
			help = L["Marks world latency at the end of your cast when cast times are readable."] }, on)
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarTotal", label = L["Show total duration"],
			help = L["Show the time cast so far and the full cast time, such as 0.4 / 2.0."] }, function(s) return on(s) and s.castbarTimer ~= false end)
	end
	TextRows(schema, kind, "cast")
end

AuraRows = function(schema, kind)
	local function on()
		return Settings.Value(kind, "auras") == true
	end
	schema[#schema + 1] = Header(kind, L["auras"])
	if kind == "target" then
		schema[#schema + 1] = Row(kind, {
			type = "toggle", key = "crestDebuffs", label = L["Your target debuffs above the crest"],
			help = L["Medallions: fans your debuffs above the crest, with the rest on the target frame."],
		}, function() return K.HudStyle.Current() == "medallions" and Settings.Module().auraLayout == "fan" end)
	end
	for _, medallions in ipairs(kind == "player" and { false, true } or { false }) do
		local function visible(filter)
			return (kind ~= "player" or Settings.AuraRows(kind) == medallions) and (not filter or on())
		end
		schema[#schema + 1] = Row(kind, {
			type = "toggle", key = medallions and "medallionsAuras" or "auras", label = L["Auras"],
			help = L["Shows the unit's buffs and debuffs beside the frame."],
		}, function() return visible(false) end)
		schema[#schema + 1] = Row(kind, {
			type = "dropdown", key = medallions and "medallionsAuraFilter" or "auraFilter", label = L["Which auras"],
			help = L["Your debuffs, all debuffs, buffs, or debuffs and buffs."], options = CHOICES.auraFilter,
		}, function() return visible(true) end)
	end
	local filters = {}
	K.Options.AuraFilterRows(filters, kind .. ".auraFilters")
	for _, row in ipairs(filters) do
		row.showWhen, row.scope = Shows(kind, on), Scope(kind)
		schema[#schema + 1] = row
	end
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "auraPosition", label = L["Aura position"],
		help = L["Which side of the frame the auras sit on."], options = CHOICES.auraPosition,
	}, on)
	Nudges(schema, kind, "aura", L["Auras"], on)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "auraGrowth", label = L["Aura growth"],
		help = L["Which way new aura icons are added."], options = CHOICES.auraGrowth,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraSize", label = L["Aura icon size"],
		help = L["The size of each aura icon in units."], min = AURA_SIZE_MIN, max = AURA_SIZE_MAX, step = 1,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraSpacing", label = L["Aura spacing"],
		help = L["The gap between aura icons in units."], min = 0, max = AURA_SPACING_MAX, step = 1,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraRows", label = L["Aura rows"],
		help = L["How many rows of each kind of aura show."], min = 1, max = AURA_ROWS_MAX, step = 1,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraColumns", label = L["Aura columns"],
		help = L["How many aura icons fit in a row."], min = 1, max = AURA_COLUMNS_MAX, step = 1,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "auraTimer", label = L["Aura timers"],
		help = L["Shows the time left on each aura."],
	}, on)
	local crest = kind == "target"
	Nudges(schema, kind, "auraTimer", L["Aura timers"], function(s) return on() and s.auraTimer ~= false end, crest)
	schema[#schema + 1] = Row(kind, { type = "slider", key = "auraCountSize", label = L["Stack text size"],
		help = crest and L["Stack count size; the aura text size until you move it. Not the Medallions crest."] or L["The size of aura stack counts. It matches the aura text size until you move it."],
		min = FONT_SIZE_MIN, max = FONT_SIZE_MAX, step = 1,
		shown = function(value) return value == 0 and math.max(FONT_SIZE_MIN, math.floor(Settings.FontSize(kind, "aura") / K.Theme.FontScale() + 0.5)) or value end }, on)
	schema[#schema + 1] = Row(kind, { type = "dropdown", key = "auraCountPoint", label = L["Stack position"],
		help = crest and L["Which corner of each aura icon shows its stack count. Not the Medallions crest."] or L["Which corner of each aura icon shows its stack count."], options = CHOICES.countPoint }, on)
	Nudges(schema, kind, "auraCount", L["Stack position"], on, crest)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "auraDispel", label = L["Debuff dispel colours"],
		help = L["Edges debuffs in their dispel type's colour."] }, on)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "auraBuffDispel", label = L["Buff dispel colours"],
		help = L["Edges buffs that have a dispel type in its colour, such as magic buffs you can purge."] }, on)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "auraStealable", label = L["Only buffs you can steal"],
		help = L["Edges only buffs a spell steal can take."] }, function(s) return on() and s.auraBuffDispel == true end)
	schema[#schema + 1] = Row(kind, { type = "slider", key = "auraZoom", label = L["Aura icon zoom"],
		help = L["Crops into each aura icon. 0 shows the whole icon with its border."], min = 0, max = ZOOM_MAX, step = ZOOM_STEP }, on)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "auraTooltipCombat", label = L["Aura tooltips in combat"],
		help = L["Off hides aura tooltips while you fight; they still show out of combat."] }, on)
	TextRows(schema, kind, "aura")
end

ResourceRows = function(schema)
	local function shows(extra)
		return function(settings)
			if settings.edit ~= "player" then
				return false
			end
			local r = type(settings.resource) == "table" and settings.resource or Settings.defaults.resource
			return extra == nil or extra(r) ~= false
		end
	end
	local function on(r)
		return r.enabled ~= false
	end
	local first = #schema + 1
	schema[#schema + 1] = { type = "header", label = Settings.LABELS.player .. ": " .. L["class resource"], showWhen = shows() }
	schema[#schema + 1] = {
		type = "toggle", key = "resource.enabled", label = L["Class resource"], showWhen = shows(),
		help = L["Shows combo points and the druid's mana under the player frame."],
	}
	schema[#schema + 1] = {
		type = "toggle", key = "resource.comboPoints", label = L["Combo points"], showWhen = shows(on),
		help = L["Shows rogue and cat form combo points as pips."],
	}
	schema[#schema + 1] = {
		type = "dropdown", key = "resource.comboColor", label = L["Combo point colour"], showWhen = shows(on),
		help = L["The pips follow the class colour or a custom colour."], options = CHOICES.accent,
	}
	schema[#schema + 1] = {
		type = "color", key = "resource.comboCustom", label = L["Custom combo point colour"],
		help = L["The pips' colour when it is custom."],
		showWhen = shows(function(r)
			return on(r) and r.comboColor == "custom"
		end),
	}
	schema[#schema + 1] = {
		type = "slider", key = "resource.spacing", label = L["Pip spacing"], showWhen = shows(on),
		help = L["The gap between combo point pips in units."], min = SPACING_MIN, max = SPACING_MAX, step = 1,
	}
	schema[#schema + 1] = {
		type = "toggle", key = "resource.druidMana", label = L["Druid mana"], showWhen = shows(on),
		help = L["Shows your mana in bear and cat form."],
	}
	K.Widgets.BarRows(schema, "resource", {
		keys = { texture = "manaTexture", colorSource = "manaColor", color = "manaCustom" }, options = CHOICES.manaColor,
		row = function(row)
			row.showWhen = shows(row.type == "color" and function(r) return on(r) and r.manaColor == "custom" end or on)
			return row
		end,
	})
	schema[#schema + 1] = {
		type = "dropdown", key = "resource.manaOrientation", label = L["Fill direction"], showWhen = shows(on),
		help = L["Which way the druid mana bar fills."], options = CHOICES.orientation,
	}
	for i = first, #schema do
		schema[i].scope = Scope("player")
	end
end

local STYLE_HELP = {
	column = L["Column: full-width bars, portrait outside. Vitals line: one line, gilt ring. Plate: a panel."],
	target = L["Column: bars by a portrait. Wide bar: no portrait. Sigil: centred, with debuffs. Plate: a panel."],
	card = L["Standard: clean bars under a section cap. Plate: a panel."],
	row = L["Standard: a name over a thin bar. Plate: a small tile."],
}

local function KindRows(schema, kind)
	local function portraitOn(s)
		return s.portrait ~= false
	end
	schema[#schema + 1] = Header(kind, L["frame"])
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "enabled", label = L["Show this frame"],
		help = L["Turn this frame off to leave its unit without a KstyleUI frame."],
	})
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "style", label = L["Style"],
		help = STYLE_HELP[kind == "target" and "target" or Settings.COLUMN[kind] and "column" or Settings.FORMS[kind]],
		options = kind == "target" and CHOICES.styleTarget or Settings.COLUMN[kind] and CHOICES.style or CHOICES.styleLumen,
	})
	if kind == "boss" then
		schema[#schema + 1] = Row(kind, {
			type = "dropdown", key = "growth", label = L["Growth"],
			help = L["Down from the top, or up from the foot so a lone boss sits by your combat cluster."],
			options = CHOICES.growth,
		})
		schema[#schema + 1] = Row(kind, { type = "slider", key = "gap", label = L["Spacing"],
			help = L["The gap between boss frames in units. The frames share the element's height."], min = 0, max = BOSS_GAP_MAX, step = 1 })
	end
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "portrait", label = L["Portrait"],
		help = L["Shows a portrait beside the bars."],
	})
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "portraitStyle", label = L["Portrait style"],
		help = L["A 2D character portrait or the unit's class icon."], options = CHOICES.portraitStyle,
	}, portraitOn)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "portraitShape", label = L["Portrait shape"],
		help = L["A chamfered frame, as on the KstyleUI kit, or a round ring. The level badge follows it."],
		options = CHOICES.portraitShape,
	}, portraitOn)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "portraitSide", label = L["Portrait side"],
		help = L["Which side of the bars the portrait sits on."], options = CHOICES.portraitSide,
	}, portraitOn)
	local function flatPortrait(s)
		return portraitOn(s) and K.HudStyle.Current() ~= "medallions"
	end
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "portraitMirror", label = L["Mirror portrait"],
		help = L["Flips the portrait or class icon to face the other way."] }, flatPortrait)
	schema[#schema + 1] = Row(kind, { type = "slider", key = "portraitZoom", label = L["Portrait zoom"],
		help = L["Crops into the portrait or class icon. 0 shows all of it."], min = 0, max = ZOOM_MAX, step = ZOOM_STEP }, flatPortrait)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "name", label = L["Name"],
		help = L["Shows the unit's name."],
	})
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "nameCaps", label = L["Capital letters"],
		help = L["Writes the name in capital letters, as the KstyleUI captions do."],
	}, function(s)
		return s.name ~= false
	end)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "level", label = L["Level"],
		help = L["Shows the unit's level in a badge on the portrait, or after the name."],
	})
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "levelDifficulty", label = L["Level difficulty colour"],
		help = L["Colours an enemy's level number by how hard it is for you."] }, function(s) return s.level ~= false end)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "levelFriendly", label = L["Friendly level colour"],
		help = L["Gives friendly units their level's difficulty colour too."] }, function(s) return s.level ~= false and s.levelDifficulty == true end)
	schema[#schema + 1] = Header(kind, L["health bar"])
	BarRows(schema, kind, "health")
	schema[#schema + 1] = Row(kind, { type = "slider", key = "healthAlpha", label = L["Fill opacity"],
		help = L["How solid the health fill is. Lower lets the track show through."], min = ALPHA_MIN, max = 1, step = ALPHA_STEP })
	schema[#schema + 1] = Row(kind, { type = "dropdown", key = "healthGradient", label = L["Fill gradient"],
		help = L["Shades the health fill from darker to its colour."], options = CHOICES.gradient }, function(s) return s.healthColor ~= "health" end)
	if kind == "target" then
		schema[#schema + 1] = Row(kind, {
			type = "toggle", key = "transitions", label = L["Gentle target changes"],
			help = L["Medallions: fades target loss and changes, and greys a dead target. Off changes it immediately."],
		})
		schema[#schema + 1] = Row(kind, {
			type = "toggle", key = "percentLead", label = L["Lead with target percent"],
			help = L["In Medallions, shows percent first and smaller current and maximum health at the far end."],
		})
	end
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "healPrediction", label = L["Incoming heals"],
		help = L["Shows incoming heals and absorb shields on the health bar."],
	})
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "absorbs", label = L["Absorbs"],
		help = L["Shows absorb shields when incoming heals are enabled."] }, function(s) return s.healPrediction ~= false end)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "healAbsorbs", label = L["Heal absorbs"],
		help = L["Marks the health that heal-absorbing debuffs will eat, from the fill's end."] }, function(s) return s.healPrediction ~= false end)
	for _, spec in ipairs({
		{ "incomingAlpha", L["Incoming heal opacity"], L["How solid incoming heals look on the health bar."], function() return true end },
		{ "absorbAlpha", L["Absorb opacity"], L["How solid absorb shields look on the health bar."], function(s) return s.absorbs ~= false end },
		{ "healAbsorbAlpha", L["Heal absorb opacity"], L["How solid heal absorbs look on the health bar."], function(s) return s.healAbsorbs == true end },
	}) do
		schema[#schema + 1] = Row(kind, { type = "slider", key = spec[1], label = spec[2], help = spec[3], min = ALPHA_MIN, max = 1, step = ALPHA_STEP },
			function(s) return s.healPrediction ~= false and spec[4](s) end)
	end
	schema[#schema + 1] = Header(kind, L["power bar"])
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "power", label = L["Power bar"],
		help = L["Shows the unit's mana, rage, energy or focus under its health."],
	})
	BarRows(schema, kind, "power")
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "powerSeparate", label = L["Separate similar health and power colours"],
		help = L["When the colours are close, draws power in steel with a thin line of its original colour."],
	}, function(s) return s.power ~= false end)
	schema[#schema + 1] = Row(kind, { type = "slider", key = "powerAlpha", label = L["Fill opacity"],
		help = L["How solid the power fill is. Lower lets the track show through."], min = ALPHA_MIN, max = 1, step = ALPHA_STEP }, function(s) return s.power ~= false end)
	schema[#schema + 1] = Row(kind, { type = "dropdown", key = "powerGradient", label = L["Fill gradient"],
		help = L["Shades the power fill from darker to its colour."], options = CHOICES.gradient }, function(s) return s.power ~= false end)
	schema[#schema + 1] = Header(kind, L["text"])
	for _, element in ipairs(Settings.TEXTS) do
		TextRows(schema, kind, element)
	end
	for i = 1, 2 do
		local key = "extra" .. i
		schema[#schema + 1] = Header(kind, L["Extra text"] .. " " .. i)
		K.Widgets.TextRows(schema, key, { outlines = CHOICES.outline, tags = true, placement = true,
			row = function(row) return Row(kind, row) end })
	end
	IconRows(schema, kind)
	if Settings.CASTBAR[kind] then
		CastRows(schema, kind)
	end
	if Settings.AURAS[kind] then
		AuraRows(schema, kind)
	end
	if kind == "player" then
		ResourceRows(schema)
	end
end

function Settings.Schema()
	local schema = {
		{ type = "header", label = L["Unit frames"] },
		{ type = "dropdown", key = "auraLayout", label = L["Aura layout"], help = L["Place auras above their frames or restore the crest fan."],
			options = Options({ { "rows", L["Rows above frames"] }, { "fan", L["Crest fan"] } }),
			showWhen = function() return K.HudStyle.Current() == "medallions" end },
		{ type = "toggle", key = "castOutcomes", label = L["Readable cast outcomes"],
			help = L["Keeps failed casts readable and acknowledges channels. Off restores the original cast effects."] },
		{ type = "toggle", key = "castbarRaise", label = L["Cast bars above other frames"],
			help = L["Draws every unit frame cast bar above other frames so nothing covers it."] },
		{ type = "toggle", key = "healthDecimal", label = L["Health percent with a decimal"],
			help = L["Shows health percentages with one decimal place. Shortened health values already show one."] },
		{ type = "dropdown", key = "unitTooltip", label = L["Unit tooltips"], options = CHOICES.unitTooltip,
			help = L["When hovering a unit frame shows the unit's tooltip."] },
		{ type = "toggle", key = "stableSlabNames", label = L["Keep Medallions name face"],
			help = L["Shorten long names in the same face and capitals. Off allows the original body face."] },
		{ type = "toggle", key = "singleSlabLevel", label = L["Show each level once"],
			help = L["Keep the portrait level and leave room for names. Off repeats the level beside the name."] },
		{
			type = "toggle", key = "hideBlizzard", label = L["Hide Blizzard's unit frames"],
			help = L["Hides Blizzard's player, target, focus, pet and boss frames that KstyleUI replaces."],
		},
		{
			type = "dropdown", key = "accent", label = L["Accent"],
			help = L["The colour of the portrait frames, and of the badges on round portraits."], options = CHOICES.accent,
		},
		{
			type = "color", key = "accentColor", label = L["Custom accent"],
			help = L["The accent colour when the accent is custom."],
			showWhen = function(s)
				return s.accent == "custom"
			end,
		},
		{ type = "header", label = L["Medallions danger"] },
		{
			type = "toggle", key = "dangerEdge", label = L["Restrained danger edge"],
			help = L["Keeps danger at the edges and hides it with the UI. Off restores the original red glow."],
		},
		{
			type = "toggle", key = "cleanLowRing", label = L["Clean player danger ring"],
			help = L["A smooth ring on you, a still red rim on enemies. Off restores every portrait's smoky pulse."],
		},
		{ type = "header", label = L["Orbs"] },
		{
			type = "toggle", key = "orbGlass", label = L["Sharp orb glass"],
			help = L["A crisper glass with a hard glint and a clearer band for health just lost."],
		},
		{
			type = "toggle", key = "orbLedge", label = L["Ledge under bar 2"],
			help = L["Seats the split bar 2 on a metal ledge across the tray."],
		},
		{
			type = "toggle", key = "orbCastRoom", label = L["Room for long spell names"],
			help = L["Widens the target's cast bar so long spell names show in full."],
		},
		{ type = "header", label = L["Customise"] },
	}
	local frames = {}
	for i, kind in ipairs(KINDS) do
		frames[i] = { value = kind, label = Settings.LABELS[kind] }
	end
	schema[#schema + 1] = {
		type = "dropdown", key = "edit", label = L["Frame to customise"],
		help = L["Pick a frame to show its settings below."], options = frames,
	}
	for _, kind in ipairs(KINDS) do
		KindRows(schema, kind)
	end
	return schema
end
