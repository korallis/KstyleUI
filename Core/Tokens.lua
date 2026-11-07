-- Tokens.lua: every colour, size, gap, duration and font, and the only file where a colour literal may appear.
local _, ns = ...

local Tokens = {}
ns.Tokens = Tokens

local MEDIA = "Interface\\AddOns\\KstyleUI\\Media\\"
local FONTS_DIR = MEDIA .. "Fonts\\"
local TEXTURES_DIR = MEDIA .. "Textures\\"

local COLORS = {
	surface = { "101010", 0.88 },
	raised = { "1c1c1c", 1 },
	edgeOuter = { "000000", 0.6 },
	edgeInner = { "ffffff", 0.28 },
	edgeFaint = { "ffffff", 0.08 },
	text = { "ababab", 1 },
	textEmphasis = { "ebebeb", 1 },
	textHover = { "ffffff", 1 },
	textDisabled = { "666666", 1 },
	rare = { "4fc3ff", 1 },
	epic = { "b67cff", 1 },
	hostile = { "e5534b", 1 },
	neutral = { "e8c14f", 1 },
	friendly = { "5fcf72", 1 },
	accentDefault = { "aad372", 1 },
	shadow = { "000000", 0.55 },
	textShadow = { "000000", 0.8 },
	track = { "000000", 0.45 },
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
	chamferPanel = 6,
	chamferTile = 3,
	shadow = 12,
	actionButton = 34,
	actionGap = 3,
	cooldownEssential = 40,
	cooldownUtility = 30,
	unitFrameWidth = 220,
	unitFrameHeight = 46,
	portrait = 46,
	buffBarWidth = 180,
	buffBarHeight = 18,
	display = 24,
	heading = 16,
	body = 11,
	caption = 9,
	number = 11,
	world = 12,
	textShadowOffset = 0.6,
	pressOffset = 1,
	panelRise = 16,
	panelOvershoot = 2,
	gapTiny = 2,
	gapSmall = 4,
	gapMedium = 8,
	gapLarge = 12,
	gapHuge = 16,
	panelPadding = 16,
	rowHeight = 24,
}

local DURATIONS = {
	hover = 0.15,
	panelOpen = 0.25,
	panelRise = 0.4,
	panelClose = 0.15,
	listStagger = 0.05,
	castSheen = 0.6,
	procPulse = 1.2,
	fade = 0.2,
}

local EASINGS = {
	hover = "outQuart",
	panelOpen = "outSine",
	panelRise = "outBack",
	panelClose = "outQuad",
	fade = "outQuad",
}

local FONT_FACES = {
	{ key = "SourceSans3Semibold", label = "Source Sans 3 Semibold", path = FONTS_DIR .. "SourceSans3-Semibold.ttf" },
	{ key = "SourceSans3Regular", label = "Source Sans 3", path = FONTS_DIR .. "SourceSans3-Regular.ttf" },
	{ key = "InterSemiBold", label = "Inter SemiBold", path = FONTS_DIR .. "Inter-SemiBold.ttf" },
}
local DEFAULT_FACE = "SourceSans3Semibold"
local NUMBER_FACE = "SourceSans3Semibold"

local FONT_ROLES = {
	display = { face = "ui", flags = "", tracking = -0.5 },
	heading = { face = "ui", flags = "", tracking = -0.3 },
	body = { face = "ui", flags = "", tracking = 0 },
	caption = { face = "ui", flags = "", tracking = 1.5, upper = true },
	number = { face = "number", flags = "", tracking = 0 },
	world = { face = "ui", flags = "OUTLINE", tracking = 0 },
}

local STATUSBARS = {
	{ key = "Glass", label = "Glass", path = TEXTURES_DIR .. "BarGlass.png" },
	{ key = "Soft", label = "Soft", path = TEXTURES_DIR .. "BarSoft.png" },
	{ key = "Flat", label = "Flat", path = TEXTURES_DIR .. "BarFlat.png" },
}

local TEXTURES = {
	chamferPanel = { file = "Textures\\ChamferPanel.png", slice = 24, density = 4 },
	chamferTile = { file = "Textures\\ChamferTile.png", slice = 12, density = 4 },
	bevelPanelOuter = { file = "Textures\\BevelPanelOuter.png", slice = 28, density = 4 },
	bevelPanelInner = { file = "Textures\\BevelPanelInner.png", slice = 28, density = 4 },
	bevelTileOuter = { file = "Textures\\BevelTileOuter.png", slice = 16, density = 4 },
	bevelTileInner = { file = "Textures\\BevelTileInner.png", slice = 16, density = 4 },
	bevelPanelHairline = { file = "Textures\\BevelPanelHairline.png", slice = 32, density = 4 },
	bevelTileHairline = { file = "Textures\\BevelTileHairline.png", slice = 20, density = 4 },
	iconMask = { file = "Textures\\ChamferIconMask.png" },
	shadow = { file = "Textures\\Shadow.png", slice = 48, density = 2 },
	glow = { file = "Textures\\Glow.png" },
	divider = { file = "Textures\\Divider.png" },
	noise = { file = "Textures\\Noise.png" },
	ring = { file = "Textures\\Ring.png" },
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
for _, face in ipairs(FONT_FACES) do
	FACE_PATH[face.key] = face.path
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
	local key = NUMBER_FACE
	if spec.face == "ui" then
		key = theme and theme.FontFace and theme.FontFace() or DEFAULT_FACE
	end
	local path = FACE_PATH[key]
	if not path and theme and theme.IsFontPath and theme.IsFontPath(key) then
		path = key
	end
	local size = SIZES[role]
	if role ~= "world" and theme and theme.FontScale then
		size = size * theme.FontScale()
	end
	return path or FACE_PATH[DEFAULT_FACE], size, spec.flags
end

function Tokens.TextStyle(role)
	local spec = FONT_ROLES[role]
	if not spec then
		unknown("TextStyle", role)
	end
	return spec.tracking, spec.upper == true
end

function Tokens.MediaList(kind)
	local source = (kind == "font" and FONT_FACES) or (kind == "statusbar" and STATUSBARS)
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
