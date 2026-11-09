-- Tokens.lua: every colour, size, gap, duration and font, and the only file where a colour literal may appear.
local _, ns = ...

local Tokens = {}
ns.Tokens = Tokens

local MEDIA = "Interface\\AddOns\\KstyleUI\\Media\\"
local FONTS_DIR = MEDIA .. "Fonts\\"
local TEXTURES_DIR = MEDIA .. "Textures\\"

local COLORS = {
	glass = { "e1f0fa", 0.22 },
	deep = { "0c141e", 0.62 },
	rim = { "d6eeff", 0.55 },
	rimSoft = { "d6eeff", 0.18 },
	giltLit = { "f3dca4", 1 },
	gilt = { "d9b46a", 1 },
	giltDim = { "8a6c34", 1 },
	muted = { "a9b6c2", 1 },
	dim = { "6f7d8a", 1 },
	friend = { "62d58d", 1 },
	magic = { "5aa9ff", 1 },
	quest = { "f6d27a", 1 },
	surface = { "0c141e", 0.62 },
	raised = { "1a2633", 0.85 },
	edgeOuter = { "000000", 0.5 },
	edgeInner = { "d6eeff", 0.55 },
	edgeFaint = { "d6eeff", 0.08 },
	edgeBar = { "d6eeff", 0.14 },
	buttonFill = { "0a1018", 0.7 },
	text = { "a9b6c2", 1 },
	textEmphasis = { "f2f5f8", 1 },
	textHover = { "ffffff", 1 },
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
	track = { "05090e", 0.7 },
	white = { "ffffff", 1 },
	black = { "000000", 1 },
	schoolPhysical = { "d8c3a0", 1 },
	schoolHoly = { "ffe27a", 1 },
	schoolFire = { "ff8a3d", 1 },
	schoolNature = { "6fdc5a", 1 },
	schoolFrost = { "6fd6ff", 1 },
	schoolShadow = { "9d7bff", 1 },
	schoolArcane = { "e07bff", 1 },
}

local SIZES = {
	radius = 14,
	radiusTile = 8,
	chamferPanel = 14,
	chamferTile = 8,
	chamferWindow = 14,
	shadow = 14,
	shadowOffset = 3,
	gilt = 20,
	gem = 16,
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
	caption = 9,
	number = 12,
	world = 13,
	textShadowOffset = 0.6,
	pressOffset = 1,
	panelRise = 16,
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
	screenMargin = 28,
	rowHeight = 24,
}

local SHARES = {
	radiusSocket = 11 / 52,
}

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
	fade = 0.2,
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
	{ key = "Lumen", label = "Lumen: Cinzel and Alegreya Sans", path = FONTS_DIR .. "AlegreyaSansTabular-Regular.ttf" },
}
local FONT_FACES = {
	{ key = "CinzelSemiBold", label = "Cinzel SemiBold", path = FONTS_DIR .. "Cinzel-SemiBold.ttf" },
	{ key = "AlegreyaSansRegular", label = "Alegreya Sans", path = FONTS_DIR .. "AlegreyaSansTabular-Regular.ttf" },
	{ key = "AlegreyaSansMedium", label = "Alegreya Sans Medium", path = FONTS_DIR .. "AlegreyaSansTabular-Medium.ttf" },
	{ key = "AlegreyaSansBold", label = "Alegreya Sans Bold", path = FONTS_DIR .. "AlegreyaSansTabular-Bold.ttf" },
	{ key = "SourceSans3Semibold", label = "Source Sans 3 Semibold", path = FONTS_DIR .. "SourceSans3-Semibold.ttf" },
	{ key = "SourceSans3Regular", label = "Source Sans 3", path = FONTS_DIR .. "SourceSans3-Regular.ttf" },
	{ key = "InterSemiBold", label = "Inter SemiBold", path = FONTS_DIR .. "Inter-SemiBold.ttf" },
}
local DEFAULT_FACE = "Lumen"
local FALLBACK_FACE = "SourceSans3Semibold"
local NUMBER_FACE = "SourceSans3Semibold"

local FONT_ROLES = {
	display = { lumen = "CinzelSemiBold", flags = "", tracking = 0.6 },
	heading = { lumen = "CinzelSemiBold", flags = "", tracking = 0.4 },
	body = { lumen = "AlegreyaSansRegular", flags = "", tracking = 0 },
	caption = { lumen = "CinzelSemiBold", flags = "", tracking = 1.4, upper = true },
	number = { lumen = "AlegreyaSansBold", number = true, flags = "", tracking = 0 },
	world = { lumen = "AlegreyaSansMedium", flags = "OUTLINE", tracking = 0 },
}

local STATUSBARS = {
	{ key = "Glass", label = "Glass", path = TEXTURES_DIR .. "BarGlass.png" },
	{ key = "Soft", label = "Soft", path = TEXTURES_DIR .. "BarSoft.png" },
	{ key = "Flat", label = "Flat", path = TEXTURES_DIR .. "BarFlat.png" },
}

local TEXTURES = {
	lumenShape = { file = "Textures\\LumenShape.png", slice = 56, density = 4 },
	lumenFrost = { file = "Textures\\LumenFrost.png", slice = 56, density = 4 },
	lumenRim = { file = "Textures\\LumenRim.png", slice = 56, density = 4 },
	lumenRimSmall = { file = "Textures\\LumenRimSmall.png", slice = 32, density = 4 },
	lumenOutline = { file = "Textures\\LumenOutline.png", slice = 32, density = 4 },
	chamferTile = { file = "Textures\\LumenShape.png", slice = 56, density = 4 },
	lumenShadow = { file = "Textures\\LumenShadow.png", slice = 56, density = 2 },
	gilt = { file = "Textures\\LumenGilt.png" },
	gem = { file = "Textures\\LumenGem.png" },
	pillCapLeft = { file = "Textures\\PillCapLeft.png" },
	pillCapRight = { file = "Textures\\PillCapRight.png" },
	barSheen = { file = "Textures\\BarSheen.png" },
	lensMask = { file = "Textures\\LensMask.png" },
	ruleFade = { file = "Textures\\RuleFade.png" },
	iconMask = { file = "Textures\\SocketMask.png" },
	portraitMask = { file = "Textures\\SocketMask.png" },
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
for _, list in ipairs({ FONT_SETS, FONT_FACES }) do
	for _, face in ipairs(list) do
		FACE_PATH[face.key] = face.path
	end
end

function Tokens.FontPath(key)
	return FACE_PATH[key]
end

function Tokens.Font(role)
	local spec = FONT_ROLES[role]
	if not spec then
		unknown("Font", role)
	end
	local theme = ns.Theme
	local key = theme and theme.FontFace and theme.FontFace() or DEFAULT_FACE
	if key == DEFAULT_FACE then
		key = spec.lumen
	elseif spec.number then
		key = NUMBER_FACE
	end
	local path = FACE_PATH[key]
	if not path and theme and theme.IsFontPath and theme.IsFontPath(key) then
		path = key
	end
	local size = SIZES[role]
	if role ~= "world" and theme and theme.FontScale then
		size = size * theme.FontScale()
	end
	return path or FACE_PATH[FALLBACK_FACE], size, spec.flags
end

function Tokens.TextStyle(role)
	local spec = FONT_ROLES[role]
	if not spec then
		unknown("TextStyle", role)
	end
	return spec.tracking, spec.upper == true
end

function Tokens.MediaList(kind)
	local source = (kind == "font" and FONT_FACES) or (kind == "fontSet" and FONT_SETS) or (kind == "statusbar" and STATUSBARS)
	if not source then
		unknown("MediaList", kind)
	end
	local out = {}
	for i, item in ipairs(source) do
		out[i] = { key = item.key, label = item.label, path = item.path }
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
