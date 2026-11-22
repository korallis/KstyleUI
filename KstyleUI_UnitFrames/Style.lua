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
local GRADIENT_SHADE = 0.55
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
local SCRIM_PAD = { sigil = { 36, 22, 0.5 }, row = { 30, 18, 0.75 }, card = { 30, 3, 0.75 }, slab = { 18, 14, 0.55 } }
local GLOW_LINE, SPARK_W, FIVE_SECONDS, COST_ALPHA, ABSORB_BAR_ALPHA = 6, 6, 5, 0.6, 0.9
local NUDGE = { name = "name", healthText = "health", healthSub = "health", powerText = "power", levelText = "level", caption = "level", slabLevel = "level" }

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
	powerText = { element = "power", justify = "LEFT", color = "textEmphasis" },
	levelText = { element = "level", justify = "CENTER", color = "textEmphasis" },
	caption = { element = "level", justify = "LEFT", color = "text", lumen = "caption" },
	capLabel = { element = "level", justify = "LEFT", color = "textEmphasis", lumen = "cap", lumenColor = "goldLit" },
}
local TEXT_KEYS = { "name", "healthText", "healthSub", "powerText", "levelText", "caption", "capLabel" }
TEXTS.healthSub.lumen, TEXTS.healthSub.lumenShare = "caption", 1

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

	view.health = Widgets.UnitBar(panel, { lowHealth = true })
	view.health:SetClipsChildren(true)
	view.incoming = Prediction(view.health, "friendly")
	view.absorb = Prediction(view.health, "white")
	view.power = Widgets.UnitBar(panel, { loss = false, spark = false })
	view.trackLine = panel:CreateTexture(nil, "ARTWORK")
	view.trackLine:SetColorTexture(Tokens.Color("white"))
	view.powerTypeLine = view.power:CreateTexture(nil, "OVERLAY")
	view.powerTypeLine:SetPoint("BOTTOMLEFT", view.power, "BOTTOMLEFT")
	view.powerTypeLine:SetPoint("BOTTOMRIGHT", view.power, "BOTTOMRIGHT")
	view.powerTypeLine:Hide()

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
	local clip = CreateFrame("Frame", nil, top)
	clip:SetFrameLevel(top:GetFrameLevel() + 1)
	clip:SetClipsChildren(true)
	local fill = view.power:GetStatusBarTexture()
	clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
	clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
	view.powerFillClip = clip
	view.powerFillText = NewText(clip, "powerText")
	view.powerFillText:SetAllPoints(view.powerText)
	view.powerFillText:SetJustifyH("RIGHT")
	clip:Hide()
	for _, method in ipairs({ "SetText", "SetFormattedText" }) do
		local write = view.powerText[method]
		view.powerText[method] = function(self, ...)
			write(self, ...)
			write(view.powerFillText, ...)
		end
	end
	view.capGem = Lumen.Gem(top)
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

local function PowerStrata(view)
	local s = view.s
	local own = s and s.powerDetach ~= "" and s.form ~= "slab" and s.powerDetachStrata or ""
	if own == (view.powerStrata or "") then return end
	view.powerStrata = own ~= "" and own or nil
	local lift = view.powerLift or CreateFrame("Frame", nil, view.top)
	view.powerLift = lift
	lift:SetAllPoints(view.top)
	local home = own ~= "" and lift or view.top
	view.powerText:SetParent(home)
	view.powerFillClip:SetParent(home)
	view.powerFillClip:SetFrameLevel(home:GetFrameLevel() + 1)
	local strata = own ~= "" and own or view.power:GetParent():GetFrameStrata()
	if not issecretvalue(strata) then
		view.power:SetFrameStrata(strata)
		lift:SetFrameStrata(strata)
		view.powerFillClip:SetFrameStrata(strata)
	end
end

local function PlaceBar(view, bar, rect)
	if bar == view.power then PowerStrata(view) end
	if not rect then
		bar:Hide()
		return
	end
	bar.opts.width, bar.opts.height = rect.w, rect.h
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", view.parent, "TOPLEFT", Snap(view, rect.x), -Snap(view, rect.y))
	bar:Restyle()
	if bar == view.power then view.powerTypeLine:SetHeight(Snap(view, 1)) end
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

local function PlacePrediction(view, bar, after, backwards, placement, base, direction)
	base = base or view.health
	local o = ORIENTATION[direction or view.orientation or "RIGHT"] or ORIENTATION.RIGHT
	if placement == "END" or placement == "START" then
		after, backwards = base, placement == "END"
	end
	bar.opts.width, bar.opts.height = base.opts.width, base.opts.height
	bar:SetOrientation(o[1])
	bar:SetReverseFill(o[2] ~= (backwards == true))
	bar:ClearAllPoints()
	bar:SetPoint(o[backwards and 4 or 3], after, o[(after == base and not backwards) and 3 or 4])
	bar:Restyle()
end

local function Texture(kind, key)
	local own = Settings.Value(kind, key)
	return own ~= "" and own or Settings.Value(kind, "healthTexture")
end

local function PlaceHealAbsorb(view)
	local bar = view.healAbsorb
	if not bar then return end
	PlacePrediction(view, bar, view.health:GetStatusBarTexture(), true, Settings.Value(view.kind, "healAbsorbPlacement"))
	bar:SetBarTexture(Texture(view.kind, "healAbsorbTexture"))
	bar:SetBarColor(Widgets.Rgba("hostile", Settings.Value(view.kind, "healAbsorbAlpha")))
end

function Style.ShieldGlow(view)
	local glow = view.shieldGlow
	if not glow then
		glow = view.top:CreateTexture(nil, "BACKGROUND")
		glow:SetTexture((Tokens.Texture("glow")))
		glow:SetBlendMode("ADD")
		glow:SetVertexColor(Tokens.Color("white"))
		glow:Hide()
		view.shieldGlow = glow
	end
	local o, health = ORIENTATION[view.orientation or "RIGHT"], view.health
	glow:ClearAllPoints()
	glow:SetPoint(o[4], health, o[4])
	local across = o[1] == "HORIZONTAL"
	glow:SetSize(Snap(view, across and GLOW_LINE or health.opts.width), Snap(view, across and health.opts.height or GLOW_LINE))
	return glow
end

function Style.AbsorbBar(view)
	local bar, where = view.absorbBar, Settings.Value(view.kind, "absorbBar")
	if where == "" then
		if bar then bar:Hide() end
		return nil
	end
	if not bar then
		bar = Prediction(view.health, "white")
		view.absorbBar = bar
	end
	bar.opts.width, bar.opts.height = view.health.opts.width, Settings.Value(view.kind, "absorbBarHeight")
	bar:SetOrientation("HORIZONTAL")
	bar:SetReverseFill(view.orientation == "LEFT")
	bar:ClearAllPoints()
	bar:SetPoint(where .. "LEFT", view.health, where .. "LEFT")
	bar:Restyle()
	bar:SetBarTexture(Texture(view.kind, "absorbTexture"))
	bar:SetBarColor(Widgets.Rgba("white", ABSORB_BAR_ALPHA))
	return bar
end

function Style.LossBar(view)
	local bar = view.lossBar
	if not bar then
		bar = Prediction(view.health, "hostile")
		view.lossBar = bar
	end
	PlacePrediction(view, bar, view.health, true)
	bar:SetBarRange(0, 1)
	bar:SetBarTexture(Settings.Value(view.kind, "healthTexture"))
	bar:SetBarColor(Widgets.Rgba("hostile", Settings.Value(view.kind, "maxHealthAlpha")))
	return bar
end

function Style.CostBar(view)
	local bar = view.costBar
	if not bar then
		bar = Prediction(view.power, "white")
		view.costBar = bar
	end
	PlacePrediction(view, bar, view.power:GetStatusBarTexture(), true, nil, view.power, Settings.Value(view.kind, "powerOrientation"))
	bar:SetBarTexture(Settings.Value(view.kind, "powerTexture"))
	local c = Settings.Value(view.kind, "powerCostColor")
	bar:SetBarColor(c.r, c.g, c.b, COST_ALPHA)
	return bar
end

local SPARK_PATH = { RIGHT = { "LEFT", 1, 0 }, LEFT = { "RIGHT", -1, 0 }, UP = { "BOTTOM", 0, 1 }, DOWN = { "TOP", 0, -1 } }
function Style.Spark(view)
	local spark = view.manaSpark
	if not spark then
		spark = view.power:CreateTexture(nil, "OVERLAY")
		spark:SetTexture((Tokens.Texture("glow")))
		spark:SetBlendMode("ADD")
		spark:Hide()
		spark.group = spark:CreateAnimationGroup()
		spark.move = spark.group:CreateAnimation("Translation")
		spark.move:SetDuration(FIVE_SECONDS)
		spark.group:SetScript("OnFinished", function() spark:Hide() end)
		view.manaSpark = spark
	end
	local path = SPARK_PATH[Settings.Value(view.kind, "powerOrientation")] or SPARK_PATH.RIGHT
	local w, h = view.power.opts.width, view.power.opts.height
	spark:ClearAllPoints()
	spark:SetPoint("CENTER", view.power, path[1])
	spark:SetSize(Snap(view, path[2] ~= 0 and SPARK_W or w), Snap(view, path[2] ~= 0 and h or SPARK_W))
	spark.move:SetOffset(Snap(view, path[2] * w), Snap(view, path[3] * h))
	return spark
end

function Style.HealAbsorb(view)
	view.healAbsorb = Prediction(view.health, "hostile")
	PlaceHealAbsorb(view)
	return view.healAbsorb
end

local function Overlays(view, s)
	PlacePrediction(view, view.incoming, view.health:GetStatusBarTexture())
	PlacePrediction(view, view.absorb, view.incoming:GetStatusBarTexture(), nil, s.absorbPlacement)
	PlaceHealAbsorb(view)
	if view.shieldGlow then Style.ShieldGlow(view) end
	if view.absorbBar then Style.AbsorbBar(view) end
	if view.lossBar then Style.LossBar(view) end
	if view.costBar then Style.CostBar(view) end
	if view.manaSpark then Style.Spark(view) end
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
	PlaceText(view, view.powerText, g.powerText)
	view.powerText:SetJustifyH("RIGHT")
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
	local padY = view.kind == "boss" and math.min(pad[2], Settings.Value("boss", "gap") / 2) or pad[2]
	scrim:SetSize(Snap(view, g.glass.w + 2 * pad[1]), Snap(view, g.glass.h + 2 * padY))
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
	Overlays(view, s)
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

local BAR_GAP, BAR_PAD, BAR_MIN_BODY, BAR_MIN = 4, 4, 20, 8
local BAR_SLOTS = { "textBarLeft", "textBarCenter", "textBarRight" }

local function BarRoom(s, height)
	local gap = (s.textBarPlace == "BELOW" or s.textBarPlace == "ABOVE") and BAR_GAP or 0
	local h = math.min(s.textBarHeight, math.max(0, height - gap - BAR_MIN_BODY))
	if h <= 0 then return 0, 0, false end
	return h, gap, s.textBarPlace == "TOP" or s.textBarPlace == "ABOVE"
end

local function Reach(view, g, x0, x1, top, bodyH)
	local reach = 0
	for key, r in pairs(g) do
		if type(r) == "table" and r.w and key ~= "marker" and key ~= "medal" and (key ~= "aura" or r.centred) and r.x < x1 and r.x + r.w >= x0 then
			local h = key == "aura" and select(2, ns.Auras.Footprint(view.kind)) or r.h
			reach = math.max(reach, top and -r.y or r.y + h - bodyH)
		end
	end
	return reach
end

local function TextBar(view, s)
	local rect, bar = view.barRect, view.textBar
	if not (rect or bar:IsShown()) then return end
	if not rect then
		bar:Hide()
		for _, key in ipairs(BAR_SLOTS) do if view[key] then view[key]:Hide() end end
		return
	end
	if not bar then
		bar = CreateFrame("Frame", nil, view.parent)
		bar.fill = bar:CreateTexture(nil, "BACKGROUND")
		bar.fill:SetAllPoints(bar)
		bar.icon = bar:CreateTexture(nil, "ARTWORK")
		bar.inner = CreateFrame("Frame", nil, bar)
		view.textBar = bar
	end
	bar.fill:SetColorTexture(Widgets.Rgba(TRACK))
	Place(view, bar, rect)
	local strata = s.textBarStrata ~= "" and s.textBarStrata or view.parent:GetFrameStrata()
	if not issecretvalue(strata) then bar:SetFrameStrata(strata) end
	local icon, pad, size = s.textBarIcon, Snap(view, BAR_PAD), Snap(view, rect.h)
	bar.icon:ClearAllPoints()
	bar.icon:SetSize(size, size)
	bar.icon:SetPoint(icon == "RIGHT" and "RIGHT" or "LEFT", bar)
	if icon == "" then bar.icon:Hide() end
	bar.inner:ClearAllPoints()
	bar.inner:SetPoint("TOPLEFT", bar, "TOPLEFT", pad + (icon == "LEFT" and size or 0), 0)
	bar.inner:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -pad - (icon == "RIGHT" and size or 0), 0)
	local inner = math.max(0, rect.w - 2 * BAR_PAD - (icon ~= "" and rect.h or 0))
	for _, key in ipairs(BAR_SLOTS) do
		view[key] = Widgets.PlaceText(view[key], s[key], bar, bar.inner, Snap(view, inner))
	end
	bar:Show()
end

local function ExtraTexts(view, s)
	for i = 1, 2 do
		local key = "extra" .. i
		view[key] = Widgets.PlaceText(view[key], s[key], view.top, view.parent)
	end
	if view.barRect or view.textBar then TextBar(view, s) end
	view.tagged = view.extra1 or view.extra2 or view.barRect
	local align = s.powerTextAlign
	if align ~= "" or view.powerAligned then
		view.powerAligned = align ~= ""
		view.powerText:SetJustifyH(align ~= "" and align or view.form == "plate" and TEXTS.powerText.justify or "RIGHT")
		view.powerFillText:SetJustifyH(align ~= "" and align or "RIGHT")
	end
end

function Style.Layout(view, s, width, height)
	local barH, gap, top = 0, 0, false
	if s.textBar then barH, gap, top = BarRoom(s, height) end
	local bodyH = height - barH - gap
	local g = Geometry.Frame(s, width, bodyH, K.Theme.FontScale())
	view.barRect = nil
	if barH > 0 then
		local full = Geometry.Frame(s, width, height, K.Theme.FontScale())
		local w = gap > 0 and s.textBarWidth > 0 and math.min(s.textBarWidth, width) or width
		local x0, x1, m = (width - w) / 2, (width + w) / 2, g.medal
		if m and m.x + m.w / 2 < width / 2 then x0 = math.max(x0, m.x + m.w) elseif m then x1 = math.min(x1, m.x) end
		local h, need = barH - math.max(0, Reach(view, g, x0, x1, top, bodyH) - gap), BAR_MIN
		for _, key in ipairs(BAR_SLOTS) do
			if s[key].textFormat ~= "" then need = math.max(need, tonumber(s[key].size) or 0) end
		end
		if h >= math.min(barH, need) and x1 > x0 then
			view.barRect = { x = x0, y = top and 0 or height - h, w = x1 - x0, h = h }
			for key, r in pairs(g) do
				if top and type(r) == "table" and type(r.y) == "number" and (key ~= "aura" or r.centred) then r.y = r.y + barH + gap end
			end
			if g.aura and not g.aura.centred then g.aura = full.aura end
		else
			g = full
		end
	end
	view.geometry = g
	view.healthText.twoPlaces, view.healthSub.twoPlaces = s.healthValues, s.healthValues
	view.form = g.form
	if g.form ~= "plate" then
		LayoutLumen(view, g, s)
		local built = view.medallion
		ns.Slab.Layout(view, g)
		if view.nudges and not built and view.medallion then
			Style.Nudge(view)
			ns.Slab.Layout(view, g)
		end
		for _, key in ipairs({ "name", "caption", "healthText", "healthSub", "capLabel" }) do
			Widgets.TextScrim(view[key], g.form ~= "slab" and view[key]:IsShown())
		end
		ExtraTexts(view, s)
		Style.Gradient(view)
		return g
	end
	ns.Slab.Layout(view, g)
	for _, key in ipairs({ "name", "caption", "healthText", "healthSub", "capLabel" }) do
		Widgets.TextScrim(view[key], false)
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
	Overlays(view, s)
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
	ExtraTexts(view, s)
	Style.Gradient(view)
	return g
end

local function Offset(value)
	local most = Settings.OFFSET_MAX
	return type(value) == "number" and value == value and math.max(-most, math.min(most, value)) or 0
end

local function Wrap(view, text, nudge)
	if not text or text.nudge == nudge then return end
	if not nudge then
		text.SetPoint, text.nudge, text.native = text.native, nil, nil
		return
	end
	local set = text.SetPoint
	text.nudge, text.native = nudge, set
	text.SetPoint = function(self, point, rel, ...)
		if type(rel) ~= "table" or rel.nudge == nudge then return set(self, point, rel, ...) end
		local relPoint, x, y = ...
		return set(self, point, rel, relPoint or point, (x or 0) + Snap(view, nudge[1]), (y or 0) + Snap(view, nudge[2]))
	end
end

function Style.Nudge(view)
	local fonts = view.s and view.s.fonts
	if not fonts then return end
	local on = false
	for _, element in ipairs(Settings.TEXTS) do
		on = on or Offset(fonts[element].x) ~= 0 or Offset(fonts[element].y) ~= 0
	end
	if not (on or view.nudges) then return end
	local nudges = on and (view.nudges or { name = {}, health = {}, power = {}, level = {} }) or nil
	view.nudges = nudges
	for key, element in pairs(NUDGE) do
		Wrap(view, view[key], nudges and nudges[element])
	end
	Wrap(view, view.medallion and view.medallion.levelText, nudges and nudges.level)
	for element, nudge in pairs(nudges or {}) do
		nudge[1], nudge[2] = Offset(fonts[element].x), Offset(fonts[element].y)
	end
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
		if lumen and not Widgets.Readability("worldText") and (key == "caption" or key == "healthSub") then
			view[key]:SetTextColor(Lumen.Color("subLabel"))
		elseif key == "healthSub" and Widgets.Readability("worldText") then
			view[key]:SetTextColor(Tokens.Color("text"))
		elseif lumen and spec.lumenColor then
			view[key]:SetTextColor(Lumen.Color(spec.lumenColor))
		else
			view[key]:SetTextColor(Tokens.Color(spec.color))
		end
	end
	view.capRule:SetVertexColor(Lumen.Color("gold"))
	view.capRule:SetAlpha(RULE_ALPHA)
	Style.Shape(view, form == "vitals" or Settings.Value(kind, "portraitShape") == "round")
	local s, health = view.s, Settings.Value(kind, "healthTexture")
	view.health:SetBarTexture(health)
	view.power:SetBarTexture(Settings.Value(kind, "powerTexture"))
	view.incoming:SetBarTexture(s and s.incomingTexture ~= "" and s.incomingTexture or health)
	view.absorb:SetBarTexture(s and s.absorbTexture ~= "" and s.absorbTexture or health)
	Style.Nudge(view)
	view.orientation = Settings.Value(kind, "healthOrientation")
	Orient(view.health, view.orientation)
	Orient(view.power, Settings.Value(kind, "powerOrientation"))
	view.incoming:SetBarColor(Widgets.Rgba("friendly", Settings.Value(kind, "incomingAlpha")))
	view.absorb:SetBarColor(Widgets.Rgba("white", Settings.Value(kind, "absorbAlpha")))
	PlaceHealAbsorb(view)
	Widgets.Tint(view.trackLine, TRACK_LINE, TRACK_LINE_ALPHA)
	Style.Accent(view)
	ns.Slab.Restyle(view, form)
	if form == "slab" then
		local _, size, flags = Settings.Font(kind, "level")
		Widgets.ApplyFont(view.powerText, (Settings.Font(kind, "power")), size, flags)
		view.powerText:SetTextColor(Tokens.Color("labelMuted"))
	end
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
	view.healthR, view.healthG, view.healthB = nil, nil, nil
	if Plain(r, g, b) then view.healthR, view.healthG, view.healthB = r, g, b end
	if view.s and view.s.powerSeparate and view.powerR then Style.PowerTint(view, view.powerR, view.powerG, view.powerB) end
	if view.geometry and view.geometry.form == "plate" and not view.geometry.compact and Plain(r, g, b) then
		view.healthText:SetTextColor(r + (1 - r) * TINT, g + (1 - g) * TINT, b + (1 - b) * TINT)
	else
		view.healthText:SetTextColor(Tokens.Color("textEmphasis"))
	end
	Style.Gradient(view)
end

function Style.Gradient(view)
	local s, bar = view.s, view.health
	local direction, r, g, b = s and s.healthColor ~= "health" and s.healthGradient or "", view.healthR, view.healthG, view.healthB
	local texture = bar:GetStatusBarTexture()
	if direction ~= "" and r and texture and texture.SetGradient and CreateColor then
		local a = s.healthAlpha
		view.gradient = true
		texture:SetGradient(direction, CreateColor(r * GRADIENT_SHADE, g * GRADIENT_SHADE, b * GRADIENT_SHADE, a), CreateColor(r, g, b, a))
	elseif view.gradient then
		view.gradient = nil
		bar:SetBarColor(unpack(bar.colorRGBA, 1, bar.colorRGBA.n))
	end
end

local function Hue(r, g, b)
	local high, low = math.max(r, g, b), math.min(r, g, b)
	local delta = high - low
	if delta == 0 then return nil end
	if high == r then return ((g - b) / delta % 6) * 60 end
	if high == g then return ((b - r) / delta + 2) * 60 end
	return ((r - g) / delta + 4) * 60
end

function Style.PowerFill(view, r, g, b, base)
	local s, bar = view.s, view.power
	local a = s and s.powerAlpha or 1
	if a < 1 then bar:SetBarColor(r, g, b, a) elseif base then bar:SetBarColor(r, g, b, base) else bar:SetBarColor(r, g, b) end
	local direction = s and s.powerGradient or ""
	local texture = direction ~= "" and Plain(r, g, b) and bar:GetStatusBarTexture()
	if texture and texture.SetGradient and CreateColor then
		local from, to = view.powerFrom or CreateColor(r, g, b, a), view.powerTo or CreateColor(r, g, b, a)
		view.powerFrom, view.powerTo = from, to
		from.r, from.g, from.b, from.a = r * GRADIENT_SHADE, g * GRADIENT_SHADE, b * GRADIENT_SHADE, a
		to.r, to.g, to.b, to.a = r, g, b, a
		texture:SetGradient(direction, from, to)
	end
end

function Style.PowerTint(view, r, g, b)
	view.powerR, view.powerG, view.powerB = nil, nil, nil
	local separate = false
	if Plain(r, g, b) then
		view.powerR, view.powerG, view.powerB = r, g, b
		if view.s and view.s.powerSeparate and view.healthR then
			local health, power = Hue(view.healthR, view.healthG, view.healthB), Hue(r, g, b)
			if health and power then
				local gap = math.abs(health - power)
				separate = math.min(gap, 360 - gap) <= 35
			end
		end
	end
	view.powerTypeLine:SetShown(separate)
	if separate then
		view.powerTypeLine:SetColorTexture(r, g, b, 1)
		r, g, b = Tokens.Color("steelLit")
	end
	Style.PowerFill(view, r, g, b)
	local geometry = view.geometry
	local inside = geometry and geometry.form ~= "plate" and geometry.powerText and geometry.form ~= "slab"
	view.powerFillClip:SetShown(inside == true)
	if inside then
		Widgets.InkText(view.powerText, Tokens.Color(TRACK))
		local path, size = view.powerText:GetFont()
		Widgets.ApplyFont(view.powerFillText, path, size)
		Widgets.InkText(view.powerFillText, r, g, b)
	end
	Style.PowerText(view, view.typeR, view.typeG, view.typeB)
end

function Style.PowerText(view, r, g, b)
	local mode = view.s and view.s.powerTextColor
	if mode == "custom" then
		local c = view.s.powerTextCustom
		r, g, b = c.r, c.g, c.b
	elseif mode ~= "power" or r == nil then
		return
	end
	view.powerText:SetTextColor(r, g, b)
	view.powerFillText:SetTextColor(r, g, b)
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
