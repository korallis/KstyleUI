-- Tokens.lua: every colour, size, gap, duration and font, and the only file where a colour literal may appear.
local _, ns = ...

local Tokens = {}
ns.Tokens = Tokens

local MEDIA = "Interface\\AddOns\\KstyleUI\\Media\\"
local FONTS_DIR = MEDIA .. "Fonts\\"
local TEXTURES_DIR = MEDIA .. "Textures\\"

local COLORS = {
	materialFlat = { "13171b", 0.98 },
	materialSlate = { "171716", 0.98 },
	materialForged = { "101211", 1 },
	materialGold = { "af9865", 1 },
	materialFlatEdge = { "74808b", 0.20 },
	materialSlateEdge = { "746551", 0.38 },
	deep = { "0e1217", 0.75 },
	rim = { "d6eeff", 0.55 },
	rimSoft = { "d6eeff", 0.18 },
	giltLit = { "f3dca4", 1 },
	gilt = { "d3b574", 1 },
	capsGold = { "d3b574", 1 },
	chatSystem = { "efe06a", 1 },
	giltDim = { "8a6c34", 1 },
	muted = { "a9b6c2", 1 },
	dim = { "6f7d8a", 1 },
	friend = { "62d58d", 1 },
	magic = { "5aa9ff", 1 },
	quest = { "f6d27a", 1 },
	questGold = { "f2cf55", 1 },
	questDisc = { "2f6ed6", 1 },
	surface = { "0e1217", 0.75 },
	raised = { "1a2633", 0.85 },
	edgeOuter = { "000000", 0.55 },
	edgeInner = { "869094", 0.16 },
	socketEdge = { "000000", 0.94 },
	edgeFaint = { "d6eeff", 0.08 },
	edgeBar = { "d6eeff", 0.14 },
	buttonFill = { "0e1217", 0.5 },
	slotFill = { "050606", 1 },
	slotWell = { "151716", 1 },
	slotRim = { "78705c", 0.85 },
	slotPress = { "fff6da", 1 },
	slotEdge = { "fff4d6", 0.95 },
	slotNumber = { "fff3d0", 1 },
	text = { "c8d1da", 1 },
	textEmphasis = { "f2f5f8", 1 },
	textHover = { "ffffff", 1 },
	timerText = { "e3e7ec", 1 },
	textDisabled = { "6f7d8a", 1 },
	rare = { "4fc3ff", 1 },
	epic = { "b67cff", 1 },
	hostile = { "e2524f", 1 },
	healthHostile = { "e03b3f", 1 },
	neutral = { "e8c14f", 1 },
	friendly = { "62d58d", 1 },
	accentDefault = { "aad372", 1 },
	shadow = { "000000", 0.45 },
	textShadow = { "000000", 0.85 },
	track = { "05090e", 0.88 },
	barTrack = { "090a0a", 1 },
	barEdgeSoft = { "000000", 0.45 },
	barLoss = { "f1b98a", 0.85 },
	barLossLit = { "ffe9c9", 0.85 },
	healthLow = { "c5443e", 1 },
	barEdge = { "202327", 1 },
	powerEdge = { "12160a", 1 },
	castEdge = { "040502", 1 },
	white = { "ffffff", 1 },
	black = { "000000", 1 },
	schoolPhysical = { "d8c3a0", 1 },
	schoolHoly = { "ffe27a", 1 },
	schoolFire = { "ff8a3d", 1 },
	schoolNature = { "6fdc5a", 1 },
	schoolFrost = { "6fd6ff", 1 },
	schoolShadow = { "9d7bff", 1 },
	schoolArcane = { "e07bff", 1 },
	coinGold = { "f0c75e", 1 },
	coinSilver = { "c3ccd6", 1 },
	coinCopper = { "d68a5c", 1 },
	plateHostile = { "c3433d", 1 },
	hudPlayerHealth = { "2c69cc", 1 },
	hudTargetHealth = { "c5443e", 1 },
	hudMana = { "3d3dec", 1 },
	hudRested = { "5a9cca", 1 },
	orbHealth = { "c0302b", 1 },
	orbLoss = { "f2dcc0", 0.85 },
	meterPhysical = { "7a6a52", 1 },
	meterNature = { "2e7d4f", 1 },
	meterFire = { "b4501f", 1 },
	meterFrost = { "2f7396", 1 },
	meterShadow = { "5e4a8c", 1 },
	meterArcane = { "8a4f9e", 1 },
	meterHoly = { "94803a", 1 },
}

local SIZES = {
	radius = 14,
	radiusTile = 8,
	chamferPanel = 14,
	chamferTile = 8,
	chamferWindow = 14,
	shadow = 14,
	shadowOffset = 3,
	tick = 15,
	actionButton = 34,
	actionGap = 3,
	cooldownEssential = 40,
	cooldownUtility = 30,
	unitFrameWidth = 220,
	unitFrameHeight = 46,
	portrait = 46,
	buffBarWidth = 180,
	buffBarHeight = 18,
	display = 22,
	heading = 16,
	body = 12,
	prose = 12,
	title = 12,
	caps = 10,
	names = 10,
	unit = 18,
	caption = 11,
	number = 12,
	time = 12,
	timer = 11,
	world = 13,
	textShadowOffset = 1,
	pressOffset = 1,
	panelRise = 6,
	panelOvershoot = 2,
	gapTiny = 2,
	gapSmall = 4,
	gapMedium = 8,
	gapLarge = 12,
	gapHuge = 16,
	gapXLarge = 20,
	gapXXLarge = 28,
	railWidth = 318,
	railPadding = 20,
	sectionGap = 22,
	rowGap = 12,
	socketGap = 8,
	screenMargin = 17,
	rowHeight = 24,
	lootTile = 24,
	lootText = 14,
}

local SHARES = {}

local DURATIONS = {
	hover = 0.12,
	combatIn = 0.24,
	combatOut = 0.6,
	combatOutDelay = 3,
	panelOpen = 0.25,
	panelRise = 0.4,
	panelClose = 0.15,
	listStagger = 0.05,
	castSheen = 0.6,
	procPulse = 0.7,
	pressIn = 0.06,
	pressOut = 0.18,
	readyFlash = 0.3,
	fade = 0.2,
	lootHold = 6,
	hitFlash = 0.18,
	lossHold = 0.5,
	sparkHold = 0.25,
	sparkFade = 0.35,
}

local EASINGS = {
	hover = "outQuad",
	combatIn = "outCubic",
	combatOut = "inOutSine",
	panelOpen = "outSine",
	panelRise = "outBack",
	panelClose = "outQuad",
	fade = "outQuad",
}

local FONT_SETS = {
	{ key = "Folio", label = ns.L["Folio: classic serif"], path = FONTS_DIR .. "PTSerif-Regular.ttf" },
	{ key = "Lumen", label = ns.L["Lumen: original fonts"], path = FONTS_DIR .. "AlegreyaSansTabular-Regular.ttf" },
}
local FONT_FACES = {
	{ key = "CinzelSemiBold", label = "Cinzel SemiBold", path = FONTS_DIR .. "Cinzel-SemiBold.ttf" },
	{ key = "AlegreyaSansRegular", label = "Alegreya Sans", path = FONTS_DIR .. "AlegreyaSansTabular-Regular.ttf" },
	{ key = "AlegreyaSansMedium", label = "Alegreya Sans Medium", path = FONTS_DIR .. "AlegreyaSansTabular-Medium.ttf" },
	{ key = "AlegreyaSansBold", label = "Alegreya Sans Bold", path = FONTS_DIR .. "AlegreyaSansTabular-Bold.ttf" },
	{ key = "SourceSans3Semibold", label = "Source Sans 3 Semibold", path = FONTS_DIR .. "SourceSans3-Semibold.ttf" },
	{ key = "SourceSans3Regular", label = "Source Sans 3", path = FONTS_DIR .. "SourceSans3-Regular.ttf" },
	{ key = "InterSemiBold", label = "Inter SemiBold", path = FONTS_DIR .. "Inter-SemiBold.ttf" },
	{ key = "FolioDisplay", label = "IM Fell Double Pica SC", path = FONTS_DIR .. "FolioDisplay-Regular.ttf", tracking = 0 },
	{ key = "FolioCaps", label = "Folio Caps", path = FONTS_DIR .. "FolioCaps-SemiBold.ttf", tracking = 0.045, shadow = false },
	{ key = "FolioNames", label = "Cinzel Names SemiBold", path = FONTS_DIR .. "CinzelNames-SemiBold.ttf", tracking = 0, shadow = { x = 1, y = 1, alpha = 0.5 } },
	{ key = "FolioUnit", label = "Cinzel Unit SemiBold", path = FONTS_DIR .. "CinzelUnit-SemiBold.ttf", tracking = -0.064, shadow = { x = 1, y = 1, alpha = 0.5 } },
	{ key = "PTSerifRegular", label = "PT Serif", path = FONTS_DIR .. "PTSerif-Regular.ttf", tracking = 0 },
	{ key = "PTSerifBold", label = "PT Serif Bold", path = FONTS_DIR .. "PTSerif-Bold.ttf", tracking = 0 },
}
local ROLE_FACES = {
	{ key = "CinzelCaps", label = "Cinzel Caps Medium", path = FONTS_DIR .. "CinzelCaps-Medium.ttf", tracking = 0.065, shadow = false },
	{ key = "CinzelNames", label = "Cinzel Names Medium", path = FONTS_DIR .. "CinzelNames-Medium.ttf", tracking = 0, shadow = { x = 1, y = 1, alpha = 0.5 } },
	{ key = "CinzelUnit", label = "Cinzel Unit Medium", path = FONTS_DIR .. "CinzelUnit-Medium.ttf", tracking = -0.064, shadow = { x = 1, y = 1, alpha = 0.5 } },
	{ key = "AlegreyaSansProse", label = "Alegreya Sans Proportional", path = FONTS_DIR .. "AlegreyaSans-Regular.ttf", tracking = 0 },
	{ key = "AlegreyaSansExtraBold", label = "Alegreya Sans ExtraBold", path = FONTS_DIR .. "AlegreyaSansTabular-ExtraBold.ttf", tracking = 0 },
}
local FONT_LIST = {}
for _, list in ipairs({ FONT_FACES, ROLE_FACES }) do
	for _, face in ipairs(list) do
		FONT_LIST[#FONT_LIST + 1] = face
	end
end
local DEFAULT_FACE = "Folio"
local FALLBACK_FACE = "SourceSans3Semibold"
local NUMBER_FACE = "SourceSans3Semibold"
local MIN_TEXT = 10

local FONT_ROLES = {
	display = { folio = "FolioDisplay", lumen = "CinzelSemiBold", flags = "", tracking = 0.6 },
	heading = { folio = "FolioDisplay", lumen = "CinzelSemiBold", flags = "", tracking = 0.4 },
	body = { folio = "PTSerifRegular", lumen = "AlegreyaSansRegular", flags = "", tracking = 0 },
	prose = { folio = "PTSerifRegular", lumen = "AlegreyaSansProse", flags = "", tracking = 0 },
	title = { folio = "FolioCaps", lumen = "CinzelSemiBold", flags = "", tracking = 1.4, upper = true },
	caps = { folio = "FolioCaps", lumen = "CinzelCaps", flags = "", tracking = 0, upper = true },
	names = { folio = "FolioNames", lumen = "CinzelNames", flags = "", tracking = 0, upper = true },
	unit = { folio = "FolioUnit", lumen = "CinzelUnit", flags = "", tracking = 0, upper = true },
	caption = { folio = "PTSerifRegular", lumen = "AlegreyaSansMedium", flags = "", tracking = 0.6, upper = true },
	number = { folio = "PTSerifBold", lumen = "AlegreyaSansExtraBold", number = true, flags = "", tracking = 0 },
	time = { folio = "PTSerifBold", lumen = "AlegreyaSansBold", number = true, flags = "", tracking = 0 },
	timer = { folio = "PTSerifRegular", lumen = "AlegreyaSansMedium", number = true, flags = "", tracking = 0 },
	world = { folio = "PTSerifRegular", lumen = "AlegreyaSansMedium", flags = "OUTLINE", tracking = 0 },
}

local TYPE_SET_VALUES = {
	Folio = { chatSize = 12, chatSpacing = 6.5, noteSize = 10, tooltipTitle = "body", tooltipName = "names" },
	Lumen = { chatSize = 14, chatSpacing = 4.5, noteSize = 12, tooltipTitle = "heading", tooltipName = "heading" },
}

local ROLE_ORDER = { "display", "heading", "title", "caps", "names", "unit", "body", "prose", "caption", "number", "time", "timer", "world" }

local STATUSBARS = {
	{ key = "Glass", label = "Glass", path = TEXTURES_DIR .. "BarGlass.png" },
	{ key = "Soft", label = "Soft", path = TEXTURES_DIR .. "BarSoft.png" },
	{ key = "Flat", label = "Flat", path = TEXTURES_DIR .. "BarFlat.png" },
}

local TEXTURES = {
	materialSlate = { file = "Textures\\MaterialSlate.png" },
	materialForged = { file = "Textures\\MaterialForged.png" },
	forgedFrame1 = { file = "Textures\\ForgedFrame1.png", slice = 8, density = 4 },
	forgedFrame2 = { file = "Textures\\ForgedFrame2.png", slice = 16, density = 4 },
	forgedFrame3 = { file = "Textures\\ForgedFrame3.png", slice = 24, density = 4 },
	forgedBracket1 = { file = "Textures\\ForgedBracket1.png" },
	forgedBracket2 = { file = "Textures\\ForgedBracket2.png" },
	forgedBracket3 = { file = "Textures\\ForgedBracket3.png" },
	forgedDiamond = { file = "Textures\\ForgedDiamond.png" },
	forgedRule = { file = "Textures\\ForgedRule.png" },
	lumenShape = { file = "Textures\\LumenShape.png", slice = 56, density = 4 },
	cardShape = { file = "Textures\\CardShape.png", slice = 56, density = 4 },
	ringLine2 = { file = "Textures\\RingLine2.png", slice = 64, density = 4 },
	ringLine3 = { file = "Textures\\RingLine3.png", slice = 64, density = 4 },
	ringLine4 = { file = "Textures\\RingLine4.png", slice = 64, density = 4 },
	ringLine5 = { file = "Textures\\RingLine5.png", slice = 64, density = 4 },
	ringLine6 = { file = "Textures\\RingLine6.png", slice = 64, density = 4 },
	ringLine8 = { file = "Textures\\RingLine8.png", slice = 64, density = 4 },
	ringLine10 = { file = "Textures\\RingLine10.png", slice = 64, density = 4 },
	ringLine12 = { file = "Textures\\RingLine12.png", slice = 64, density = 4 },
	ringLine16 = { file = "Textures\\RingLine16.png", slice = 64, density = 4 },
	ringLine20 = { file = "Textures\\RingLine20.png", slice = 64, density = 4 },
	ringLine24 = { file = "Textures\\RingLine24.png", slice = 64, density = 4 },
	ringLine32 = { file = "Textures\\RingLine32.png", slice = 64, density = 4 },
	lumenOutline = { file = "Textures\\LumenOutline.png", slice = 32, density = 4 },
	chamferTile = { file = "Textures\\LumenShape.png", slice = 56, density = 4 },
	lumenShadow = { file = "Textures\\LumenShadow.png", slice = 56, density = 2 },
	diamond = { file = "Textures\\Diamond.png" },
	pillCapLeft = { file = "Textures\\PillCapLeft.png" },
	pillCapRight = { file = "Textures\\PillCapRight.png" },
	barSheen = { file = "Textures\\BarSheen.png" },
	lensMask = { file = "Textures\\LensMask.png" },
	ruleFade = { file = "Textures\\RuleFade.png" },
	iconMask = { file = "Textures\\SocketMask.png" },
	portraitMask = { file = "Textures\\PortraitMask.png" },
	shadow = { file = "Textures\\Shadow.png", slice = 24, density = 2 },
	glow = { file = "Textures\\Glow.png" },
	divider = { file = "Textures\\Divider.png" },
	noise = { file = "Textures\\Noise.png" },
	ring = { file = "Textures\\Ring.png" },
	ringBevel = { file = "Textures\\RingBevel.png" },
	barFlat = { file = "Textures\\BarFlat.png" },
	barSoft = { file = "Textures\\BarSoft.png" },
	barGlass = { file = "Textures\\BarGlass.png" },
	minimapMask = { file = "Textures\\MinimapMask.png" },
	dot = { file = "Textures\\Dot.png" },
	pill = { file = "Textures\\Pill.png" },
	glyphChevron = { file = "Textures\\GlyphChevron.png" },
	glyphClose = { file = "Textures\\GlyphClose.png" },
	orbRing = { file = "Textures\\OrbRing.png" },
	orbArm = { file = "Textures\\OrbArm.png" },
	orbCrest = { file = "Textures\\OrbCrest.png" },
	orbRail = { file = "Textures\\OrbRail.png" },
	orbRailBottom = { file = "Textures\\OrbRailBottom.png" },
	orbMask = { file = "Textures\\OrbMask.png" },
	orbBack = { file = "Textures\\OrbBack.png" },
	orbGlass = { file = "Textures\\OrbGlass.png" },
	orbLiquid = { file = "Textures\\OrbLiquid.png" },
	orbSurface = { file = "Textures\\OrbSurface.png" },
	hudStyleFrames = { file = "Textures\\HudStyleFrames.png" },
	hudStyleOrbs = { file = "Textures\\HudStyleOrbs.png" },
	logo = { file = "Logo\\Logo64.png" },
	logoLarge = { file = "Logo\\Logo256.png" },
}

local RGBA = {}
for name, spec in pairs(COLORS) do
	local hex = spec[1]
	RGBA[name] = {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
		spec[2],
	}
end

local function unknown(kind, name)
	error("KstyleUI.Tokens." .. kind .. ": unknown name " .. tostring(name), 3)
end

function Tokens.Color(name)
	if name == "accent" then
		local theme = ns.Theme
		if theme and theme.Accent then
			local r, g, b = theme.Accent()
			return r, g, b, 1
		end
		name = "accentDefault"
	end
	local c = RGBA[name]
	if not c then
		unknown("Color", name)
	end
	return c[1], c[2], c[3], c[4]
end

function Tokens.Size(name)
	local v = SIZES[name]
	if not v then
		unknown("Size", name)
	end
	return v
end

function Tokens.Share(name)
	local v = SHARES[name]
	if not v then
		unknown("Share", name)
	end
	return v
end

function Tokens.Duration(name)
	local v = DURATIONS[name]
	if not v then
		unknown("Duration", name)
	end
	return v
end

function Tokens.Easing(name)
	local v = EASINGS[name]
	if not v then
		unknown("Easing", name)
	end
	return v
end

local FACE_PATH = {}
local FACE_TRACKING = {}
local FACE_SHADOW = {}
for _, list in ipairs({ FONT_SETS, FONT_FACES, ROLE_FACES }) do
	for _, face in ipairs(list) do
		FACE_PATH[face.key] = face.path
		FACE_TRACKING[face.path] = face.tracking
		FACE_SHADOW[face.path] = face.shadow
	end
end

function Tokens.FontPath(key)
	return ns.Locale.Font(FACE_PATH[key])
end

function Tokens.IsFontSet(key)
	return key == "Folio" or key == "Lumen"
end

local function RoleChoice(role)
	local theme = ns.Theme
	local explicit = theme and theme.RoleFont and theme.RoleFont(role)
	if explicit and explicit ~= "" then
		return explicit
	end
end

function Tokens.FontRoles()
	local out = {}
	for i, role in ipairs(ROLE_ORDER) do
		out[i] = role
	end
	return out
end

function Tokens.Font(role)
	local spec = FONT_ROLES[role]
	if not spec then
		unknown("Font", role)
	end
	local theme = ns.Theme
	local key = RoleChoice(role)
	if not key then
		key = theme and theme.FontFace and theme.FontFace() or DEFAULT_FACE
		if key == "Folio" then
			key = spec.folio
		elseif key == "Lumen" then
			key = spec.lumen
		elseif spec.number then
			key = NUMBER_FACE
		end
	end
	local path = FACE_PATH[key]
	if not path and theme and theme.IsFontPath and theme.IsFontPath(key) then
		path = key
	end
	local size = SIZES[role]
	if role ~= "world" and theme and theme.FontScale then
		size = math.max(MIN_TEXT, size * theme.FontScale())
	end
	return ns.Locale.Font(path or FACE_PATH[FALLBACK_FACE]), size, spec.flags
end

function Tokens.FaceTracking(path)
	return FACE_TRACKING[path] or 0
end

function Tokens.FaceShadow(path)
	local shadow = FACE_SHADOW[path]
	if shadow == nil then
		return true
	end
	return shadow
end

function Tokens.TextStyle(role)
	local spec = FONT_ROLES[role]
	if not spec then
		unknown("TextStyle", role)
	end
	local theme = ns.Theme
	local key = RoleChoice(role) and "" or theme and theme.FontFace and theme.FontFace() or DEFAULT_FACE
	return key == "Lumen" and spec.tracking or 0, spec.upper == true
end

function Tokens.TypeDefault(name)
	local theme = ns.Theme
	local set = TYPE_SET_VALUES[theme and theme.TypeSet and theme.TypeSet() or DEFAULT_FACE]
	local value = set and set[name]
	if not value then
		unknown("TypeDefault", name)
	end
	return value
end

function Tokens.NoteFont()
	local path, _, flags = Tokens.Font("body")
	local size = Tokens.TypeDefault("noteSize")
	local theme = ns.Theme
	if theme and theme.FontScale then
		size = math.max(MIN_TEXT, size * theme.FontScale())
	end
	return path, size, flags
end

function Tokens.RoleFontPaths()
	local out = {}
	for i, face in ipairs(ROLE_FACES) do
		out[i] = ns.Locale.Font(face.path)
	end
	return out
end

function Tokens.MediaList(kind)
	local source = (kind == "font" and FONT_LIST) or (kind == "fontSet" and FONT_SETS) or (kind == "statusbar" and STATUSBARS)
	if not source then
		unknown("MediaList", kind)
	end
	local out = {}
	for i, item in ipairs(source) do
		out[i] = { key = item.key, label = item.label, path = source == STATUSBARS and item.path or ns.Locale.Font(item.path) }
	end
	return out
end

function Tokens.Texture(name)
	local spec = TEXTURES[name]
	if not spec then
		unknown("Texture", name)
	end
	local units = spec.slice and spec.slice / spec.density
	return MEDIA .. spec.file, spec.slice, units
end

Tokens.DEFAULT_FONT_FACE = DEFAULT_FACE

local MATERIALS = {
	Glass = {},
	Flat = { fill = "materialFlat", edge = "materialFlatEdge" },
	Slate = { fill = "materialSlate", edge = "materialSlateEdge", texture = "materialSlate", texels = 256, grain = 0.12 },
	ForgedTicks = { fill = "materialForged", texture = "materialForged", texels = 256, grain = 0.055, frame = true, gem = "forgedDiamond", rule = "forgedRule" },
	ForgedBrackets = { fill = "materialForged", texture = "materialForged", texels = 256, grain = 0.055, frame = true, brackets = true, gem = "forgedDiamond", rule = "forgedRule" },
}

function Tokens.Material(name)
	return MATERIALS[name]
end
