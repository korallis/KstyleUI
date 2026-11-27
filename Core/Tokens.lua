-- Tokens.lua: every colour, size, gap, duration and font, and the only file where a colour literal may appear.
local _, ns = ...

local Tokens = {}
ns.Tokens = Tokens
Tokens.MEDALLIONS_PLATE_NAME_FACE = "InterSemiBold"

local MEDIA = "Interface\\AddOns\\KstyleUI\\Media\\"
local FONTS_DIR = MEDIA .. "Fonts\\"
local TEXTURES_DIR = MEDIA .. "Textures\\"

local COLORS = {
	visionRGCalm = { "0072b2", 1 },
	visionRGDanger = { "d55e00", 1 },
	visionRGWarning = { "f0e442", 1 },
	visionBYCalm = { "009e73", 1 },
	visionBYDanger = { "cc79a7", 1 },
	visionBYWarning = { "e69f00", 1 },
	materialFlat = { "13171b", 0.98 },
	materialSlate = { "171716", 0.98 },
	materialForged = { "101211", 1 },
	materialGold = { "af9865", 1 },
	materialFlatEdge = { "74808b", 0.20 },
	materialSlateEdge = { "746551", 0.38 },
	steel = { "b9c1cc", 1 },
	steelLit = { "e6ecf3", 1 },
	steelDim = { "6b7380", 1 },
	steelFill = { "0f1318", 0.96 },
	steelEdge = { "9ca6b4", 0.52 },
	slabTop = { "15171c", 1 },
	slabBottom = { "0a0b0e", 1 },
	slabInner = { "000000", 0.85 },
	labelMuted = { "8f98a4", 1 },
	nameHostile = { "ff8a7a", 1 },
	medDead = { "4a4f57", 1 },
	plaqueFill = { "16181c", 1 },
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
	slotEdge = { "f3dca4", 0.6 },
	slotEdgeLegacy = { "fff4d6", 0.95 },
	slotNumber = { "fff3d0", 1 },
	text = { "c8d1da", 1 },
	textEmphasis = { "f2f5f8", 1 },
	textHover = { "ffffff", 1 },
	timerText = { "e3e7ec", 1 },
	timerExpiring = { "ff7060", 1 },
	textDisabled = { "6f7d8a", 1 },
	rare = { "4fc3ff", 1 },
	epic = { "b67cff", 1 },
	uncommon = { "6fdc5a", 1 },
	poor = { "8f98a4", 1 },
	common = { "c8d1da", 1 },
	legendary = { "ff9d3d", 1 },
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
	barLoss = { "ffffff", 0.32 },
	barLossLit = { "ffffff", 0.45 },
	healthLow = { "c5443e", 1 },
	dangerBody = { "3a0a0c", 1 },
	healthLowText = { "ffb3a7", 1 },
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
	hudMana = { "2a3fa8", 1 },
	hudRested = { "5a9cca", 1 },
	meterPhysical = { "7a6a52", 1 },
	meterNature = { "2e7d4f", 1 },
	meterFire = { "b4501f", 1 },
	meterFrost = { "2f7396", 1 },
	meterShadow = { "5e4a8c", 1 },
	meterArcane = { "8a4f9e", 1 },
	meterHoly = { "94803a", 1 },
	medOutline = { "000000", 1 },
	medRimLit = { "2c2f34", 1 },
	medRimLow = { "15171a", 1 },
	medTopLine = { "3a3e44", 0.6 },
	medFillTop = { "121417", 1 },
	medFillBottom = { "07080a", 1 },
	medSocketRim = { "1e2024", 1 },
	medSocketTop = { "020203", 1 },
	medSocket = { "0a0b0d", 1 },
	medSocketLip = { "33363b", 0.67 },
	jewelCombo = { "ff5a3c", 1 },
	jewelComboRim = { "8a2414", 1 },
	jewelComboCore = { "ffd2a0", 1 },
	jewelHoly = { "f2c14e", 1 },
	jewelHolyRim = { "7d5a12", 1 },
	jewelHolyCore = { "fff4c2", 1 },
	jewelShard = { "a46bff", 1 },
	jewelShardCore = { "e6d4ff", 1 },
	pipDruidGlow = { "ffa62e", 1 },
	pipDruidCore = { "fff0b8", 1 },
	pipWarriorGlow = { "ff7a2e", 1 },
	pipPriestGlow = { "ffd36e", 1 },
	pipMageGlow = { "8f6bff", 1 },
	pipBearGlow = { "ff5a2a", 1 },
	pipStormGlow = { "5fb4ff", 1 },
	jewelSetting = { "7a5a2b", 1 },
	jewelSocket = { "4a505a", 1 },
	jewelHawk = { "aad372", 1 },
	jewelHawkCore = { "f1ffd9", 1 },
	totemEarth = { "8cc152", 1 },
	totemFire = { "ff8a3d", 1 },
	totemWater = { "4aa8ff", 1 },
	totemAir = { "b79cff", 1 },
	totemCore = { "fff4dc", 1 },
	totemSpirit = { "8fd8ff", 1 },
	mantleTravel = { "2ec4b6", 1 },
	jewelStormCore = { "e3f3ff", 1 },
	medGunLit = { "50555d", 1 },
	medGunDark = { "0e0f12", 1 },
	medGunHair = { "6b7380", 0.4 },
	medCardFill = { "0c0d10", 0.94 },
	medChatFill = { "0c0d10", 0.8 },
	medCardHeaderTop = { "17191d", 1 },
	medCardHeaderBottom = { "101215", 1 },
	medCardDivider = { "2c2f34", 1 },
	medText = { "e8ebef", 1 },
	medTextMuted = { "8f98a4", 1 },
}

local SIZES = {
	plateNameSize = 16,
	medallionsPlateNameSize = 11,
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
	barHeight = 12,
	lootTile = 24,
	lootText = 14,
}

local SHARES = { rowHover = 0.05 }

local DURATIONS = {
	dangerBreath = 0.8,
	hover = 0.12,
	combatIn = 0.24,
	combatOut = 0.6,
	combatOutDelay = 3,
	panelOpen = 0.25,
	panelRise = 0.4,
	panelClose = 0.15,
	listStagger = 0.05,
	castSheen = 0.6,
	castFlash = 0.22,
	castErrorHold = 0.9,
	procPulse = 0.7,
	glowBreath = 0.6,
	procIn = 0.18,
	procOut = 0.15,
	hoverGrace = 0.3,
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

Tokens.Smoothing = { enter = "OUT", exit = "IN", loop = "IN_OUT" }
Tokens.Flicker = { low = 0.6, step = 0.25 }

local EASINGS = {
	enter = "outCubic",
	exit = "inQuad",
	move = "inOutSine",
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
	{ key = "Lumen", label = ns.L["Original: Cinzel and Alegreya Sans"], path = FONTS_DIR .. "AlegreyaSansTabular-Regular.ttf" },
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
	{ key = "FolioNames", label = "Cinzel Names SemiBold", path = FONTS_DIR .. "CinzelNames-SemiBold.ttf", tracking = 0, shadow = { x = 1, y = 1, alpha = 0.85 } },
	{ key = "FolioUnit", label = "Cinzel Unit SemiBold", path = FONTS_DIR .. "CinzelUnit-SemiBold.ttf", tracking = -0.064, shadow = { x = 1, y = 1, alpha = 0.85 } },
	{ key = "PTSerifRegular", label = "PT Serif", path = FONTS_DIR .. "PTSerif-Regular.ttf", tracking = 0 },
	{ key = "PTSerifBold", label = "PT Serif Bold", path = FONTS_DIR .. "PTSerif-Bold.ttf", tracking = 0 },
	{ key = "BarlowSemiBold", label = "Barlow Semi Condensed SemiBold", path = FONTS_DIR .. "BarlowSemiCondensedTabular-SemiBold.ttf", tracking = 0 },
	{ key = "BarlowBold", label = "Barlow Semi Condensed Bold", path = FONTS_DIR .. "BarlowSemiCondensedTabular-Bold.ttf", tracking = 0 },
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
	Folio = { chatSize = 12, chatSpacing = 6.5, noteSize = 10, tooltipTitle = "heading", tooltipLegacyTitle = "body", tooltipName = "names" },
	Lumen = { chatSize = 14, chatSpacing = 4.5, noteSize = 12, tooltipTitle = "heading", tooltipLegacyTitle = "heading", tooltipName = "heading" },
}

local ROLE_ORDER = { "display", "heading", "title", "caps", "names", "unit", "body", "prose", "caption", "number", "time", "timer", "world" }

local STATUSBARS = {
	{ key = "Flat", label = "Flat", path = TEXTURES_DIR .. "BarFlat.png" },
	{ key = "Glass", label = "Glass", path = TEXTURES_DIR .. "BarGlass.png" },
	{ key = "Soft", label = "Soft", path = TEXTURES_DIR .. "BarSoft.png" },
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
	hawkSigil = { file = "Textures\\Medallions\\Hawks\\HawkSigil.png" },
	stormOrb = { file = "Textures\\Medallions\\Storm\\StormOrb.png" },
	stormOrbSpark = { file = "Textures\\Medallions\\Storm\\StormOrbSpark.png" },
	stormBolt = { file = "Textures\\Medallions\\Storm\\StormBolt.png" },
	trackerWisp = { file = "Textures\\Medallions\\Trackers\\SoulWisp.png" },
	trackerGust = { file = "Textures\\Medallions\\Trackers\\Gust.png" },
	trackerFlame = { file = "Textures\\Medallions\\Trackers\\Flame.png" },
	trackerLeaf = { file = "Textures\\Medallions\\Trackers\\Leaf.png" },
	trackerRune = { file = "Textures\\Medallions\\Trackers\\Rune.png" },
	trackerStone = { file = "Textures\\Medallions\\Trackers\\Stone.png" },
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
	orbMask = { file = "Textures\\OrbMask.png" },
	hudStyleFrames = { file = "Textures\\HudStyleFrames.tga" },
	dispelM = { file = "Textures\\Accessibility\\DispelM.png" },
	dispelC = { file = "Textures\\Accessibility\\DispelC.png" },
	dispelD = { file = "Textures\\Accessibility\\DispelD.png" },
	dispelP = { file = "Textures\\Accessibility\\DispelP.png" },
	dispelE = { file = "Textures\\Accessibility\\DispelE.png" },
	medActionSlab = { file = "Textures\\Medallions\\ActionSlab.png", slice = 16, density = 2 },
	medAmbientDruid = { file = "Textures\\Medallions\\AmbientDruid.png", rows = 4, columns = 4, frames = 16, seconds = 1.44 },
	medAmbientHunter = { file = "Textures\\Medallions\\AmbientHunter.png", rows = 4, columns = 4, frames = 16, seconds = 1.44 },
	medAmbientMage = { file = "Textures\\Medallions\\AmbientMage.png", rows = 4, columns = 4, frames = 16, seconds = 1.44 },
	medAmbientPaladin = { file = "Textures\\Medallions\\AmbientPaladin.png", rows = 4, columns = 4, frames = 16, seconds = 1.44 },
	medAmbientPriest = { file = "Textures\\Medallions\\AmbientPriest.png", rows = 4, columns = 4, frames = 16, seconds = 1.44 },
	medAmbientRogue = { file = "Textures\\Medallions\\AmbientRogue.png", rows = 4, columns = 4, frames = 16, seconds = 1.44 },
	medAmbientShaman = { file = "Textures\\Medallions\\AmbientShaman.png", rows = 4, columns = 4, frames = 16, seconds = 1.44 },
	medAmbientWarlock = { file = "Textures\\Medallions\\AmbientWarlock.png", rows = 4, columns = 4, frames = 16, seconds = 1.44 },
	medAmbientWarrior = { file = "Textures\\Medallions\\AmbientWarrior.png", rows = 4, columns = 4, frames = 16, seconds = 1.44 },
	procAura = { file = "Textures\\Medallions\\Auras\\ProcAura.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 },
	medAuraBorder = { file = "Textures\\Medallions\\AuraBorder.png", slice = 8, density = 2 },
	medBarFill = { file = "Textures\\Medallions\\BarFill.png" },
	medBarSpark = { file = "Textures\\Medallions\\BarSpark.png" },
	medBarTrack = { file = "Textures\\Medallions\\BarTrack.png" },
	medBurstDruid = { file = "Textures\\Medallions\\BurstDruid.png" },
	medBurstHunter = { file = "Textures\\Medallions\\BurstHunter.png" },
	medBurstMage = { file = "Textures\\Medallions\\BurstMage.png" },
	medBurstPaladin = { file = "Textures\\Medallions\\BurstPaladin.png" },
	medBurstPriest = { file = "Textures\\Medallions\\BurstPriest.png" },
	medBurstRogue = { file = "Textures\\Medallions\\BurstRogue.png" },
	medBurstShaman = { file = "Textures\\Medallions\\BurstShaman.png" },
	medBurstWarlock = { file = "Textures\\Medallions\\BurstWarlock.png" },
	medBurstWarrior = { file = "Textures\\Medallions\\BurstWarrior.png" },
	medCardEdge = { file = "Textures\\Medallions\\CardEdge.png", slice = 16, density = 2 },
	medCastShield = { file = "Textures\\Medallions\\CastShield.png" },
	medCastShieldGlyph = { file = "Textures\\Medallions\\CastShieldGlyph.png" },
	medCombatSweep = { file = "Textures\\Medallions\\CombatSweep.png" },
	medEnamel = { file = "Textures\\Medallions\\Enamel128.png" },
	medEnamelLarge = { file = "Textures\\Medallions\\Enamel256.png" },
	medGroupTargetRing = { file = "Textures\\Medallions\\GroupTargetRing.png", slice = 8, density = 2 },
	medGroupTile = { file = "Textures\\Medallions\\GroupTile.png", slice = 8, density = 2 },
	medHubSocket = { file = "Textures\\Medallions\\HubSocket.png" },
	medHubWing = { file = "Textures\\Medallions\\HubWing.png" },
	medLevelPlaque = { file = "Textures\\Medallions\\LevelPlaque.png" },
	medLevelUp = { file = "Textures\\Medallions\\LevelUp.png", rows = 4, columns = 4, frames = 16, seconds = 1.2 },
	medLowHealthRing = { file = "Textures\\Medallions\\LowHealthRing.png" },
	dangerAnnulus = { file = "Textures\\Danger\\Annulus.png" },
	dangerRim = { file = "Textures\\Danger\\Rim.png" },
	dangerEdge = { file = "Textures\\Danger\\Edge.png" },
	medMinimapMask = { file = "Textures\\Medallions\\MapMask.png" },
	medMinimapRing = { file = "Textures\\Medallions\\MinimapRing.png" },
	medParticleDruid = { file = "Textures\\Medallions\\ParticleDruid.png", rows = 2, columns = 2, frames = 4 },
	medParticleHunter = { file = "Textures\\Medallions\\ParticleHunter.png", rows = 2, columns = 2, frames = 4 },
	medParticleMage = { file = "Textures\\Medallions\\ParticleMage.png", rows = 2, columns = 2, frames = 4 },
	medParticlePaladin = { file = "Textures\\Medallions\\ParticlePaladin.png", rows = 2, columns = 2, frames = 4 },
	medParticlePriest = { file = "Textures\\Medallions\\ParticlePriest.png", rows = 2, columns = 2, frames = 4 },
	medParticleRogue = { file = "Textures\\Medallions\\ParticleRogue.png", rows = 2, columns = 2, frames = 4 },
	medParticleShaman = { file = "Textures\\Medallions\\ParticleShaman.png", rows = 2, columns = 2, frames = 4 },
	medParticleWarlock = { file = "Textures\\Medallions\\ParticleWarlock.png", rows = 2, columns = 2, frames = 4 },
	medParticleWarrior = { file = "Textures\\Medallions\\ParticleWarrior.png", rows = 2, columns = 2, frames = 4 },
	medPortraitSheen = { file = "Textures\\Medallions\\PortraitSheen.png" },
	medProcDruid = { file = "Textures\\Medallions\\ProcDruid.png", rows = 4, columns = 4, frames = 16, seconds = 0.96 },
	medProcHunter = { file = "Textures\\Medallions\\ProcHunter.png", rows = 4, columns = 4, frames = 16, seconds = 0.96 },
	medProcMage = { file = "Textures\\Medallions\\ProcMage.png", rows = 4, columns = 4, frames = 16, seconds = 0.96 },
	medProcPaladin = { file = "Textures\\Medallions\\ProcPaladin.png", rows = 4, columns = 4, frames = 16, seconds = 0.96 },
	medProcPriest = { file = "Textures\\Medallions\\ProcPriest.png", rows = 4, columns = 4, frames = 16, seconds = 0.96 },
	medProcRogue = { file = "Textures\\Medallions\\ProcRogue.png", rows = 4, columns = 4, frames = 16, seconds = 0.96 },
	medProcShaman = { file = "Textures\\Medallions\\ProcShaman.png", rows = 4, columns = 4, frames = 16, seconds = 0.96 },
	medProcStart = { file = "Textures\\Medallions\\ProcStart.png" },
	medProcWarlock = { file = "Textures\\Medallions\\ProcWarlock.png", rows = 4, columns = 4, frames = 16, seconds = 0.96 },
	medProcWarrior = { file = "Textures\\Medallions\\ProcWarrior.png", rows = 4, columns = 4, frames = 16, seconds = 0.96 },
	medReadyFlash = { file = "Textures\\Medallions\\ReadyFlash.png" },
	medRing = { file = "Textures\\Medallions\\Ring128.png" },
	medMinimapCrestRing = { file = "Textures\\Medallions\\MinimapCrestRing.png" },
	medMinimapCrestEnamel = { file = "Textures\\Medallions\\MinimapCrestEnamel.png" },
	medRingLarge = { file = "Textures\\Medallions\\Ring256.png" },
	medRuneGlyphs = { file = "Textures\\Medallions\\RuneGlyphs.png" },
	medRuneRing = { file = "Textures\\Medallions\\RuneRing.png" },
	medSlot = { file = "Textures\\Medallions\\Slot.png" },
	medSlotChecked = { file = "Textures\\Medallions\\SlotChecked.png" },
	medSlotHighlight = { file = "Textures\\Medallions\\SlotHighlight.png" },
	medSlotMask = { file = "Textures\\Medallions\\SlotMask.png" },
	medSlotSocket = { file = "Textures\\Medallions\\SlotSocket.png" },
	medSlotPushed = { file = "Textures\\Medallions\\SlotPushed.png" },
	medTargetBrackets = { file = "Textures\\Medallions\\TargetBrackets.png" },
	medUnitSlab = { file = "Textures\\Medallions\\UnitSlab.png", slice = 16, density = 2 },
	medUnitSlabCap = { file = "Textures\\Medallions\\UnitSlabCap.png", slice = 16, density = 2 },
	medVignette = { file = "Textures\\Medallions\\Vignette.png" },
	hudStyleMedallions = { file = "Textures\\HudStyleMedallions.tga" },
	logo = { file = "Logo\\Logo64.png" },
	logoLarge = { file = "Logo\\Logo256.tga" },
}
local FAN, ALL, FED = { 130, 110, 90, 70, 50 }, { "", "Steel", "Shape", "Glow" }, { "", "Steel", "Glow" }
local PIPS = {
	Blade = { FAN, ALL }, Claw = { FAN, ALL }, Banner = { FAN, FED }, Candle = { FAN, FED }, Talon = { FAN, FED },
	Shard = { { 130, 110, 90, 70, 50 }, FED }, Arrow = { { 105, 90, 75 }, FED }, Storm = { { 90 }, FED },
}
for set, pip in pairs(PIPS) do
	for _, kind in ipairs(pip[2]) do
		for _, angle in ipairs(pip[1]) do
			TEXTURES["pip" .. set .. kind .. angle] = { file = "Textures\\Pips\\Pip" .. set .. kind .. angle .. ".png" }
		end
	end
end
for _, kind in ipairs({ "", "Steel", "Core", "Glow" }) do
	for _, angle in ipairs({ 126, 102, 90, 78, 54 }) do
		TEXTURES["pipSpire" .. kind .. angle] = { file = "Textures\\Pips\\PipSpire" .. kind .. angle .. ".png" }
	end
end
for _, element in ipairs({ "Earth", "Fire", "Water", "Air" }) do
	TEXTURES["totemRune" .. element] = { file = "Textures\\Totems\\Rune" .. element .. ".png" }
end
for _, name in ipairs({
	"Aegis", "Aimed", "Arcane", "Axe", "Bark", "BlastWave", "Blink", "Bolt", "Brave", "Bubble", "Bulwark", "Charm", "ColdSnap", "Crossed", "Crystal", "Curse", "Dash",
	"Deflect", "Drop", "Escape", "Evade", "Eye", "Fang", "Farseer", "Feedback", "FireBlast", "FireTrap", "Flame", "Flurry", "Focus", "FrostNova", "Gear", "Ghost",
	"Grave", "Hand", "Heart", "Horns", "Hourglass", "IceBarrier", "IceLance", "Infusion", "Innervate", "Intimidate", "Lifeline", "Mend", "Moon", "Paw",
	"Potion", "Regen", "Roots", "Rush", "Sacrifice", "Shade", "Shatter", "Skull", "Smoke", "Sniper", "Star", "Stone", "Strider",
	"Sun", "Sweep", "Swift", "Thorns", "Tusks", "Veil", "Voice", "Void", "Volley", "Vortex", "Wall", "Wing"
}) do
	TEXTURES["sigil" .. name] = { file = "Textures\\Sigils\\" .. name .. ".png" }
end
for _, name in ipairs({
	"Ankh", "Bud", "Charge", "Dome", "Faerie", "Fangs", "Fiend", "Growl", "Growth", "Lance", "Mending", "MindOrb", "Moon", "Plague",
	"Rake", "Reaper", "Renew", "Rip", "Roar", "Shock", "Shroud", "Sprout", "Strike", "Swarm", "Tide", "Wolf"
}) do
	TEXTURES["figure" .. name] = { file = "Textures\\Figures\\" .. name .. ".png" }
end
for _, name in ipairs({
	"ArcLeft", "ArcPet", "ArcRight", "ArmorArcane", "ArmorFrost", "Bail", "Beast", "BlackArrow", "Burst", "Cheetah",
	"ChillShard", "Compass", "Counter", "Elements", "Eye", "Facet", "Fangs", "FireTongue", "Frost", "Haunch", "Hawk", "Horns", "Hound", "Hourglass",
	"Imp", "Intellect", "Lacerate", "MarkReticle", "Mongoose", "Monkey", "Pack", "PolyCurl", "Raptor", "RimLeft",
	"Scorpid", "Serpent", "Siphon", "Succubus", "Swirl", "Tongue", "Trueshot", "Viper", "ViperSting", "Voidwalker", "Weakness",
	"Wild", "Wyvern"
}) do
	TEXTURES["glyph" .. name] = { file = "Textures\\Glyphs\\" .. name .. ".png" }
end
for name, file in pairs({ Family = "Sigils\\Intimidate", Growl = "Figures\\Growl", Tranq = "Sigils\\Drop" }) do
	TEXTURES["glyph" .. name] = { file = "Textures\\" .. file .. ".png" }
end
for _, name in ipairs({
	"glyphBeast", "glyphBlackArrow", "glyphCheetah", "glyphCompass", "glyphCounter", "glyphHaunch", "glyphHawk", "glyphHound", "glyphLacerate", "glyphMongoose",
	"glyphMonkey", "glyphPack", "glyphRaptor", "glyphScorpid", "glyphSerpent", "glyphTrueshot", "glyphViper", "glyphViperSting", "glyphWild",
	"glyphWyvern", "glyphFamily", "glyphTranq", "sigilAimed", "sigilCharm", "sigilDeflect", "sigilFireTrap", "sigilIntimidate", "sigilPaw", "sigilSniper",
	"sigilStrider", "sigilVolley", "sigilBlink", "sigilFrostNova", "sigilFireBlast", "sigilBlastWave", "sigilColdSnap",
	"sigilIceBarrier", "sigilIceLance", "sigilEscape"
}) do
	TEXTURES[name].forged = true
end
TEXTURES.glyphHealthstone = { file = "Textures\\Glyphs\\Facet.png" }
for name, base in pairs({ HornsPet = "Horns", ImpFel = "Imp", VoidwalkerFel = "Voidwalker", SuccubusFel = "Succubus", FangsFel = "Fangs" }) do
	TEXTURES["glyph" .. name] = { file = TEXTURES["glyph" .. base].file }
end
for kind, names in pairs({
	Glyph = { "Burst", "ChillShard", "Elements", "Eye", "Facet", "Fangs", "FireTongue", "Healthstone", "Horns", "Hourglass", "Imp", "Intellect",
		"PolyCurl", "Siphon", "Succubus", "Swirl", "Tongue", "Voidwalker", "Weakness", "HornsPet", "ImpFel", "VoidwalkerFel", "SuccubusFel",
		"FangsFel" },
	Sigil = { "Arcane", "Crystal", "Curse", "Flame", "Horns", "Hourglass", "Shade", "Void", "Vortex" },
}) do
	for _, name in ipairs(names) do
		local token = "aura" .. kind .. name
		TEXTURES[token] = { file = "Textures\\Auras\\" .. kind .. "s\\" .. name .. ".png", rows = 4, columns = 4, frames = 16, seconds = 1.44 }
		TEXTURES[kind:lower() .. name].aura, TEXTURES[kind:lower() .. name].forged = token, true
	end
end
TEXTURES.auraTrackerSoulWisp = { file = "Textures\\Auras\\Trackers\\SoulWisp.png", rows = 4, columns = 4, frames = 16, seconds = 1.44 }
TEXTURES.trackerWisp.aura = "auraTrackerSoulWisp"
for _, name in ipairs({ "auraGlyphFacet", "auraGlyphHealthstone", "auraSigilArcane", "auraSigilCrystal", "auraSigilCurse", "auraSigilFlame",
	"auraSigilHorns", "auraSigilHourglass", "auraSigilShade", "auraSigilVoid", "auraSigilVortex", "auraTrackerSoulWisp" }) do
	TEXTURES[name].span = 1.25
end
TEXTURES.auraTrackerGust = { file = "Textures\\Auras\\Trackers\\Gust.png", rows = 8, columns = 2, frames = 16, seconds = 1.44 }
TEXTURES.auraSocket = { file = "Textures\\Auras\\Socket.png" }
TEXTURES.orbVesselHuman = { file = "Textures\\Medallions\\Orbs\\VesselHuman.png" }
TEXTURES.orbVesselGnome = { file = "Textures\\Medallions\\Orbs\\VesselGnome.png" }
TEXTURES.orbVesselOrc = { file = "Textures\\Medallions\\Orbs\\VesselOrc.png" }
TEXTURES.orbVesselScourge = { file = "Textures\\Medallions\\Orbs\\VesselScourge.png" }
TEXTURES.orbVesselTroll = { file = "Textures\\Medallions\\Orbs\\VesselTroll.png" }
TEXTURES.orbVesselSkyborne = { file = "Textures\\Medallions\\Orbs\\VesselSkyborne.png" }
TEXTURES.orbLightArcane = { file = "Textures\\Medallions\\Orbs\\LightArcane.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 }
TEXTURES.orbCoreArcane = { file = "Textures\\Medallions\\Orbs\\CoreArcane.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 }
TEXTURES.orbMeniscusArcane = { file = "Textures\\Medallions\\Orbs\\MeniscusArcane.png" }
TEXTURES.orbLightFire = { file = "Textures\\Medallions\\Orbs\\LightFire.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 }
TEXTURES.orbCoreFire = { file = "Textures\\Medallions\\Orbs\\CoreFire.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 }
TEXTURES.orbMeniscusFire = { file = "Textures\\Medallions\\Orbs\\MeniscusFire.png" }
TEXTURES.orbLightFrost = { file = "Textures\\Medallions\\Orbs\\LightFrost.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 }
TEXTURES.orbCoreFrost = { file = "Textures\\Medallions\\Orbs\\CoreFrost.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 }
TEXTURES.orbMeniscusFrost = { file = "Textures\\Medallions\\Orbs\\MeniscusFrost.png" }
TEXTURES.orbClear = { file = "Textures\\Medallions\\Orbs\\Clear.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 }
TEXTURES.orbBarrage = { file = "Textures\\Medallions\\Orbs\\Barrage.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 }
TEXTURES.orbHeat = { file = "Textures\\Medallions\\Orbs\\Heat.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 }
TEXTURES.orbRime1 = { file = "Textures\\Medallions\\Orbs\\Rime1.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 }
TEXTURES.orbRime2 = { file = "Textures\\Medallions\\Orbs\\Rime2.png", rows = 4, columns = 4, frames = 16, seconds = 1.6 }
TEXTURES.orbGlass = { file = "Textures\\Medallions\\Orbs\\Glass.png" }
for _, set in ipairs({
	{ kind = "Sigil", names = { "Crossed", "Skull", "Wall", "Heart", "Sweep", "Thorns", "Bubble", "Aegis", "Sun", "Hand", "Wing", "Bulwark", "Voice",
		"Flurry", "Rush", "Evade", "Drop", "Smoke", "Ghost", "Blink", "FrostNova", "FireBlast", "BlastWave", "ColdSnap", "IceBarrier", "IceLance" } },
	{ kind = "Sigil", tint = true, names = { "Dash", "Axe", "Tusks", "Stone", "Eye", "Grave", "Shatter", "Star", "Gear", "Regen", "Potion", "Escape" } },
	{ kind = "Sigil", rail = true, names = { "Fang", "Bolt", "Feedback", "Farseer", "Brave", "Mend", "Swift", "Sacrifice", "Infusion",
		"Lifeline", "Focus", "Moon", "Veil" } },
	{ kind = "Effect", tint = true, names = { "Horn", "Sword", "Axe", "Dagger", "Hammer", "Shield", "Seal", "Brand", "Drop", "Vial", "Ward", "Oath", "Stain" } },
}) do
	for _, name in ipairs(set.names) do
		local token = "aura" .. set.kind .. name
		TEXTURES[token] = {
			file = "Textures\\Auras\\" .. set.kind .. "s\\" .. name .. ".png", rows = 4, columns = 4, frames = 16, seconds = 1.44, span = 1.25, tint = set.tint,
		}
		if set.kind == "Sigil" and not set.rail then
			TEXTURES["sigil" .. name].aura = token
		end
	end
end
local BARE_AURAS = { Counter = true, Mongoose = true, Raptor = true }
for kind, names in pairs({
	Glyph = { "Beast", "BlackArrow", "Cheetah", "Compass", "Counter", "Haunch", "Hawk", "Hound", "Lacerate", "Mongoose", "Monkey", "Pack",
		"Raptor", "Scorpid", "Serpent", "Trueshot", "Viper", "ViperSting", "Wild", "Wyvern" },
	Sigil = { "Aimed", "Charm", "Deflect", "FireTrap", "Intimidate", "Paw", "Sniper", "Strider", "Volley" },
	Figure = { "Arrow75", "Arrow90", "Arrow105", "HawkPerch", "HawkPerchMirror" },
}) do
	for _, name in ipairs(names) do
		local token = "aura" .. kind .. name
		TEXTURES[token] = { file = "Textures\\Auras\\" .. kind .. "s\\" .. name .. ".png", rows = 4, columns = 4, frames = 16, seconds = 1.44,
			span = (kind ~= "Glyph" or BARE_AURAS[name]) and 1.25 or nil }
		if kind ~= "Figure" then
			TEXTURES[kind:lower() .. name].aura = token
		end
	end
end
TEXTURES.auraSigilFireTrapFuse = { file = "Textures\\Auras\\Sigils\\FireTrapFuse.png", rows = 4, columns = 4, frames = 16, seconds = 1.44, span = 1.25 }
TEXTURES.sigilFireTrapFuse = { file = TEXTURES.sigilFireTrap.file, forged = true, aura = "auraSigilFireTrapFuse" }

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

local LEGACY_COLOR = {
	barLoss = { 241 / 255, 185 / 255, 138 / 255, 0.85 },
	barLossLit = { 1, 233 / 255, 201 / 255, 0.85 },
	hudMana = { 61 / 255, 61 / 255, 236 / 255, 1 },
	healthLowText = { 197 / 255, 68 / 255, 62 / 255, 1 },
}

function Tokens.Color(name)
	local key = name == "healthLowText" and "readableBars" or "barColors"
	local legacy = LEGACY_COLOR[name]
	if legacy and ns.Appearance and not ns.Appearance.Readability(key) then
		return legacy[1], legacy[2], legacy[3], legacy[4]
	end
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
	return ns.Profiles and ns.Profiles.TextSize(name, v) or v
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
	local key = RoleChoice(role) or theme and theme.StyleFace and theme.StyleFace(role)
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
	local size = Tokens.Size(role)
	if role ~= "world" and theme and theme.FontScale then
		size = math.max(MIN_TEXT, size * theme.FontScale())
	end
	return ns.Locale.Font(path or FACE_PATH[FALLBACK_FACE]), size, spec.flags
end

function Tokens.FaceTracking(path)
	return FACE_TRACKING[path] or 0
end

local LEGACY_NAME_SHADOW = { x = 1, y = 1, alpha = 0.5 }
function Tokens.FaceShadow(path)
	if ns.Appearance and not ns.Appearance.Readability("worldText") and (path == Tokens.FontPath("FolioNames") or path == Tokens.FontPath("FolioUnit")) then
		return LEGACY_NAME_SHADOW
	end
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
	return MEDIA .. spec.file, spec.slice, units, spec.forged, spec.aura
end

function Tokens.Flipbook(name)
	local spec = TEXTURES[name]
	if not spec or not spec.frames then
		unknown("Flipbook", name)
	end
	return spec.rows, spec.columns, spec.frames, spec.seconds, spec.span or 1, spec.tint == true
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
