-- Style.lua: a unit frame's visual parts (glass panel, chamfered or round portrait, level badge, bars, texts), laid out from Geometry and styled from Settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Geometry, Indicators, Lumen = ns.Settings, ns.Geometry, ns.Indicators, ns.Lumen

local Style = {}
ns.Style = Style

local LEVEL_PORTRAIT = 3
local LEVEL_BADGE = 5
local LEVEL_TEXT = 8
local BADGE_EDGE = "text"
local BADGE_EDGE_ALPHA = 0.6
local PORTRAIT_BACK_ALPHA = 1
local INCOMING_ALPHA = 0.45
local ABSORB_ALPHA = 0.35
local IMAGE_SUBLEVEL = -4
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local TRACK = "buttonFill"
local TRACK_LINE, TRACK_LINE_ALPHA = "edgeBar", 1
local TINT = 0.85
local RIM_WHITE = 0.15
local RING_LIFT = 0.3
local OCTAGON = 1 / (2 + math.sqrt(2))
local PORTRAIT_CHAMFER = 0.15
local GLOW_SUBLEVEL = -8
local GLOW_SPREAD = 1.7
local RING_GUTTER = 1 / 64
local COLUMN_LEVEL_SCALE = 0.95
local DIAMOND_LINE = 2
local CAPTION_GAP = 10
local COLUMN_CAPTION_GAP = 9
local RULE_GAP = 8
local RULE_ALPHA = 0.55
local VALUE_GAP = 2
local SCRIM_SUBLEVEL = -8
local SCRIM_PAD = { sigil = { 36, 22, 0.5 }, row = { 30, 18, 0.75 }, card = { 30, 18, 0.75 } }

local issecretvalue = issecretvalue or function()
	return false
end

local ORIENTATION = {
	RIGHT = { "HORIZONTAL", false, "LEFT", "RIGHT" },
	LEFT = { "HORIZONTAL", true, "RIGHT", "LEFT" },
	UP = { "VERTICAL", false, "BOTTOM", "TOP" },
	DOWN = { "VERTICAL", true, "TOP", "BOTTOM" },
}

local TEXTS = {
	name = { justify = "LEFT", color = "textEmphasis" },
	healthText = { element = "health", justify = "RIGHT", color = "textEmphasis" },
	healthSub = { element = "health", justify = "RIGHT", color = "textEmphasis", share = Geometry.DETAIL_SHARE },
	powerText = { element = "power", justify = "LEFT", color = "text" },
	levelText = { element = "level", justify = "CENTER", color = "textEmphasis" },
	caption = { element = "level", justify = "LEFT", color = "text", lumen = "caption", lumenColor = "subLabel" },
	capLabel = { element = "level", justify = "LEFT", color = "textEmphasis", lumen = "cap", lumenColor = "goldLit" },
}
local TEXT_KEYS = { "name", "healthText", "healthSub", "powerText", "levelText", "caption", "capLabel" }
TEXTS.healthSub.lumen, TEXTS.healthSub.lumenColor, TEXTS.healthSub.lumenShare = "caption", "subLabel", 1

local function NewText(owner, key)
	local text = Widgets.FontString(owner, "OVERLAY")
	text:SetWordWrap(false)
	text:SetJustifyV("MIDDLE")
	text:SetJustifyH(TEXTS[key].justify)
	return text
end

local function GlassShape(kind)
	local element = K.Setup.Layouts.Element(Settings.ELEMENTS[kind])
	if element and element.height < Geometry.FULL_MIN_HEIGHT then
		return "tile"
	end
	return "panel"
end

local function Prediction(health, colorName)
	local bar = Widgets.StatusBar(health, { background = false, color = colorName, smooth = true })
	bar:Hide()
	return bar
end

local PORTRAITS, BLOCKS = {}, {}

function Style.RestyleBlocks()
	for _, block in ipairs(BLOCKS) do block:Restyle() end
end

function Style.New(parent, kind)
	local view = { kind = kind, parent = parent }
	local base = parent:GetFrameLevel()

	local panel = CreateFrame("Frame", nil, parent)
	panel:SetFrameLevel(base + 1)
	view.panel = panel
	view.scrim = panel:CreateTexture(nil, "BACKGROUND", nil, SCRIM_SUBLEVEL)
	view.scrim:SetTexture((Tokens.Texture("glow")))
	view.scrim:Hide()
	view.chrome = Widgets.Chrome(panel, { shape = GlassShape(kind), fill = "surface", shadow = true })

	view.health = Widgets.UnitBar(panel, { lowHealth = true })
	view.health:SetClipsChildren(true)
	view.incoming = Prediction(view.health, "friendly")
	view.absorb = Prediction(view.health, "white")
	view.power = Widgets.UnitBar(panel, { loss = false, spark = false })
	view.health.ornament = Widgets.Ornament(panel, "bar", view.health)
	view.health.ornament.span = view.power
	Widgets.RecordAll(view.health, view.power)
	view.trackLine = panel:CreateTexture(nil, "ARTWORK")
	view.trackLine:SetColorTexture(Tokens.Color("white"))

	local portraitFrame = CreateFrame("Frame", nil, parent)
	portraitFrame:SetFrameLevel(base + LEVEL_PORTRAIT)
	view.portraitFrame = portraitFrame
	view.portraitChrome = Widgets.Chrome(portraitFrame, { shape = "panel", fill = "buttonFill", grain = false })
	local dot, ring = Tokens.Texture("dot"), Tokens.Texture("ringBevel")
	view.portraitBack = portraitFrame:CreateTexture(nil, "BACKGROUND")
	view.portraitBack:SetTexture(dot)
	view.portraitBack:SetAllPoints(portraitFrame)
	view.portrait = portraitFrame:CreateTexture(nil, "BORDER", nil, IMAGE_SUBLEVEL)
	view.mask = portraitFrame:CreateMaskTexture()
	view.mask:SetAllPoints(view.portrait)
	view.portrait:AddMaskTexture(view.mask)
	view.ring = portraitFrame:CreateTexture(nil, "OVERLAY")
	view.ring:SetTexture(ring)
	view.ring:SetAllPoints(portraitFrame)
	view.portraitOrnament = Widgets.Ornament(portraitFrame, "ring")

	local badge = CreateFrame("Frame", nil, parent)
	badge:SetFrameLevel(base + LEVEL_BADGE)
	view.badge = badge
	view.badgeChrome = Widgets.Chrome(badge, { shape = "panel", fill = TRACK, shadow = false, grain = false })

	view.ringGlow = portraitFrame:CreateTexture(nil, "BACKGROUND", nil, GLOW_SUBLEVEL)
	view.ringGlow:SetTexture((Tokens.Texture("glow")))
	view.ringGlow:SetBlendMode("ADD")
	view.ringGlow:Hide()
	local disc = CreateFrame("Frame", nil, parent)
	disc:SetFrameLevel(base + LEVEL_BADGE)
	view.disc = disc
	view.health.ornament.avoid = { disc, badge, view.portraitOrnament }
	view.health.ornament.yoke = view.portraitOrnament
	view.health.ornament.card = view.chrome
	view.health.ornament.forged = true
	view.health.ornament.bare = true
	view.chrome.ornament = Widgets.Ornament(panel, "corners", nil, true)
	view.chrome.ornament.block, view.chrome.ornament.chrome = view.health.ornament, view.chrome
	view.chrome.ornament.bars = { view.health, view.power }
	view.health.ornament.others = PORTRAITS
	view.portraitFrame.blockOf, view.portraitOrnament.blockOf = view.health.ornament, view.health.ornament
	PORTRAITS[#PORTRAITS + 1] = view.portraitFrame
	PORTRAITS[#PORTRAITS + 1] = view.portraitOrnament
	BLOCKS[#BLOCKS + 1] = view.health.ornament
	view.discEdge = disc:CreateTexture(nil, "BACKGROUND", nil, -2)
	view.discEdge:SetTexture((Tokens.Texture("diamond")))
	view.discBack = disc:CreateTexture(nil, "BACKGROUND")
	view.discBack:SetTexture(dot)
	view.discBack:SetAllPoints(disc)
	view.discRing = disc:CreateTexture(nil, "BORDER")
	view.discRing:SetTexture((Tokens.Texture("ring")))
	view.discRing:SetAllPoints(disc)
	view.discInner = disc:CreateTexture(nil, "BORDER", nil, 1)
	view.discInner:SetTexture((Tokens.Texture("diamond")))
	disc:Hide()

	local top = CreateFrame("Frame", nil, parent)
	top:SetFrameLevel(base + LEVEL_TEXT)
	top:SetAllPoints(parent)
	view.top = top
	for _, key in ipairs(TEXT_KEYS) do
		view[key] = NewText(top, key)
	end
	view.health.ornament.texts = { view.name, view.healthText, view.healthSub, view.powerText, view.levelText, view.caption, view.capLabel }
	Widgets.RecordAll(unpack(view.health.ornament.texts))
	view.capGem = Lumen.Gem(top)
	local avoid = view.health.ornament.avoid
	avoid[#avoid + 1] = view.capGem
	view.capRule = top:CreateTexture(nil, "ARTWORK")
	view.capRule:SetTexture((Tokens.Texture("divider")))
	Indicators.New(view)
	Style.Shape(view, false)
	return view
end

local function Diamond(view, on)
	local disc = view.disc
	local diamond, dot, ring = (Tokens.Texture("diamond")), (Tokens.Texture("dot")), (Tokens.Texture("ring"))
	view.discBack:SetTexture(on and diamond or dot)
	view.discRing:SetTexture(on and diamond or ring)
	view.discEdge:SetShown(on)
	view.discInner:SetShown(on)
	view.discBack:ClearAllPoints()
	view.discRing:ClearAllPoints()
	if not on then
		view.discBack:SetAllPoints(disc)
		view.discRing:SetAllPoints(disc)
		return
	end
	local px = Widgets.Border(disc) * DIAMOND_LINE
	for i, layer in ipairs({ view.discEdge, view.discRing, view.discInner, view.discBack }) do
		layer:ClearAllPoints()
		layer:SetPoint("TOPLEFT", disc, "TOPLEFT", px * (i - 1), -px * (i - 1))
		layer:SetPoint("BOTTOMRIGHT", disc, "BOTTOMRIGHT", -px * (i - 1), px * (i - 1))
	end
end

function Style.Shape(view, round)
	view.round = round
	local column = view.form == "column" or view.form == "bar"
	local gutter = column and RING_GUTTER or 0
	view.ring:SetTexCoord(gutter, 1 - gutter, gutter, 1 - gutter)
	view.discRing:SetTexCoord(gutter, 1 - gutter, gutter, 1 - gutter)
	view.disc.ink = column and { "Dot", 0 } or { "Dot", 0, "Ring", gutter }
	Diamond(view, column)
	view.portraitBack:SetShown(round)
	view.ring:SetShown(round)
	view.portraitChrome:SetShadow(not round)
	view.portraitChrome:SetShown(not round)
	view.mask:SetTexture((Tokens.Texture(round and "dot" or "portraitMask")), MASK_WRAP, MASK_WRAP)
end

local function Snap(view, units)
	return Widgets.Snap(view.parent, units)
end

local function Place(view, region, rect)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", view.parent, "TOPLEFT", Snap(view, rect.x), -Snap(view, rect.y))
	region:SetSize(Snap(view, rect.w), Snap(view, rect.h))
end

local function PlaceBar(view, bar, rect)
	if not rect then
		bar:Hide()
		return
	end
	bar.opts.width, bar.opts.height = rect.w, rect.h
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", view.parent, "TOPLEFT", Snap(view, rect.x), -Snap(view, rect.y))
	bar:Restyle()
	bar:Show()
end

local function PlaceText(view, text, rect)
	if not rect then
		text:Hide()
		return
	end
	Place(view, text, rect)
	text:Show()
end

local function PlacePrediction(view, bar, after)
	local health = view.health
	local o = ORIENTATION[view.orientation or "RIGHT"]
	local w, h = health.opts.width, health.opts.height
	bar.opts.width, bar.opts.height = w, h
	bar:SetOrientation(o[1])
	bar:SetReverseFill(o[2])
	bar:ClearAllPoints()
	bar:SetPoint(o[3], after, o[4])
	bar:Restyle()
end

local function PlaceGem(view, gem, rect)
	if not rect then
		gem:Hide()
		return
	end
	Place(view, gem, rect)
	gem:Show()
end

local function Bottom(view, text, point, relative, relPoint, x, rect, drop)
	text:ClearAllPoints()
	text:SetPoint(point, relative, relPoint, Snap(view, x), -Snap(view, rect.y + rect.h) - Snap(view, drop or 0))
	text:SetHeight(Snap(view, rect.h))
	text:SetWidth(0)
	text:SetJustifyV("BOTTOM")
	text:Show()
end

local function Centre(view, text, point, relative, relPoint, x, rect)
	text:ClearAllPoints()
	text:SetPoint(point, relative, relPoint, Snap(view, x), -Snap(view, rect.y + rect.h / 2))
	text:SetHeight(Snap(view, rect.h))
	text:SetWidth(0)
	text:SetJustifyV("MIDDLE")
	text:Show()
end

local function TightName(view)
	return Tokens.FaceTracking((view.name:GetFont())) < 0
end

local function CaptionPoint(view, g)
	local lift = TightName(view) and Snap(view, g.captionLift or 0) or 0
	view.caption:ClearAllPoints()
	if g.mirror then
		view.caption:SetPoint("BOTTOMRIGHT", view.name, "BOTTOMLEFT", -Snap(view, g.form == "column" and COLUMN_CAPTION_GAP or CAPTION_GAP), lift)
	else
		view.caption:SetPoint("BOTTOMLEFT", view.name, "BOTTOMRIGHT", Snap(view, CAPTION_GAP) - Widgets.TrackPad(view.name), lift)
	end
end

local function NameBottom(view, g, rect)
	local drop = TightName(view) and g.nameDrop or 0
	view.nameRect = rect
	if g.mirror then
		Bottom(view, view.name, "BOTTOMRIGHT", view.parent, "TOPLEFT", rect.x + rect.w, rect, drop)
		view.name:SetJustifyH("RIGHT")
	else
		Bottom(view, view.name, "BOTTOMLEFT", view.parent, "TOPLEFT", rect.x, rect, drop)
		view.name:SetJustifyH("LEFT")
	end
	if view.nameBound and g.nameRoom then
		view.name:SetWidth(Snap(view, g.nameRoom))
	end
end

local function ValuePoints(view, g)
	local drop, parent = TightName(view) and g.valueDrop or 0, view.parent
	local sub, main = g.healthSub, g.healthText
	if g.mirror then
		if main then
			Bottom(view, view.healthText, "BOTTOMLEFT", parent, "TOPLEFT", main.x, main, drop)
		end
		return
	end
	if sub then
		Bottom(view, view.healthSub, "BOTTOMRIGHT", parent, "TOPLEFT", sub.x + sub.w, sub, drop)
	elseif main then
		Bottom(view, view.healthText, "BOTTOMRIGHT", parent, "TOPLEFT", main.x + main.w, main, drop)
	end
end

local function LumenTexts(view, g)
	local form, parent = g.form, view.parent
	for _, key in ipairs({ "name", "caption", "healthText", "healthSub", "powerText", "capLabel" }) do
		view[key]:SetJustifyV("MIDDLE")
	end
	view.healthText:SetJustifyH("RIGHT")
	view.powerText:Hide()
	view.capRule:Hide()
	if form == "bar" then
		for key, justify in pairs({ name = "CENTER", healthText = "LEFT", caption = "LEFT", healthSub = "RIGHT" }) do
			local text = view[key]
			PlaceText(view, text, g[key])
			text:SetJustifyH(justify)
		end
	elseif form == "column" and g.mirror then
		if g.name then
			NameBottom(view, g, g.name)
		else
			view.name:Hide()
		end
		if g.caption then
			CaptionPoint(view, g)
			view.caption:SetHeight(Snap(view, g.caption.h))
			view.caption:SetWidth(0)
			view.caption:SetJustifyV("BOTTOM")
			view.caption:SetJustifyH("RIGHT")
			view.caption:Show()
		else
			view.caption:Hide()
		end
		if g.healthText then
			ValuePoints(view, g)
			view.healthText:SetJustifyH("LEFT")
		else
			view.healthText:Hide()
		end
		view.healthSub:Hide()
	elseif form == "vitals" or form == "column" then
		if g.name and g.nameAuto then
			NameBottom(view, g, g.name)
		else
			PlaceText(view, view.name, g.name)
			view.name:SetJustifyV("BOTTOM")
			view.name:SetJustifyH("LEFT")
		end
		if g.caption then
			CaptionPoint(view, g)
			view.caption:SetHeight(Snap(view, g.caption.h))
			view.caption:SetWidth(0)
			view.caption:SetJustifyV("BOTTOM")
			view.caption:SetJustifyH("LEFT")
			view.caption:Show()
		else
			view.caption:Hide()
		end
		local sub, main = g.healthSub, g.healthText
		ValuePoints(view, g)
		if not sub then
			view.healthSub:Hide()
		end
		if main and sub then
			local text = view.healthText
			text:ClearAllPoints()
			text:SetPoint("BOTTOMRIGHT", view.healthSub, "BOTTOMLEFT", -Snap(view, VALUE_GAP), 0)
			text:SetHeight(Snap(view, main.h))
			text:SetWidth(0)
			text:SetJustifyV("BOTTOM")
			text:Show()
		elseif not main then
			view.healthText:Hide()
		end
	elseif form == "sigil" then
		PlaceText(view, view.name, g.name)
		PlaceText(view, view.caption, g.caption)
		view.name:SetJustifyH("CENTER")
		view.caption:SetJustifyH("CENTER")
		view.healthText:Hide()
		view.healthSub:Hide()
	elseif form == "card" then
		PlaceText(view, view.name, g.name)
		PlaceText(view, view.healthText, g.healthText)
		view.name:SetJustifyH("LEFT")
		view.healthText:SetJustifyH("RIGHT")
		view.healthSub:Hide()
		local cap = g.cap
		if cap then
			Centre(view, view.capLabel, "LEFT", parent, "TOPLEFT", g.capLabel.x, cap)
			Centre(view, view.caption, "RIGHT", parent, "TOPLEFT", cap.x + cap.w, cap)
			view.caption:SetJustifyH("RIGHT")
			local rule = view.capRule
			rule:ClearAllPoints()
			rule:SetPoint("LEFT", view.capLabel, "RIGHT", Snap(view, RULE_GAP), 0)
			rule:SetPoint("RIGHT", view.caption, "LEFT", -Snap(view, RULE_GAP), 0)
			rule:SetHeight(Widgets.Border(parent))
			rule:Show()
		else
			view.capLabel:Hide()
			view.caption:Hide()
		end
	else
		PlaceText(view, view.name, g.name)
		PlaceText(view, view.healthText, g.healthText)
		view.name:SetJustifyH("LEFT")
		view.healthText:SetJustifyH("RIGHT")
		view.caption:Hide()
		view.healthSub:Hide()
	end
	if form ~= "card" then
		view.capLabel:Hide()
	end
	PlaceGem(view, view.capGem, g.capGem)
end

local function PlaceScrim(view, g)
	local scrim, pad = view.scrim, SCRIM_PAD[g.form]
	if not pad then
		scrim:Hide()
		return
	end
	local r, gg, b = Tokens.Color("black")
	scrim:SetVertexColor(r, gg, b, pad[3])
	scrim:ClearAllPoints()
	scrim:SetPoint("CENTER", view.parent, "TOPLEFT", Snap(view, g.glass.x + g.glass.w / 2), -Snap(view, g.glass.y + g.glass.h / 2))
	scrim:SetSize(Snap(view, g.glass.w + 2 * pad[1]), Snap(view, g.glass.h + 2 * pad[2]))
	scrim:Show()
end

local function LayoutLumen(view, g, s)
	view.panel:SetShown(true)
	Place(view, view.panel, g.glass)
	PlaceScrim(view, g)
	view.chrome:Restyle()
	view.chrome:SetShadow(g.chrome)
	view.chrome:SetShown(g.chrome)
	PlaceBar(view, view.health, g.health)
	PlaceBar(view, view.power, g.power)
	view.trackLine:Hide()
	PlacePrediction(view, view.incoming, view.health:GetStatusBarTexture())
	PlacePrediction(view, view.absorb, view.incoming:GetStatusBarTexture())
	view.badge:Hide()
	if g.portrait then
		local p = g.portrait
		Place(view, view.portraitFrame, p)
		local inset = Snap(view, p.w * Widgets.RING_INSET)
		view.portrait:ClearAllPoints()
		view.portrait:SetPoint("TOPLEFT", view.portraitFrame, "TOPLEFT", inset, -inset)
		view.portrait:SetPoint("BOTTOMRIGHT", view.portraitFrame, "BOTTOMRIGHT", -inset, inset)
		local spread = Snap(view, p.w * GLOW_SPREAD)
		view.ringGlow:ClearAllPoints()
		view.ringGlow:SetPoint("CENTER", view.portraitFrame, "CENTER")
		view.ringGlow:SetSize(spread, spread)
		view.portraitFrame:Show()
	else
		view.portraitFrame:Hide()
	end
	if g.badge then
		Place(view, view.disc, g.badge)
		view.disc:Show()
		view.levelText:ClearAllPoints()
		view.levelText:SetPoint("CENTER", view.disc, "CENTER")
		view.levelText.ink = view.disc.ink
		view.levelText:SetSize(Snap(view, g.badge.w), Snap(view, g.badge.h))
		view.levelText:SetJustifyH("CENTER")
		view.levelText:Show()
	else
		view.disc:Hide()
		view.levelText:Hide()
		view.levelText.ink = nil
	end
	LumenTexts(view, g)
	Indicators.Layout(view, g, s)
end

local function HideLumen(view)
	view.scrim:Hide()
	view.disc:Hide()
	view.ringGlow:Hide()
	view.caption:Hide()
	view.capLabel:Hide()
	view.capRule:Hide()
	view.capGem:Hide()
	for _, key in ipairs({ "name", "healthText", "healthSub", "powerText", "levelText" }) do
		view[key]:SetJustifyV("MIDDLE")
	end
	view.name:SetJustifyH("LEFT")
	view.healthText:SetJustifyH("RIGHT")
end

function Style.Baseline(view)
	local g = view.geometry
	if not (g and g.nameAuto and g.nameDrop and view.nameRect) then
		return
	end
	NameBottom(view, g, view.nameRect)
	if g.caption and view.caption:IsShown() then
		CaptionPoint(view, g)
	end
	ValuePoints(view, g)
end

function Style.PlaceName(view, rect)
	local g = view.geometry
	if (g.form == "vitals" or g.form == "column") and g.nameAuto then
		NameBottom(view, g, rect)
	else
		Place(view, view.name, rect)
	end
end

function Style.Layout(view, s, width, height)
	local g = Geometry.Frame(s, width, height, K.Theme.FontScale())
	view.geometry = g
	view.portraitOrnament.mirror = g.mirror == true
	view.form = g.form
	if g.form ~= "plate" then
		LayoutLumen(view, g, s)
		return g
	end
	HideLumen(view)
	Place(view, view.panel, g.glass)
	view.chrome:Restyle()
	view.chrome:SetShadow(true)
	view.chrome:SetShown(true)
	PlaceBar(view, view.health, g.health)
	PlaceBar(view, view.power, g.power)
	PlaceText(view, view.trackLine, g.trackLine)
	if g.trackLine then
		view.trackLine:SetHeight(Widgets.Border(view.parent))
	end
	PlacePrediction(view, view.incoming, view.health:GetStatusBarTexture())
	PlacePrediction(view, view.absorb, view.incoming:GetStatusBarTexture())
	if g.portrait then
		Place(view, view.portraitFrame, g.portrait)
		view.portraitChrome:SetChamfer(PORTRAIT_CHAMFER * g.portrait.w)
		view.portraitChrome:Restyle()
		local inset = view.round and Snap(view, g.portrait.w * Widgets.RING_INSET) or Widgets.Border(view.parent) * 2
		view.portrait:ClearAllPoints()
		view.portrait:SetPoint("TOPLEFT", view.portraitFrame, "TOPLEFT", inset, -inset)
		view.portrait:SetPoint("BOTTOMRIGHT", view.portraitFrame, "BOTTOMRIGHT", -inset, inset)
		view.portraitFrame:Show()
	else
		view.portraitFrame:Hide()
	end
	if g.badge then
		Place(view, view.badge, g.badge)
		view.badgeChrome:SetChamfer(OCTAGON * g.badge.w)
		view.badgeChrome:Restyle()
		view.badge:Show()
		view.levelText:ClearAllPoints()
		view.levelText:SetPoint("CENTER", view.badge, "CENTER")
		view.levelText.ink = nil
		view.levelText:SetSize(Snap(view, g.badge.w), Snap(view, g.badge.h))
		view.levelText:SetJustifyH("CENTER")
		view.levelText:Show()
	else
		view.badge:Hide()
		PlaceText(view, view.levelText, g.levelText)
		view.levelText:SetJustifyH("RIGHT")
		view.levelText.ink = nil
	end
	PlaceText(view, view.name, g.name)
	PlaceText(view, view.healthText, g.healthText)
	PlaceText(view, view.healthSub, g.healthSub)
	PlaceText(view, view.powerText, g.powerText)
	Indicators.Layout(view, g, s)
	return g
end

local function ApplyFont(text, path, size, flags)
	if not Widgets.ApplyFont(text, path, size, flags) then
		local fallback, fallbackSize = Tokens.Font("body")
		Widgets.ApplyFont(text, fallback, fallbackSize, flags)
		Widgets.LogOnce("unitframes-font:" .. tostring(path), "UnitFrames: the font " .. tostring(path) .. " did not load; using KstyleUI's font")
	end
end

local function Orient(bar, direction)
	local o = ORIENTATION[direction] or ORIENTATION.RIGHT
	bar:SetOrientation(o[1])
	bar:SetReverseFill(o[2])
end

function Style.Restyle(view, kind)
	local form = Settings.Form(kind)
	view.form = form
	local lumen = form ~= "plate"
	for key, spec in pairs(TEXTS) do
		local element = spec.element or key
		local path, size, flags = Settings.Font(kind, element)
		if (form == "column" or form == "bar") and key == "levelText" then
			size = size * COLUMN_LEVEL_SCALE
		end
		local share = spec.share or 1
		if lumen and spec.lumen then
			share = spec.lumenShare or share
			if Settings.ThemeFont(kind, element) then
				path = Lumen.Font(spec.lumen)
			end
		end
		ApplyFont(view[key], path, size * share, flags)
		if lumen and spec.lumenColor then
			view[key]:SetTextColor(Lumen.Color(spec.lumenColor))
		else
			view[key]:SetTextColor(Tokens.Color(spec.color))
		end
	end
	view.capRule:SetVertexColor(Lumen.Color("gold"))
	view.capRule:SetAlpha(RULE_ALPHA)
	Style.Shape(view, form == "vitals" or Settings.Value(kind, "portraitShape") == "round")
	view.health:SetBarTexture(Settings.Value(kind, "healthTexture"))
	view.power:SetBarTexture(Settings.Value(kind, "powerTexture"))
	view.incoming:SetBarTexture(Settings.Value(kind, "healthTexture"))
	view.absorb:SetBarTexture(Settings.Value(kind, "healthTexture"))
	view.orientation = Settings.Value(kind, "healthOrientation")
	Orient(view.health, view.orientation)
	Orient(view.power, Settings.Value(kind, "powerOrientation"))
	view.incoming:SetBarColor(Widgets.Rgba("friendly", INCOMING_ALPHA))
	view.absorb:SetBarColor(Widgets.Rgba("white", ABSORB_ALPHA))
	Widgets.Tint(view.trackLine, TRACK_LINE, TRACK_LINE_ALPHA)
	Style.Accent(view)
end

local function Plain(...)
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if issecretvalue(v) or type(v) ~= "number" then
			return false
		end
	end
	return true
end

function Style.HealthTint(view, r, g, b)
	if view.geometry and view.geometry.form == "plate" and not view.geometry.compact and Plain(r, g, b) then
		view.healthText:SetTextColor(r + (1 - r) * TINT, g + (1 - g) * TINT, b + (1 - b) * TINT)
	else
		view.healthText:SetTextColor(Tokens.Color("textEmphasis"))
	end
end

function Style.Accent(view)
	local r, g, b = Settings.Accent()
	if view.form == "vitals" or view.form == "column" then
		local gr, gg, gb = Lumen.Color("gold")
		view.ring:SetVertexColor(gr, gg, gb, 1)
	else
		view.ring:SetVertexColor(Widgets.Mix(r, g, b, 1, 1, 1, 1, 1, RING_LIFT))
	end
	view.discRing:SetVertexColor(Lumen.Color("gold"))
	view.discBack:SetVertexColor(Lumen.Color("deep"))
	Widgets.Tint(view.discEdge, "black")
	Widgets.Tint(view.discInner, "black")
	if view.form == "column" or view.form == "bar" then
		view.discBack:SetVertexColor(Tokens.Color("materialForged"))
	end
	view.portraitChrome:SetEdgeRGBA(Widgets.Mix(r, g, b, 1, 1, 1, 1, 1, RIM_WHITE))
	view.icons.resting:SetTextColor(r, g, b, 1)
	if view.round then
		view.badgeChrome:SetEdgeRGBA(r, g, b, 1)
	else
		view.badgeChrome:SetEdge(BADGE_EDGE, BADGE_EDGE_ALPHA)
	end
	local br, bg, bb = Tokens.Color("buttonFill")
	view.portraitBack:SetVertexColor(br, bg, bb, PORTRAIT_BACK_ALPHA)
end

Style.ORIENTATION = ORIENTATION
