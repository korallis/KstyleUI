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
local MARKER_MAX, CAST_WIDTH_MIN, CAST_WIDTH_MAX, CARD_CAST = 48, 2 * CAST_HEIGHT_MAX, 400, 16
local PRECISE_MAX, SPELL_LIST_LETTERS = 90, 240
local HEALTH_HEIGHT_MAX, ABSORB_BAR_MAX, OFFSET_MAX, DETACH_WIDTH_MAX = 40, 10, 100, 600
local NO_ABOVE = { slab = true, bar = true, sigil = true }
Settings.OFFSET_MAX = OFFSET_MAX

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

Settings.CASTBAR = { player = true, target = true, focus = true, boss = true, pet = true }
Settings.CAST_ELEMENTS = { player = "unitframes.castbar.player", target = "unitframes.castbar.target" }
Settings.AURAS = { player = true, target = true, focus = true, boss = true, pet = true }

local function Color(token)
	local r, g, b = Tokens.Color(token)
	return { r = r, g = g, b = b }
end

local BAR_TEXTURE = Tokens.MediaList("statusbar")[1].path

local function TextStyle(size)
	return { font = THEME_FONT, size = size, outline = "INHERIT", x = 0, y = 0 }
end

local COMPACT_TEXT = { 12, 12, 9, 10 }

local function ExtraText()
	return { font = "", size = 12, outline = "OUTLINE", colorMode = "", color = Color("textEmphasis"),
		textFormat = "", position = "CENTER", x = 0, y = 0, width = 100 }
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
		healthHeight = 0, incomingTexture = "", absorbTexture = "", healAbsorbTexture = "",
		absorbPlacement = "", healAbsorbPlacement = "", absorbGlow = false, absorbBar = "", absorbBarHeight = 3,
		maxHealthLoss = false, maxHealthAlpha = 0.5,
		powerAbove = false, powerTextAlign = "", powerTextColor = "", powerTextCustom = Color("textEmphasis"),
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
		markerSize = 0,
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
		castbarAlpha = 1,
		castbarTextX = 0, castbarTextY = 0, castbarTimerX = 0, castbarTimerY = 0,
		castbarTarget = false,
		castbarImportant = false,
		castbarImportantColor = Color("legendary"),
		castbarHideIdle = true,
		auras = aura ~= nil and aura.on or false,
		auraCopy = "",
		auraBuffZoom = -1,
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
			power = { font = THEME_FONT, size = full and 12 or text[3], outline = "OUTLINE", x = 0, y = 0 },
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
	healthDecimalBoss = false, healthDecimalTrim = false, healthDecimalPercentOnly = true, targetSounds = false, reactionColors = false, hostileColor = Color("healthHostile"),
	neutralColor = Color("neutral"), friendlyColor = Color("friendly"), tappedColor = Color("textDisabled"),
	castbarRaise = false,
	dispelCustom = false, dispelMagic = Color("magic"), dispelCurse = Color("epic"), dispelPoison = Color("uncommon"), dispelDisease = Color("legendary"), dispelBleed = Color("hostile"),
	accent = "class",
	accentColor = Color("accentDefault"),
	dangerEdge = true,
	cleanLowRing = true,
	castbarOnFrame = true,
	edit = "player",
	player = Kind(true, {
		medallionsAuras = false, medallionsAuraFilter = "buffs",
		castbarSmooth = false, castbarChannelOverride = false, castbarChannelColor = Color("rare"), castbarTotal = false,
		powerCost = false, powerCostColor = Color("white"), manaSpark = false, powerMana = false,
		powerText = "auto",
		style = "column", combat = true, resting = true, castbarIcon = true, castbarCaps = true, castbarColor = "gold",
		healthColor = "hud",
	}, 20, 12, { on = false, size = 22, position = "BELOW" }, { 22, 15, 10, 14 }),
	target = Kind(true, {
		crestDebuffs = true, transitions = true,
		style = "column", rangeFade = true, portraitSide = "RIGHT", healthColor = "hud", castbarColor = "gold", castbarCaps = true, castbarIcon = false,
		power = false, auraSpacing = 4,
	}, 14, 12, { on = true, size = 27.6, columns = 4, rows = 1, position = "SIDE" }, { 22, 15, 10, 14 }),
	targettarget = Kind(false),
	focus = Kind(true, { power = false, castbarColor = "gold", castbarCaps = false }, 16, 12, { on = true, size = 20, position = "ABOVE" }, { 16, 14, 9, 12 }),
	focustarget = Kind(false),
	pet = Kind(false, { happiness = false, auraPosition = "ABOVE", auraColumns = 5, auraFilter = "debuffs", happinessPosition = "", castbarHeight = 12, castbarWidth = 0 }),
	boss = Kind(true, { power = false, castbarColor = "gold", castbarCaps = true, auraGrowth = "LEFT_DOWN", growth = "DOWN", gap = 6, auraSimple = "", castbarWidth = 0 }, 10, 12, { on = true, size = 22, columns = 4, rows = 1, position = "LEFT" }, { 13, 13, 9, 12 }),
	resource = {
		enabled = true,
		comboPoints = true,
		classPips = true,
		druidMana = true,
		comboColor = "class",
		comboCustom = Color("neutral"),
		manaColor = "power",
		manaCustom = Color("rare"),
		manaTexture = BAR_TEXTURE,
		manaOrientation = "RIGHT",
		manaText = "none",
		manaTextAlign = "",
		spacing = 3,
	},
}

Settings.defaults.target.fonts.aura.size = 12

local function AddDefaults(kinds, keys)
	for _, kind in ipairs(kinds) do
		for key, value in pairs(keys) do Settings.defaults[kind][key] = value end
	end
end
AddDefaults(KINDS, { auraTooltips = true, classZoom = 0, combatClassColor = false, powerPercentSign = true, leaderSize = 0, leaderX = 0, leaderY = 0,
	pvpSize = 0, pvpX = 0, pvpY = 0, combatSize = 0, combatX = 0, combatY = 0, leaderPlace = "", pvpPlace = "", combatPlace = "", markerPlace = "" })
AddDefaults({ "player" }, { threatNonTank = false, pvpTimer = false, pvpTimerSize = 10, pvpTimerX = 0, pvpTimerY = 0, pvpTimerPlace = "" })
AddDefaults({ "target", "focus" }, { threatPercent = false, threatPercentPosition = "RIGHT", slabThreatPercentPosition = "OUTLEFT", threatPercentColor = true })
Settings.defaults.focus.threatPercentPosition = "OUTRIGHT"
AddDefaults({ "target", "targettarget", "focus", "focustarget", "boss" }, { eliteSize = 0, eliteX = 0, eliteY = 0, eliteInstances = true, elitePlace = "" })
Settings.TEXT_BAR = { player = true, target = true, focus = true }
for kind in pairs(Settings.TEXT_BAR) do
	local d = Settings.defaults[kind]
	d.textBar, d.textBarPlace, d.textBarHeight, d.textBarWidth, d.textBarStrata, d.textBarIcon = false, "BOTTOM", 16, 0, "", ""
	d.textBarLeft, d.textBarCenter, d.textBarRight = ExtraText(), ExtraText(), ExtraText()
	d.textBarLeft.position, d.textBarRight.position = "LEFT", "RIGHT"
end
AddDefaults(KINDS, { powerDetach = "", powerDetachWidth = 0, powerDetachX = 0, powerDetachY = 0, powerDetachStrata = "" })

for _, kind in ipairs({ "targettarget", "focustarget", "pet" }) do
	local fonts = Settings.defaults[kind].fonts
	fonts.name.outline, fonts.health.outline = "OUTLINE", "OUTLINE"
end

local LIVE = {}
local function Live(d, values)
	for key, value in pairs(values) do
		d[key], LIVE[key] = value, true
	end
end
for _, kind in ipairs(KINDS) do
	Live(Settings.defaults[kind], { buffStealable = "", buffDefensive = "", buffDispellable = "", auraHidden = "", auraTracked = "",
		auraTimed = false, auraHideLockout = false, auraTrackedOnly = false, auraRowGap = 0, auraPrecise = 0, castbarFit = false, auraLists = "",
		castbarTargetPlace = "", castbarTargetSize = 0, castbarTargetX = 0, castbarTargetY = 0, castbarTargetColor = Color("textEmphasis"), auraBuffPlace = "", auraBuffX = 0, auraBuffY = 0 })
end
for kind in pairs(Settings.AURAS) do Live(Settings.defaults[kind], { auraTrackedDebuffs = false }) end
Live(Settings.defaults.player, { castbarRank = false, castbarLagText = false, castbarCraft = false, castbarCraftBar = false, castbarRangeGrey = false, dispelOverlay = "", dispelFilter = "PLAYER",
	dispelAlpha = 0.3, dispelEdge = false, dispelIcon = "", dispelIconSize = 14, totems = false, totemPosition = "RIGHT", totemSize = 24, castbarGcd = false })

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
	style = Options({ { "column", L["Standard"] }, { "plate", L["Plate"] } }),
	styleLumen = Options({ { "lumen", L["Standard"] }, { "plate", L["Plate"] } }),
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
	auraCopy = Options({ { "", L["Own settings"] }, { "player", L["Player"] }, { "target", L["Target"] }, { "focus", L["Focus"] }, { "pet", L["Pet"] }, { "boss", L["Boss"] } }),
	auraSimple = Options({ { "", L["Off"] }, { "LEFT", L["Left of the frame"] }, { "RIGHT", L["Right of the frame"] } }),
	happinessPosition = Options({ { "", L["Standard"] }, { "TOPLEFT", L["Above the left end"] }, { "TOPRIGHT", L["Above the right end"] }, { "LEFT", L["Left of the frame"] }, { "RIGHT", L["Right of the frame"] } }),
	placement = Options({ { "", L["Current style"] }, { "END", L["From the bar's end"] }, { "START", L["From the bar's start"] } }),
	absorbBar = Options({ { "", L["None"] }, { "TOP", L["Top"] }, { "BOTTOM", L["Bottom"] } }),
	align = Options({ { "", L["Current style"] }, { "LEFT", L["Left"] }, { "CENTER", L["Centre"] }, { "RIGHT", L["Right"] } }),
	powerTextColor = Options({ { "", L["Current style"] }, { "power", L["Power type"] }, { "custom", L["Custom colour"] } }),
	dispelOverlay = Options({ { "", L["Off"] }, { "health", L["Health bar"] }, { "frame", L["Whole frame"] } }),
	dispelFilter = Options({ { "PLAYER", L["Debuffs you can dispel"] }, { "GROUP", L["Debuffs anyone in the group can dispel"] } }),
	dispelIcon = Options({ { "", L["Off"] }, { "TOPLEFT", L["Top left"] }, { "TOP", L["Top"] }, { "TOPRIGHT", L["Top right"] }, { "LEFT", L["Left"] }, { "CENTER", L["Centre"] },
		{ "RIGHT", L["Right"] }, { "BOTTOMLEFT", L["Bottom left"] }, { "BOTTOM", L["Bottom"] }, { "BOTTOMRIGHT", L["Bottom right"] } }),
	totemPosition = Options({ { "ABOVE", L["Above the frame"] }, { "BELOW", L["Below the frame"] }, { "LEFT", L["Left of the frame"] }, { "RIGHT", L["Right of the frame"] } }),
	targetPlace = Options({ { "", L["With the spell name"] }, { "LEFT", L["On its own, left"] }, { "RIGHT", L["On its own, right"] } }),
	powerDetach = Options({ { "", L["In the frame"] }, { "BELOW", L["Below the frame, apart"] }, { "ABOVE", L["Above the frame, apart"] } }),
	buffPlace = Options({ { "", L["With the debuffs"] }, { "BELOW", L["Below the frame"] }, { "ABOVE", L["Above the frame"] }, { "RIGHT", L["Right of the frame"] }, { "LEFT", L["Left of the frame"] } }),
}
local CHOICES = Settings.CHOICES
CHOICES.threatPlace = Options({ { "OUTLEFT", L["Left of the bar"] }, { "OUTRIGHT", L["Right of the bar"] }, { "LEFT", L["Inside the left edge"] },
	{ "RIGHT", L["Inside the right edge"] }, { "CENTER", L["Centre"] } })
CHOICES.textBarPlace = Options({ { "BOTTOM", L["Bottom of the frame"] }, { "TOP", L["Top of the frame"] }, { "BELOW", L["Below the frame, apart"] }, { "ABOVE", L["Above the frame, apart"] } })
CHOICES.textBarIcon = Options({ { "", L["None"] }, { "LEFT", L["Left"] }, { "RIGHT", L["Right"] } })
CHOICES.iconPlace = Options({ { "", L["In the status row"] }, { "TOPLEFT", L["Top left"] }, { "TOPRIGHT", L["Top right"] }, { "BOTTOMLEFT", L["Bottom left"] }, { "BOTTOMRIGHT", L["Bottom right"] } })
CHOICES.timerPlace = Options({ { "", L["After the status icons"] }, { "LEFT", L["Left of the badge"] }, { "RIGHT", L["Right of the badge"] }, { "TOP", L["Above the badge"] }, { "BOTTOM", L["Below the badge"] } })
CHOICES.strata = { { value = "", label = L["Same as the frame"] } }
for _, option in ipairs(K.Layout and K.Layout.STRATA_OPTIONS or {}) do CHOICES.strata[#CHOICES.strata + 1] = option end

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
	auraCopy = "auraCopy",
	auraSimple = "auraSimple",
	happinessPosition = "happinessPosition",
	absorbPlacement = "placement", healAbsorbPlacement = "placement", absorbBar = "absorbBar",
	powerTextAlign = "align", powerTextColor = "powerTextColor",
	threatPercentPosition = "threatPlace",
	slabThreatPercentPosition = "threatPlace",
	dispelOverlay = "dispelOverlay", dispelFilter = "dispelFilter", dispelIcon = "dispelIcon", totemPosition = "totemPosition", auraLists = "auraCopy",
	textBarPlace = "textBarPlace", textBarIcon = "textBarIcon", textBarStrata = "strata",
	castbarTargetPlace = "targetPlace", powerDetach = "powerDetach", auraBuffPlace = "buffPlace", powerDetachStrata = "strata",
	leaderPlace = "iconPlace", pvpPlace = "iconPlace", combatPlace = "iconPlace", elitePlace = "iconPlace", markerPlace = "iconPlace", pvpTimerPlace = "timerPlace",
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

local function TextureOptions()
	local out = { { value = "", label = L["Same as the health bar"] } }
	for _, option in ipairs(K.Widgets.MediaOptions("statusbar")) do
		if type(option.value) == "string" then out[#out + 1] = option end
	end
	return out
end

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
	auraBuffZoom = { -1, ZOOM_MAX },
	markerSize = { 0, MARKER_MAX },
	castbarWidth = { 0, CAST_WIDTH_MAX },
	healthHeight = { 0, HEALTH_HEIGHT_MAX },
	absorbBarHeight = { 1, ABSORB_BAR_MAX },
	maxHealthAlpha = { ALPHA_MIN, 1 },
	classZoom = { 0, ZOOM_MAX }, leaderSize = { 0, ICON_SIZE_MAX }, pvpSize = { 0, ICON_SIZE_MAX }, eliteSize = { 0, ICON_SIZE_MAX }, combatSize = { 0, ICON_SIZE_MAX },
	pvpTimerSize = { FONT_SIZE_MIN, FONT_SIZE_MAX },
	dispelAlpha = { 0.05, 1 }, dispelIconSize = { 8, 40 }, totemSize = { 16, 48 },
	textBarHeight = { 8, CAST_HEIGHT_MAX }, textBarWidth = { 0, CAST_WIDTH_MAX },
	castbarTargetSize = { 0, FONT_SIZE_MAX }, powerDetachWidth = { 0, DETACH_WIDTH_MAX },
}
for _, key in ipairs({ "auraX", "auraY", "auraTimerX", "auraTimerY", "auraCountX", "auraCountY",
	"castbarTextX", "castbarTextY", "castbarTimerX", "castbarTimerY",
	"leaderX", "leaderY", "pvpX", "pvpY", "combatX", "combatY", "eliteX", "eliteY", "pvpTimerX", "pvpTimerY", "castbarTargetX", "castbarTargetY",
	"powerDetachX", "powerDetachY", "auraBuffX", "auraBuffY" }) do
	RANGES[key] = { -NUDGE, NUDGE }
end

local function IsNumber(v)
	return not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v == v
end

RANGES.auraRowGap, RANGES.auraPrecise = { 0, AURA_SPACING_MAX }, { 0, PRECISE_MAX }
CHOICES.lane = Options({ { "", L["Show all"] }, { "only", L["Only these"] }, { "hide", L["Hide these"] } })
CHOICE_OF.buffStealable, CHOICE_OF.buffDefensive, CHOICE_OF.buffDispellable = "lane", "lane", "lane"

local SLAB_DEFAULTS = { target = { auraSize = 22, auraSpacing = 2, auraColumns = 6, auraGrowth = "LEFT_DOWN" } }
local ROW_DEFAULTS = {
	player = { auraPosition = "ABOVE", auraGrowth = "RIGHT_UP", auraSize = 28, auraSpacing = 2, auraColumns = 6, auraRows = 2 },
	target = { auraPosition = "ABOVE", auraGrowth = "LEFT_UP", auraSize = 28, auraSpacing = 2, auraColumns = 6, auraRows = 2 },
}

local DERIVED = { auras = true, auraFilter = true, threatPercentPosition = true }
for _, list in pairs({ SLAB_DEFAULTS, ROW_DEFAULTS }) do
	for _, keys in pairs(list) do
		for key in pairs(keys) do DERIVED[key] = true end
	end
end

function Settings.AuraRows(kind)
	return ROW_DEFAULTS[kind] ~= nil and Settings.Module().auraLayout ~= "fan"
end

local AURA_LOOK = { auraSize = "simple", auraPosition = false, auraSpacing = true, auraRows = "simple", auraColumns = true,
	auraGrowth = true, auraTimer = true, auraZoom = true, auraBuffZoom = true, auraTooltipCombat = true, auraRowGap = true, auraPrecise = true }
Settings.AURA_LOOK = AURA_LOOK
local LISTS = { auraHidden = true, auraTracked = true, auraTrackedOnly = true, auraTrackedDebuffs = true }
Settings.LISTS = LISTS

local function SimpleSize()
	local G, uf = ns.Geometry, ns.Frames and ns.Frames.Get("boss")
	local h = uf and uf.holder:GetHeight()
	if not (IsNumber(h) and h > 0) then h = K.Setup.Layouts.Element(Settings.ELEMENTS.boss).height end
	local slot = (h - Settings.Value("boss", "gap") * (G.BOSS_COUNT - 1)) / G.BOSS_COUNT
	local n = Settings.Value("boss", "auraFilter") == "both" and 2 or 1
	return math.max(1, (slot - (n - 1) * Settings.Value("boss", "auraSpacing")) / n)
end

local function Value(kind, key)
	if kind == "player" and (key == "auras" or key == "auraFilter") and Settings.AuraRows(kind) then key = key == "auras" and "medallionsAuras" or "medallionsAuraFilter" end
	if key == "threatPercentPosition" and Settings.Form(kind) == "slab" then key = "slabThreatPercentPosition" end
	local own, d = Kinds(kind)
	local default = d[key]
	if default == nil then
		error("UnitFrames.Settings.Value: unknown setting " .. tostring(key), 2)
	end
	local value = own[key]
	local rows = ROW_DEFAULTS[kind]
	if rows and rows[key] ~= nil and (value == nil or value == default) and Settings.AuraRows(kind) then
		return key == "auraRows" and kind == "target" and Value(kind, "auraFilter") == "both" and default or rows[key]
	end
	local slab = SLAB_DEFAULTS[kind] and SLAB_DEFAULTS[kind][key]
	if slab ~= nil and (value == nil or value == default) and Settings.Form(kind) == "slab" then
		return slab
	end
	if value == default or type(value) ~= type(default) then
		return default
	end
	local choice = key == "style" and (Settings.COLUMN[kind] and "style" or "styleLumen") or CHOICE_OF[key]
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

function Settings.Lists(kind)
	local from = kind
	for _ = 1, #KINDS do
		local to = Kinds(from).auraLists
		if to == kind then return kind end
		if not (to and to ~= from and Settings.AURAS[to]) then return from end
		from = to
	end
	return kind
end

local function Linked(kind, key)
	if LISTS[key] then return Value(Settings.Lists(kind), key) end
	local look = AURA_LOOK[key]
	if look ~= nil then
		local own = Kinds(kind)
		local simple = kind == "boss" and look ~= true and own.auraSimple
		if simple == "LEFT" or simple == "RIGHT" then
			return key == "auraPosition" and simple or key == "auraRows" and 1 or SimpleSize()
		end
		local from = look and own.auraCopy
		if from and from ~= kind and Settings.AURAS[from] then
			return Value(from, key)
		end
	end
	return Value(kind, key)
end

local function Link()
	local linked = false
	for kind in pairs(Settings.AURAS) do
		local own = Kinds(kind)
		linked = linked or (own.auraCopy or "") ~= "" or (own.auraSimple or "") ~= "" or (own.auraLists or "") ~= ""
	end
	Settings.Value = linked and Linked or Value
end

function Settings.Value(kind, key)
	if not Saved() then return Value(kind, key) end
	Link()
	return Settings.Value(kind, key)
end
K.Callbacks.Register("SettingChanged", MODULE .. ":link", function(_, module, key) if module == MODULE and (key:find("aura[CSL]") or not key:find(".", 1, true)) and Saved() then Link() end end)
K.Callbacks.Register("ProfileChanged", MODULE .. ":link", function() if Saved() then Link() end end)

local RESOURCE_CHOICES = { comboColor = "accent", manaColor = "manaColor", manaOrientation = "orientation", manaText = "text", manaTextAlign = "align" }

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
	return Settings.Value(kind, "style") == "plate" and "plate" or "slab"
end

function Settings.CastOnFrame(kind)
	local key = Settings.CAST_ELEMENTS[kind]
	if not (key and Settings.Module().castbarOnFrame ~= false) then return false end
	local el = K.Layout.Element(key)
	local s, d = el and el.settings, el and el.default
	return not (s and d and (s.anchor ~= d.anchor or s.x ~= d.x or s.y ~= d.y or s.attachTo ~= d.attachTo or s.shown ~= d.shown or s.link ~= nil))
end

function Settings.Snapshot(kind)
	local fonts = {}
	local own, d = Kinds(kind)
	for _, element in ipairs(Settings.TEXTS) do
		local style = type(own.fonts) == "table" and type(own.fonts[element]) == "table" and own.fonts[element] or d.fonts[element]
		fonts[element] = { size = Settings.FontSize(kind, element) / K.Theme.FontScale(),
			colorMode = style.colorMode or "", color = style.color or d.fonts[element].color,
			textFormat = type(style.textFormat) == "string" and style.textFormat or "",
			x = style.x, y = style.y }
	end
	fonts.cast = { size = Settings.FontSize(kind, "cast") / K.Theme.FontScale() }
	local form = Settings.Form(kind)
	local s = { fonts = fonts, form = form, kind = kind, rowsAbove = Settings.AuraRows(kind), inlineCast = form == "column" and kind ~= "player" or Settings.CastOnFrame(kind) }
	local m = Settings.Module()
	s.healthDecimal = kind == "boss" and m.healthDecimalBoss == true and 2 or m.healthDecimal == true
	if s.healthDecimal and m.healthDecimalTrim == true then s.healthDecimal = s.healthDecimal == 2 and -2 or -1 end
	s.healthValues = kind == "boss" and m.healthDecimalBoss == true and m.healthDecimalPercentOnly == false
	s.textOptions = fonts.name.textFormat ~= "" or fonts.health.textFormat ~= "" or fonts.name.colorMode ~= "" or fonts.health.colorMode ~= ""
	for key, default in pairs(d) do
		if key ~= "fonts" and not LIVE[key] then
			local value = own[key]
			if DERIVED[key] or (value ~= nil and value ~= default) then default = Settings.Value(kind, key) end
			s[key] = default
		end
	end
	if (s.castbarWidth or 0) > 0 then s.castbarWidth = math.max(s.castbarWidth, CAST_WIDTH_MIN) end
	if kind == "boss" then s.cardCast = s.castbarHeight + CARD_CAST - d.castbarHeight end
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
			if row.type == "slider" then show = function(s) return on(s) and (s.style ~= "column" or bar == "power" and (s.powerDetach or "") ~= "") end end
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
	if element == "cast" or element == "aura" then return end
	for _, axis in ipairs({ { "x", L["Horizontal offset"], L["Moves this text left or right."] }, { "y", L["Vertical offset"], L["Moves this text up or down."] } }) do
		schema[#schema + 1] = Row(kind, { type = "slider", key = prefix .. "." .. axis[1], label = TEXT_LABELS[element] .. ": " .. axis[2],
			help = axis[3], min = -OFFSET_MAX, max = OFFSET_MAX, step = 1 })
	end
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
	schema[#schema + 1] = Row(kind, { type = "slider", key = "markerSize", label = L["Raid marker size"], min = 0, max = MARKER_MAX, step = 1,
		help = L["The raid marker's size in units. 0 follows the icon size."] }, function(s) return s.raidMarker ~= false end)
	local placeHelp = L["A corner moves it there, outside the frame where it would cross its text."]
	schema[#schema + 1] = Row(kind, { type = "dropdown", key = "markerPlace", label = L["Raid marker"] .. ": " .. L["Place"], help = placeHelp, options = CHOICES.iconPlace },
		function(s) return s.raidMarker ~= false end)
	if kind == "pet" then
		schema[#schema + 1] = Row(kind, { type = "dropdown", key = "happinessPosition", label = L["Happiness position"],
			help = L["Where the pet happiness badge sits."], options = CHOICES.happinessPosition }, function(s) return s.happiness == true end)
	end
	local function add(icon, row, second)
		schema[#schema + 1] = Row(kind, row, function()
			return (not icon or Settings.Value(kind, icon) == true) and (not second or Settings.Value(kind, second) == true)
		end)
	end
	local specs = { { "Size", L["Size"], L["0 follows Icon size."], 0, ICON_SIZE_MAX }, { "X", L["Horizontal offset"], L["Moves it left or right."], -NUDGE, NUDGE },
		{ "Y", L["Vertical offset"], L["Moves it up or down."], -NUDGE, NUDGE } }
	local function place(icon, label, key)
		for i = key and 2 or 1, 3 do
			local spec = specs[i]
			add(icon, { type = "slider", key = (key or icon) .. spec[1], label = label .. ": " .. spec[2], help = spec[3], min = spec[4], max = spec[5], step = 1 }, key)
		end
		if not key then add(icon, { type = "dropdown", key = icon .. "Place", label = label .. ": " .. L["Place"], help = placeHelp, options = CHOICES.iconPlace }) end
	end
	place("leader", L["Leader icon"])
	place("pvp", L["PvP icon"])
	place("combat", L["Combat icon"])
	add("combat", { type = "toggle", key = "combatClassColor", label = L["Combat icon in class colour"], help = L["Tints the crossed swords in the unit's class colour."] })
	if kind ~= "player" and kind ~= "pet" then
		place("elite", L["Elite and rare icon"])
		add("elite", { type = "toggle", key = "eliteInstances", label = L["Elite icon in instances"], help = L["Off hides the elite badge in dungeons and raids, where most enemies are elite."] })
	end
	if kind == "player" then
		add("pvp", { type = "toggle", key = "pvpTimer", label = L["PvP flag timer"], help = L["Shows the time left before your PvP flag drops, after the status icons."] })
		add("pvp", { type = "slider", key = "pvpTimerSize", label = L["Timer text size"], help = L["The size of the PvP flag timer."], min = FONT_SIZE_MIN, max = FONT_SIZE_MAX, step = 1 }, "pvpTimer")
		add("pvp", { type = "dropdown", key = "pvpTimerPlace", label = L["PvP flag timer"] .. ": " .. L["Place"], options = CHOICES.timerPlace,
			help = L["Above and below keep clear of the frame's text, taking the other side if needed."] }, "pvpTimer")
		place("pvp", L["PvP flag timer"], "pvpTimer")
		add("threat", { type = "toggle", key = "threatNonTank", label = L["Threat glow only as a non-tank"], help = L["Glows only in dungeons and raids, and only while your role is damage or healer."] })
	elseif kind == "target" or kind == "focus" then
		add(nil, { type = "toggle", key = "threatPercent", label = L["Threat percent"], help = L["Shows your threat on this unit as a percentage while the game shares it."] })
		for _, slab in ipairs({ false, true }) do
			schema[#schema + 1] = Row(kind, { type = "dropdown", key = slab and "slabThreatPercentPosition" or "threatPercentPosition", label = L["Threat percent place"],
				options = CHOICES.threatPlace, help = L["Where the threat percentage sits on the health bar."] }, function()
				return Settings.Value(kind, "threatPercent") == true and (Settings.Form(kind) == "slab") == slab
			end)
		end
		add("threatPercent", { type = "toggle", key = "threatPercentColor", label = L["Colour by threat"], help = L["Colours the percentage by your threat. Off uses the frame's text colour."] })
	end
end

CastRows = function(schema, kind)
	local function on(s)
		return s.castbar ~= false
	end
	local function named(s) return on(s) and s.castbarText ~= false end
	schema[#schema + 1] = Header(kind, L["cast bar"])
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbar", label = L["Cast bar"],
		help = L["Shows the unit's casts and channels."],
	})
	if kind ~= "pet" then
		schema[#schema + 1] = Row(kind, {
			type = "toggle", key = "castbarIcon", label = L["Spell icon"],
			help = L["Shows the spell's icon beside the cast bar."],
		}, on)
	end
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbarText", label = L["Spell name"],
		help = L["Shows the spell's name on the cast bar."],
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbarCaps", label = L["Spell name in capitals"],
		help = L["Capitals spaced wide, like the frame's name. Off, the name reads as the game writes it."],
	}, named)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbarTimer", label = L["Timer"],
		help = L["Shows the seconds left on the cast bar."],
	}, on)
	K.Widgets.BarRows(schema, "", {
		keys = { texture = "castbarTexture", colorSource = "castbarColor", color = "castbarCustom" },
		options = CHOICES.castbarColor,
		height = not Settings.CAST_ELEMENTS[kind] and { CAST_HEIGHT_MIN, CAST_HEIGHT_MAX, 1, key = "castbarHeight" } or nil,
		row = function(row)
			if kind == "boss" and row.type == "slider" then
				row.shown = function(value) return Settings.Form(kind) == "card" and value + CARD_CAST - Settings.defaults.boss.castbarHeight or value end
			end
			return Row(kind, row, row.type == "color" and function(s) return on(s) and s.castbarColor == "custom" end or on)
		end,
	})
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "castbarOrientation", label = L["Fill direction"],
		help = L["Which way the cast bar fills. A bar taller than it is wide stacks its icon on top."],
		options = CHOICES.orientation,
	}, on)
	for _, spec in ipairs({ { "castbarText", L["Spell name"] }, { "castbarTimer", L["Timer"] } }) do
		local part = spec[1]
		Nudges(schema, kind, part, spec[2], function(s) return on(s) and s[part] ~= false end)
	end
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarTarget", label = L["Spell target"],
		help = L["Adds who the spell is cast on after its name, when the game shows it."] }, named)
	local function targeted(s) return named(s) and s.castbarTarget == true end
	local function apart(s) return targeted(s) and (s.castbarTargetPlace or "") ~= "" end
	schema[#schema + 1] = Row(kind, { type = "dropdown", key = "castbarTargetPlace", label = L["Spell target place"], options = CHOICES.targetPlace,
		help = L["After the spell name, or its own text on one half of the name's line."] }, targeted)
	schema[#schema + 1] = Row(kind, { type = "slider", key = "castbarTargetSize", label = L["Spell target size"], min = 0, max = FONT_SIZE_MAX, step = 1,
		help = L["The spell target's text size. 0 matches the spell name."],
		shown = function(value) return value == 0 and math.floor(Settings.FontSize(kind, "cast") / K.Theme.FontScale() + 0.5) or value end }, apart)
	schema[#schema + 1] = Row(kind, { type = "color", key = "castbarTargetColor", label = L["Spell target colour"], help = L["The spell target's text colour."] }, apart)
	Nudges(schema, kind, "castbarTarget", L["Spell target"], apart)
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
	if kind == "pet" or kind == "boss" then
		schema[#schema + 1] = Row(kind, { type = "slider", key = "castbarWidth", label = L["Cast bar width"], min = 0, max = CAST_WIDTH_MAX, step = 1,
			help = kind == "pet" and L["The cast bar's width under the frame. 0 matches the frame."] or L["The cast bar's width, from its left end. 0 matches the frame."],
			shown = function(value) return value > 0 and math.max(value, CAST_WIDTH_MIN) or value end }, on)
	end
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarHideIdle", label = L["Hide when idle"],
		help = L["Hides the cast bar between casts. Off keeps its empty track shown."] }, on)
	if kind == "player" then
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarSmooth", label = L["Smooth cast progress"],
			help = L["Use the game's smoothing for cast and channel progress."] }, on)
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarChannelOverride", label = L["Separate channel colour"],
			help = L["Use a separate fill colour while you channel a spell."] }, on)
		schema[#schema + 1] = Row(kind, { type = "color", key = "castbarChannelColor", label = L["Channel colour"],
			help = L["The fill colour for channels. Uninterruptible colour still takes priority."] }, function(s) return on(s) and s.castbarChannelOverride == true end)
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarGcd", label = L["Global cooldown"],
			help = L["Between casts, the cast bar fills over the global cooldown after an instant spell."] }, on)
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarRangeGrey", label = L["Grey when out of range"],
			help = L["Greys the fill while your target is out of range of the spell you are casting."] }, on)
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarLatency", label = L["Latency zone"],
			help = L["Marks world latency at the end of your cast when cast times are readable."] }, on)
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarTotal", label = L["Show total duration"],
			help = L["Show the time cast so far and the full cast time, such as 0.4 / 2.0."] }, function(s) return on(s) and s.castbarTimer ~= false end)
	end
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarFit", label = L["Show full spell name"],
		help = L["Shrinks long spell names to fit instead of cutting them off."] }, named)
	if kind == "player" then
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarRank", label = L["Show spell rank"],
			help = L["Adds the spell's rank after its name, for spells that have one."] }, named)
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarLagText", label = L["Show latency"],
			help = L["Adds your world latency to the timer, such as 1.8 (42ms)."] }, function(s) return on(s) and s.castbarTimer ~= false end)
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarCraft", label = L["Whole craft batch"],
			help = L["Crafting a batch, the timer counts down the whole batch and the name shows how many are left."] }, on)
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "castbarCraftBar", label = L["Whole batch on the bar"],
			help = L["Crafting a batch, the bar fills once across every craft, with the batch's timer and count."] }, on)
	end
	TextRows(schema, kind, "cast")
end

local function FilterRows(schema, kind, on, own)
	local function listed() return Settings.Lists(kind) == kind end
	local function buffs()
		local filter = Settings.Value(kind, "auraFilter")
		return on() and (filter == "buffs" or filter == "both")
	end
	for _, spec in ipairs({
		{ "buffStealable", L["Stealable buffs"], L["Buffs a spell steal or purge can take: show only these, or hide them."] },
		{ "buffDefensive", L["Big defensives"], L["Major defensive cooldowns: show only these, or hide them."] },
		{ "buffDispellable", L["Dispellable buffs"], L["Buffs with a dispel type: show only these, or hide them."] },
	}) do
		schema[#schema + 1] = Row(kind, { type = "dropdown", key = spec[1], label = spec[2], help = spec[3], options = CHOICES.lane }, buffs)
	end
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "auraTimed", label = L["Only auras with a duration"],
		help = L["Hides auras that never run out."] }, on)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "auraHideLockout", label = L["Hide Bloodlust lockouts"],
		help = L["Hides Sated, Exhaustion and the other Bloodlust lockout debuffs on friendly units."] }, on)
	schema[#schema + 1] = Row(kind, { type = "text", key = "auraHidden", label = L["Hidden spell IDs"], maxLetters = SPELL_LIST_LETTERS,
		help = L["Hides these spell IDs, separated by commas or spaces, on buffs of friends and debuffs of enemies."] }, function() return on() and listed() end)
	local enemies = kind ~= "player" and kind ~= "pet"
	local function foes() return enemies and on() and Settings.Value(kind, "auraFilter") ~= "buffs" end
	schema[#schema + 1] = Row(kind, { type = "text", key = "auraTracked", label = L["Tracked spell IDs"], maxLetters = SPELL_LIST_LETTERS,
		help = L["Spell IDs, separated by commas or spaces, that Only tracked buffs and debuffs keep."] }, function() return (buffs() or foes()) and listed() end)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "auraTrackedOnly", label = L["Only tracked buffs"],
		help = L["On friendly units, shows only the buffs in Tracked spell IDs. Enemy buffs show as usual."] }, function() return buffs() and listed() end)
	if enemies then
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "auraTrackedDebuffs", label = L["Only tracked debuffs"],
			help = L["On enemies, shows only the debuffs in Tracked spell IDs. Debuffs on friends show as usual."] }, function() return foes() and listed() end)
	end
	schema[#schema + 1] = Row(kind, { type = "slider", key = "auraRowGap", label = L["Extra row spacing"],
		help = L["Adds this many units between aura rows, on top of Aura spacing."], min = 0, max = AURA_SPACING_MAX, step = 1 }, own)
	schema[#schema + 1] = Row(kind, { type = "slider", key = "auraPrecise", label = L["Precise timers below (minutes)"],
		help = L["Timers under this many minutes show minutes and seconds, such as 4m 32s. 0 keeps the short form."],
		min = 0, max = PRECISE_MAX, step = 1 }, function(s) return own(s) and s.auraTimer ~= false end)
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
		}, function() return Settings.Module().auraLayout == "fan" end)
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
	local copies = {}
	for _, option in ipairs(CHOICES.auraCopy) do
		if option.value == "" or option.value ~= kind and Settings.AURAS[option.value] then copies[#copies + 1] = option end
	end
	schema[#schema + 1] = Row(kind, { type = "dropdown", key = "auraCopy", label = L["Copy auras from"], options = copies,
		help = L["Use another frame's aura size, spacing, rows, growth, timers and zoom."] }, on)
	schema[#schema + 1] = Row(kind, { type = "dropdown", key = "auraLists", label = L["Spell ID lists from"], options = copies,
		help = L["Use another frame's hidden and tracked spell IDs, and its Only tracked buffs switch."] }, on)
	local function simple(s) return kind == "boss" and (s.auraSimple == "LEFT" or s.auraSimple == "RIGHT") end
	local function own(s) return on() and (s.auraCopy == nil or s.auraCopy == "" or s.auraCopy == kind) end
	local function placed(s) return on() and not simple(s) end
	local function sized(s) return own(s) and not simple(s) end
	if kind == "boss" then
		schema[#schema + 1] = Row(kind, { type = "dropdown", key = "auraSimple", label = L["Simple aura display"], options = CHOICES.auraSimple,
			help = L["Large icons beside each boss frame, filling its height: one row, or one each for debuffs and buffs."] }, on)
	end
	FilterRows(schema, kind, on, own)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "auraPosition", label = L["Aura position"],
		help = L["Which side of the frame the auras sit on."], options = CHOICES.auraPosition,
	}, placed)
	Nudges(schema, kind, "aura", L["Auras"], on)
	local function both(s) return placed(s) and Settings.Value(kind, "auraFilter") == "both" end
	schema[#schema + 1] = Row(kind, { type = "dropdown", key = "auraBuffPlace", label = L["Buff position"], options = CHOICES.buffPlace,
		help = L["With the debuffs, or in their own block on another side of the frame."] }, both)
	Nudges(schema, kind, "auraBuff", L["Buffs"], function(s) return both(s) and ns.Auras.Apart(kind) end)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "auraGrowth", label = L["Aura growth"],
		help = L["Which way new aura icons are added."], options = CHOICES.auraGrowth,
	}, own)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraSize", label = L["Aura icon size"],
		help = L["The size of each aura icon in units."], min = AURA_SIZE_MIN, max = AURA_SIZE_MAX, step = 1,
	}, sized)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraSpacing", label = L["Aura spacing"],
		help = L["The gap between aura icons in units."], min = 0, max = AURA_SPACING_MAX, step = 1,
	}, own)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraRows", label = L["Aura rows"],
		help = L["How many rows of each kind of aura show."], min = 1, max = AURA_ROWS_MAX, step = 1,
	}, sized)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraColumns", label = L["Aura columns"],
		help = L["How many aura icons fit in a row."], min = 1, max = AURA_COLUMNS_MAX, step = 1,
	}, own)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "auraTimer", label = L["Aura timers"],
		help = L["Shows the time left on each aura."],
	}, own)
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
		help = L["Crops into each aura icon. 0 shows the whole icon with its border."], min = 0, max = ZOOM_MAX, step = ZOOM_STEP }, own)
	schema[#schema + 1] = Row(kind, { type = "slider", key = "auraBuffZoom", label = L["Buff icon zoom"], min = 0, max = ZOOM_MAX, step = ZOOM_STEP,
		help = L["Crops buff icons on their own. Until set, buffs follow the aura icon zoom."],
		shown = function(value) return value < 0 and Settings.Value(kind, "auraZoom") or value end }, own)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "auraTooltips", label = L["Aura tooltips"],
		help = L["Off never shows a tooltip when you hover this frame's auras."] }, on)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "auraTooltipCombat", label = L["Aura tooltips in combat"],
		help = L["Off hides aura tooltips while you fight; they still show out of combat."] }, function(s) return own(s) and Settings.Value(kind, "auraTooltips") end)
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
	local function plain(r)
		return on(r) and r.classPips == false
	end
	local first = #schema + 1
	schema[#schema + 1] = { type = "header", label = Settings.LABELS.player .. ": " .. L["class resource"], showWhen = shows() }
	schema[#schema + 1] = {
		type = "toggle", key = "resource.enabled", label = L["Class resource"], showWhen = shows(),
		help = L["Shows combo points and the druid's mana under the player frame, and the crest's class crowns."],
	}
	schema[#schema + 1] = {
		type = "toggle", key = "resource.comboPoints", label = L["Combo points"], showWhen = shows(on),
		help = L["Shows rogue and cat form combo points as pips."],
	}
	schema[#schema + 1] = {
		type = "toggle", key = "resource.classPips", label = L["Class-themed pips"], showWhen = shows(on),
		help = L["Animated class marks, from a rogue's daggers to a hunter's arrows. Off: plain combo pips only."],
	}
	schema[#schema + 1] = {
		type = "dropdown", key = "resource.comboColor", label = L["Combo point colour"], showWhen = shows(plain),
		help = L["The pips follow the class colour or a custom colour."], options = CHOICES.accent,
	}
	schema[#schema + 1] = {
		type = "color", key = "resource.comboCustom", label = L["Custom combo point colour"],
		help = L["The pips' colour when it is custom."],
		showWhen = shows(function(r)
			return plain(r) and r.comboColor == "custom"
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
	schema[#schema + 1] = { type = "dropdown", key = "resource.manaText", label = L["Druid bar text"], showWhen = shows(on),
		help = L["Writes the druid bar's value on it."], options = CHOICES.text }
	schema[#schema + 1] = { type = "dropdown", key = "resource.manaTextAlign", label = L["Text position"], options = CHOICES.align,
		help = L["Where the text sits on the bar: left, centre or right."], showWhen = shows(function(r) return on(r) and r.manaText ~= "none" end) }
	for i = first, #schema do
		schema[i].scope = Scope("player")
	end
end

local function TextBarRows(schema, kind)
	local function on(s) return s.textBar == true end
	schema[#schema + 1] = Header(kind, L["text bar"])
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "textBar", label = L["Text bar"],
		help = L["A strip with left, centre and right text. It takes its room from the frame, so nothing moves."] })
	for _, spec in ipairs({
		{ "dropdown", "textBarPlace", L["Text bar place"], L["The frame's bottom or top edge, or below or above it with a gap."], CHOICES.textBarPlace },
		{ "slider", "textBarHeight", L["Text bar height"], L["The strip's height in units."], nil, 8, CAST_HEIGHT_MAX },
		{ "slider", "textBarWidth", L["Text bar width"], L["The strip's width when it sits apart, centred on the frame. 0 matches the frame."], nil, 0, CAST_WIDTH_MAX },
		{ "dropdown", "textBarStrata", L["Text bar strata"], L["Which layer the strip draws in."], CHOICES.strata },
		{ "dropdown", "textBarIcon", L["Class icon"], L["The unit's class icon at one end of the strip."], CHOICES.textBarIcon },
	}) do
		schema[#schema + 1] = Row(kind, { type = spec[1], key = spec[2], label = spec[3], help = spec[4], options = spec[5], min = spec[6], max = spec[7], step = spec[6] and 1 },
			spec[2] == "textBarWidth" and function(s) return on(s) and (s.textBarPlace == "BELOW" or s.textBarPlace == "ABOVE") end or on)
	end
	for _, slot in ipairs({ { "textBarLeft", L["Left text"] }, { "textBarCenter", L["Centre text"] }, { "textBarRight", L["Right text"] } }) do
		K.Widgets.TextRows(schema, slot[1], { outlines = CHOICES.outline, tags = true, width = true, row = function(row)
			row.label = slot[2] .. ": " .. row.label
			if row.type == "text" then row.help = L["Blank hides it. Tags: [name] [hp:pct] [pp:abr] [level] [absorb] [target] [group] [c:ff8800]x[/c]."] end
			return Row(kind, row, row.type == "color" and function(s) return on(s) and s[slot[1]].colorMode == "custom" end or on)
		end })
		for _, axis in ipairs({ { "x", L["Horizontal offset"], L["Moves this text left or right."] }, { "y", L["Vertical offset"], L["Moves this text up or down."] } }) do
			schema[#schema + 1] = Row(kind, { type = "slider", key = slot[1] .. "." .. axis[1], label = slot[2] .. ": " .. axis[2], help = axis[3], min = -NUDGE, max = NUDGE, step = 1 }, on)
		end
	end
end


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
		help = L["Standard: the Medallions slab. Plate: a panel."],
		options = Settings.COLUMN[kind] and CHOICES.style or CHOICES.styleLumen,
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
	schema[#schema + 1] = Row(kind, { type = "slider", key = "healthHeight", label = L["Health bar height"], min = 0, max = HEALTH_HEIGHT_MAX, step = 1,
		help = L["The health bar's height in units. 0 keeps the style's own."] }, function()
			local form = Settings.Form(kind)
			return form ~= "plate" and form ~= "slab"
		end)
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
	local function shields(s) return s.healPrediction ~= false and s.absorbs ~= false end
	local function eaten(s) return s.healPrediction ~= false and s.healAbsorbs == true end
	for _, spec in ipairs({
		{ "texture", "incomingTexture", L["Incoming heal texture"], function(s) return s.healPrediction ~= false end },
		{ "dropdown", "absorbPlacement", L["Absorb placement"], shields, L["After the health fill, or from the bar's end or start, so a shield on full health shows."], CHOICES.placement },
		{ "texture", "absorbTexture", L["Absorb texture"], shields },
		{ "toggle", "absorbGlow", L["Overshield glow"], nil, L["Lights the bar's end while shields are larger than the missing health."] },
		{ "dropdown", "absorbBar", L["Absorb bar"], nil, L["A thin bar along the health bar's top or bottom that fills with the unit's shields."], CHOICES.absorbBar },
		{ "slider", "absorbBarHeight", L["Absorb bar height"], function(s) return s.absorbBar ~= "" end, L["The absorb bar's height in units."] },
		{ "dropdown", "healAbsorbPlacement", L["Heal absorb placement"], eaten, L["Back from the health fill's end, or from the bar's end or start."], CHOICES.placement },
		{ "texture", "healAbsorbTexture", L["Heal absorb texture"], eaten },
		{ "toggle", "maxHealthLoss", L["Lost maximum health"], nil, L["Shortens the health fill by the maximum health lost to effects and marks the lost part."] },
		{ "slider", "maxHealthAlpha", L["Lost maximum health opacity"], function(s) return s.maxHealthLoss == true end, L["How solid the lost maximum health mark looks."] },
	}) do
		local row = { type = spec[1], key = spec[2], label = spec[3], help = spec[5] or L["The texture this part is drawn with; Same as the health bar follows it."], options = spec[6] }
		if spec[2]:find("Texture$") then row.options = TextureOptions end
		if spec[2] == "absorbBarHeight" then row.min, row.max, row.step = 1, ABSORB_BAR_MAX, 1 end
		if spec[2] == "maxHealthAlpha" then row.min, row.max, row.step = ALPHA_MIN, 1, ALPHA_STEP end
		schema[#schema + 1] = Row(kind, row, spec[4])
	end
	if kind == "player" then
		local function flat() return Settings.Form(kind) ~= "slab" end
		local function any(s) return flat() and ((s.dispelOverlay or "") ~= "" or s.dispelEdge == true or (s.dispelIcon or "") ~= "") end
		for _, spec in ipairs({
			{ "dropdown", "dispelOverlay", L["Dispel overlay"], flat, L["Washes the health bar or the whole frame in a debuff's dispel colour."], CHOICES.dispelOverlay },
			{ "slider", "dispelAlpha", L["Highlight fill opacity"], function(s) return flat() and (s.dispelOverlay or "") ~= "" end, L["How strongly the debuff type's colour tints the frame."] },
			{ "toggle", "dispelEdge", L["Dispel edge"], flat, L["Outlines the frame in a debuff's dispel colour."] },
			{ "dropdown", "dispelIcon", L["Dispel type icon"], flat, L["Shows the type icon of a debuff you can dispel on the health bar. Off shows none."], CHOICES.dispelIcon },
			{ "slider", "dispelIconSize", L["Dispel type icon size"], function(s) return flat() and (s.dispelIcon or "") ~= "" end, L["The dispel type icon's size."] },
			{ "dropdown", "dispelFilter", L["Highlight debuffs"], any, L["Highlights debuffs you can dispel, or ones anyone in the group can."], CHOICES.dispelFilter },
		}) do
			local row = { type = spec[1], key = spec[2], label = spec[3], help = spec[5], options = spec[6] }
			if spec[1] == "slider" then row.min, row.max, row.step = RANGES[spec[2]][1], RANGES[spec[2]][2], spec[2] == "dispelAlpha" and 0.05 or 1 end
			schema[#schema + 1] = Row(kind, row, spec[4])
		end
		schema[#schema + 1] = Row(kind, { type = "toggle", key = "totems", label = L["Totem timers"], help = L["Shows your totems and their time left beside the player frame."] })
		schema[#schema + 1] = Row(kind, { type = "dropdown", key = "totemPosition", label = L["Totem position"], options = CHOICES.totemPosition,
			help = L["Which side of the player frame the totems sit on."] }, function(s) return s.totems == true end)
		schema[#schema + 1] = Row(kind, { type = "slider", key = "totemSize", label = L["Totem size"], min = RANGES.totemSize[1], max = RANGES.totemSize[2], step = 1,
			help = L["The size of each totem icon in units."] }, function(s) return s.totems == true end)
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
	local function powerOn(s) return s.power ~= false end
	local function detached(s) return powerOn(s) and (s.powerDetach or "") ~= "" and Settings.Form(kind) ~= "slab" end
	for _, spec in ipairs({
		{ "toggle", "powerAbove", L["Above the health bar"], function(s) return powerOn(s) and (s.powerDetach or "") == "" and not NO_ABOVE[Settings.Form(kind)] end, L["Puts the power bar above the health bar, keeping the gap between them."] },
		{ "dropdown", "powerTextAlign", L["Text position"], powerOn, L["Where the text sits on the bar: left, centre or right."], CHOICES.align },
		{ "dropdown", "powerTextColor", L["Text colour"], powerOn, L["Keep the current style, or colour the power text by its power type or a custom colour."], CHOICES.powerTextColor },
		{ "color", "powerTextCustom", L["Custom text colour"], function(s) return powerOn(s) and s.powerTextColor == "custom" end, L["The text colour when its colour mode is custom."] },
		kind == "player" and { "toggle", "powerCost", L["Spell cost"], powerOn, L["While you cast, marks the power the spell will cost at the end of the fill."] },
		kind == "player" and { "color", "powerCostColor", L["Spell cost colour"], function(s) return powerOn(s) and s.powerCost == true end, L["The colour of the spell cost mark."] },
		kind == "player" and { "toggle", "manaSpark", L["Five-second rule"], powerOn, L["After you spend mana, a spark crosses the bar for the five seconds before regeneration resumes."] },
		kind == "player" and { "toggle", "powerMana", L["Mana in forms"], function(s) return powerOn(s) and K.Theme.Class() == "DRUID" end, L["Druids: shows mana in bear and cat form; the class resource bar shows the form's power."] },
		{ "dropdown", "powerDetach", L["Power bar place"], function(s) return powerOn(s) and Settings.Form(kind) ~= "slab" end, L["In the frame, or apart below or above its bars at its own width. The frame keeps its size."], CHOICES.powerDetach },
		{ "slider", "powerDetachWidth", L["Power bar width"], detached, L["The detached power bar's width. 0 matches the frame."] },
		{ "dropdown", "powerDetachStrata", L["Power bar strata"], detached, L["Which layer the detached power bar draws in."], CHOICES.strata },
	}) do
		if spec then
			local row = Row(kind, { type = spec[1], key = spec[2], label = spec[3], help = spec[5], options = spec[6] }, spec[4])
			if spec[2] == "powerDetachWidth" then row.min, row.max, row.step = 0, DETACH_WIDTH_MAX, 1 end
			schema[#schema + 1] = row
		end
	end
	Nudges(schema, kind, "powerDetach", L["Power bar"], detached)
	schema[#schema + 1] = Row(kind, { type = "toggle", key = "powerPercentSign", label = L["Percent sign"],
		help = L["Writes % after the power percentage. Off shows the number alone."] }, function(s) return s.power ~= false and (s.powerText == "percent" or s.powerText == "both" or s.powerText == "auto") end)
	schema[#schema + 1] = Header(kind, L["text"])
	for _, element in ipairs(Settings.TEXTS) do
		TextRows(schema, kind, element)
	end
	for i = 1, 2 do
		local key = "extra" .. i
		schema[#schema + 1] = Header(kind, L["Extra text"] .. " " .. i)
		K.Widgets.TextRows(schema, key, { outlines = CHOICES.outline, tags = true, placement = true, width = true,
			row = function(row) return Row(kind, row) end })
	end
	if Settings.TEXT_BAR[kind] then TextBarRows(schema, kind) end
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
			options = Options({ { "rows", L["Rows above frames"] }, { "fan", L["Crest fan"] } }) },
		{ type = "toggle", key = "castbarOnFrame", label = L["Cast bars on unit frames"],
			help = L["Puts each cast bar on its frame. Off restores both bars above the crest."] },
		{ type = "toggle", key = "castOutcomes", label = L["Readable cast outcomes"],
			help = L["Keeps failed casts readable and acknowledges channels. Off restores the original cast effects."] },
		{ type = "toggle", key = "castbarRaise", label = L["Cast bars above other frames"],
			help = L["Draws every unit frame cast bar above other frames so nothing covers it."] },
		{ type = "toggle", key = "healthDecimal", label = L["Health percent with a decimal"],
			help = L["Shows health percentages with one decimal place. Shortened health values already show one."] },
		{ type = "dropdown", key = "unitTooltip", label = L["Unit tooltips"], options = CHOICES.unitTooltip,
			help = L["When hovering a unit frame shows the unit's tooltip."] },
		{ type = "toggle", key = "healthDecimalBoss", label = L["Boss health percent with two decimals"],
			help = L["Shows boss frame health percentages with two decimal places, such as 41.27%."] },
		{ type = "toggle", key = "healthDecimalTrim", label = L["Hide trailing zeros"], help = L["Shows 41% rather than 41.0%, and 41.5% rather than 41.50%."],
			showWhen = function(s) return s.healthDecimal == true or s.healthDecimalBoss == true end },
		{ type = "toggle", key = "healthDecimalPercentOnly", label = L["Boss decimals on percentages only"], help = L["Off gives boss health values two decimals too, such as 240.55K."],
			showWhen = function(s) return s.healthDecimalBoss == true end },
		{ type = "toggle", key = "targetSounds", label = L["Target lost sound"],
			help = L["Plays the game's sound when you lose your target while KstyleUI hides Blizzard's target frame."] },
		{ type = "toggle", key = "reactionColors", label = L["Custom reaction colours"],
			help = L["Your own colours for hostile, neutral, friendly and tapped units on bars that follow reaction."] },
		{ type = "color", key = "hostileColor", label = L["Hostile colour"], help = L["The bar colour for these units while custom reaction colours are on."], showWhen = function(s) return s.reactionColors == true end },
		{ type = "color", key = "neutralColor", label = L["Neutral colour"], help = L["The bar colour for these units while custom reaction colours are on."], showWhen = function(s) return s.reactionColors == true end },
		{ type = "color", key = "friendlyColor", label = L["Friendly colour"], help = L["The bar colour for these units while custom reaction colours are on."], showWhen = function(s) return s.reactionColors == true end },
		{ type = "color", key = "tappedColor", label = L["Tapped colour"], help = L["The bar colour for these units while custom reaction colours are on."], showWhen = function(s) return s.reactionColors == true end },
		{ type = "toggle", key = "dispelCustom", label = L["Own dispel colours"],
			help = L["Colours the dispel overlay, edge and type icon and the aura dispel edges in the colours below."] },
		{ type = "color", key = "dispelMagic", label = L["Magic colour"], help = L["The colour of this debuff type."], showWhen = function(s) return s.dispelCustom == true end },
		{ type = "color", key = "dispelCurse", label = L["Curse colour"], help = L["The colour of this debuff type."], showWhen = function(s) return s.dispelCustom == true end },
		{ type = "color", key = "dispelPoison", label = L["Poison colour"], help = L["The colour of this debuff type."], showWhen = function(s) return s.dispelCustom == true end },
		{ type = "color", key = "dispelDisease", label = L["Disease colour"], help = L["The colour of this debuff type."], showWhen = function(s) return s.dispelCustom == true end },
		{ type = "color", key = "dispelBleed", label = L["Bleed colour"], help = L["The colour of this debuff type."], showWhen = function(s) return s.dispelCustom == true end },
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
