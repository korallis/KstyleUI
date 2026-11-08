-- Style.lua: a unit frame's visual parts (glass panel, chamfered or round portrait, level badge, bars, texts), laid out from Geometry and styled from Settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Geometry, Indicators = ns.Settings, ns.Geometry, ns.Indicators

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
local TRACK = "raised"
local POWER_TRACK = "powerTrack"
local TRACK_LINE, TRACK_LINE_ALPHA = "powerTrack", 1
local TINT = 0.85
local RIM_WHITE = 0.15
local OCTAGON = 1 / (2 + math.sqrt(2))
local PORTRAIT_CHAMFER = 0.15
local GLASS_CHAMFER = 0.125

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
}

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
	view.chrome = Widgets.Chrome(panel, { shape = GlassShape(kind), fill = "surface", shadow = true })

	view.health = Widgets.StatusBar(panel, { smooth = true, background = TRACK })
	view.health:SetClipsChildren(true)
	view.incoming = Prediction(view.health, "friendly")
	view.absorb = Prediction(view.health, "white")
	view.power = Widgets.StatusBar(panel, { smooth = true, background = POWER_TRACK })
	view.trackLine = panel:CreateTexture(nil, "ARTWORK")
	view.trackLine:SetColorTexture(Tokens.Color("white"))

	local portraitFrame = CreateFrame("Frame", nil, parent)
	portraitFrame:SetFrameLevel(base + LEVEL_PORTRAIT)
	view.portraitFrame = portraitFrame
	view.portraitChrome = Widgets.Chrome(portraitFrame, { shape = "panel", fill = "buttonFill", grain = false })
	local dot, ring = Tokens.Texture("dot"), Tokens.Texture("ring")
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
	view.badgeChrome = Widgets.Chrome(badge, { shape = "panel", fill = "surface", shadow = false, grain = false })

	local top = CreateFrame("Frame", nil, parent)
	top:SetFrameLevel(base + LEVEL_TEXT)
	top:SetAllPoints(parent)
	view.top = top
	for key in pairs(TEXTS) do
		view[key] = NewText(top, key)
	end
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

function Style.Layout(view, s, width, height)
	local g = Geometry.Frame(s, width, height, K.Theme.FontScale())
	view.geometry = g
	Place(view, view.panel, g.glass)
	view.chrome:SetChamfer(not g.compact and GLASS_CHAMFER * g.glass.h or nil)
	view.chrome:Restyle()
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
		local inset = Widgets.Border(view.parent) * (view.round and 1 or 2)
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
	for key, spec in pairs(TEXTS) do
		local path, size, flags = Settings.Font(kind, spec.element or key)
		ApplyFont(view[key], path, size * (spec.share or 1), flags)
		view[key]:SetTextColor(Tokens.Color(spec.color))
	end
	Style.Shape(view, Settings.Value(kind, "portraitShape") == "round")
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
	if view.geometry and not view.geometry.compact and Plain(r, g, b) then
		view.healthText:SetTextColor(r + (1 - r) * TINT, g + (1 - g) * TINT, b + (1 - b) * TINT)
	else
		view.healthText:SetTextColor(Tokens.Color("textEmphasis"))
	end
end

function Style.Accent(view)
	local r, g, b = Settings.Accent()
	view.ring:SetVertexColor(r, g, b, 1)
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
