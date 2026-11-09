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
local CAPTION_GAP = 10
local RULE_GAP = 8
local RULE_ALPHA = 0.55
local VALUE_GAP = 3
local SCRIM_SUBLEVEL = -8
local SCRIM_PAD_X, SCRIM_PAD_Y = 36, 22
local SCRIM_ALPHA = 0.5

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
	caption = { element = "level", justify = "LEFT", color = "text", lumen = "caption", lumenColor = "muted" },
	capLabel = { element = "level", justify = "LEFT", color = "textEmphasis", lumen = "cap", lumenColor = "goldLit" },
}
TEXTS.healthSub.lumen, TEXTS.healthSub.lumenColor, TEXTS.healthSub.lumenShare = "caption", "muted", 1

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

	view.health = Widgets.StatusBar(panel, { smooth = true, background = TRACK })
	view.health:SetClipsChildren(true)
	view.incoming = Prediction(view.health, "friendly")
	view.absorb = Prediction(view.health, "white")
	view.power = Widgets.StatusBar(panel, { smooth = true, background = TRACK })
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
	view.discBack = disc:CreateTexture(nil, "BACKGROUND")
	view.discBack:SetTexture(dot)
	view.discBack:SetAllPoints(disc)
	view.discRing = disc:CreateTexture(nil, "BORDER")
	view.discRing:SetTexture((Tokens.Texture("ring")))
	view.discRing:SetAllPoints(disc)
	disc:Hide()

	local top = CreateFrame("Frame", nil, parent)
	top:SetFrameLevel(base + LEVEL_TEXT)
	top:SetAllPoints(parent)
	view.top = top
	for key in pairs(TEXTS) do
		view[key] = NewText(top, key)
	end
	view.capGem = Lumen.Gem(top)
	view.gemLeft = Lumen.Gem(top)
	view.gemRight = Lumen.Gem(top)
	view.capRule = top:CreateTexture(nil, "ARTWORK")
	view.capRule:SetTexture((Tokens.Texture("divider")))
	Indicators.New(view)
	Style.Shape(view, false)
	return view
end

function Style.Shape(view, round)
	view.round = round
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

local function Bottom(view, text, point, relative, relPoint, x, rect)
	text:ClearAllPoints()
	text:SetPoint(point, relative, relPoint, Snap(view, x), -Snap(view, rect.y + rect.h))
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

local function LumenTexts(view, g)
	local form, parent = g.form, view.parent
	for _, key in ipairs({ "name", "caption", "healthText", "healthSub", "powerText", "capLabel" }) do
		view[key]:SetJustifyV("MIDDLE")
	end
	view.powerText:Hide()
	view.capRule:Hide()
	if form == "vitals" then
		if g.name and g.nameAuto then
			Bottom(view, view.name, "BOTTOMLEFT", parent, "TOPLEFT", g.name.x, g.name)
		else
			PlaceText(view, view.name, g.name)
			view.name:SetJustifyV("BOTTOM")
		end
		view.name:SetJustifyH("LEFT")
		if g.caption then
			view.caption:ClearAllPoints()
			view.caption:SetPoint("BOTTOMLEFT", view.name, "BOTTOMRIGHT", Snap(view, CAPTION_GAP), 0)
			view.caption:SetHeight(Snap(view, g.caption.h))
			view.caption:SetWidth(0)
			view.caption:SetJustifyV("BOTTOM")
			view.caption:SetJustifyH("LEFT")
			view.caption:Show()
		else
			view.caption:Hide()
		end
		local sub, main = g.healthSub, g.healthText
		if sub then
			Bottom(view, view.healthSub, "BOTTOMRIGHT", parent, "TOPLEFT", sub.x + sub.w, sub)
		else
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
		elseif main then
			Bottom(view, view.healthText, "BOTTOMRIGHT", parent, "TOPLEFT", main.x + main.w, main)
		else
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
	PlaceGem(view, view.gemLeft, g.gemLeft)
	PlaceGem(view, view.gemRight, g.gemRight)
end

local function PlaceScrim(view, g)
	local scrim = view.scrim
	if g.form ~= "sigil" then
		scrim:Hide()
		return
	end
	local r, gg, b = Tokens.Color("black")
	scrim:SetVertexColor(r, gg, b, SCRIM_ALPHA)
	scrim:ClearAllPoints()
	scrim:SetPoint("CENTER", view.parent, "TOPLEFT", Snap(view, g.glass.x + g.glass.w / 2), -Snap(view, g.glass.y + g.glass.h / 2))
	scrim:SetSize(Snap(view, g.glass.w + 2 * SCRIM_PAD_X), Snap(view, g.glass.h + 2 * SCRIM_PAD_Y))
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
		view.levelText:SetSize(Snap(view, g.badge.w), Snap(view, g.badge.h))
		view.levelText:SetJustifyH("CENTER")
		view.levelText:Show()
	else
		view.disc:Hide()
		view.levelText:Hide()
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
	view.gemLeft:Hide()
	view.gemRight:Hide()
	for _, key in ipairs({ "name", "healthText", "healthSub", "powerText", "levelText" }) do
		view[key]:SetJustifyV("MIDDLE")
	end
	view.name:SetJustifyH("LEFT")
	view.healthText:SetJustifyH("RIGHT")
end

function Style.PlaceName(view, rect)
	local g = view.geometry
	if g.form == "vitals" and g.nameAuto then
		Bottom(view, view.name, "BOTTOMLEFT", view.parent, "TOPLEFT", rect.x, rect)
	else
		Place(view, view.name, rect)
	end
end

function Style.Layout(view, s, width, height)
	local g = Geometry.Frame(s, width, height, K.Theme.FontScale())
	view.geometry = g
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
		view.levelText:SetSize(Snap(view, g.badge.w), Snap(view, g.badge.h))
		view.levelText:SetJustifyH("CENTER")
		view.levelText:Show()
	else
		view.badge:Hide()
		PlaceText(view, view.levelText, g.levelText)
		view.levelText:SetJustifyH("RIGHT")
	end
	PlaceText(view, view.name, g.name)
	PlaceText(view, view.healthText, g.healthText)
	PlaceText(view, view.healthSub, g.healthSub)
	PlaceText(view, view.powerText, g.powerText)
	Indicators.Layout(view, g, s)
	return g
end

local function ApplyFont(text, path, size, flags)
	if text:SetFont(path, size, flags) == false then
		local fallback, fallbackSize = Tokens.Font("body")
		text:SetFont(fallback, fallbackSize, flags)
		Widgets.LogOnce("unitframes-font:" .. tostring(path), "UnitFrames: the font " .. tostring(path) .. " did not load; using KstyleUI's font")
	end
	if flags == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
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
	if view.form == "vitals" then
		local gr, gg, gb = Lumen.Color("gold")
		view.ring:SetVertexColor(gr, gg, gb, 1)
	else
		view.ring:SetVertexColor(Widgets.Mix(r, g, b, 1, 1, 1, 1, 1, RING_LIFT))
	end
	view.discRing:SetVertexColor(Lumen.Color("gold"))
	view.discBack:SetVertexColor(Lumen.Color("deep"))
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
