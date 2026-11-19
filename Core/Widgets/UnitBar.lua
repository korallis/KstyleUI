-- UnitBar.lua: the clean health and power bar (a black edge, a dark track, a shaded fill eased by the client, a pale band for health just lost, a hit flash, a spark and a low-health colour curve), driven only through widget setters so secret values are never read.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Motion = ns.Tokens, ns.Motion

local TEXTURE = "Flat"
local SHEEN_SHARE = 0.42
local SHEEN_TOP, SHEEN_BOTTOM = 0.3, 0.05
local SHADE_BOTTOM = 0.45
local HIGHLIGHT_ALPHA = 0.28
local FLASH_ALPHA = 0.85
local SPARK_PIXELS = 2
local GLOW_WIDTH = 10
local GLOW_ALPHA = 0.55
local MED_SHEEN_SHARE, MED_SHEEN_ALPHA, MED_SHADE, MED_EDGE_ALPHA = 0.3, 0.13, 0.3, 0.35
local LOW_SHARE = 0.4
local LOW_STEP = 0.001
local CHANNELS = 4

local SPARK_POINTS = {
	HORIZONTAL = { normal = { "TOPRIGHT", "BOTTOMRIGHT" }, reverse = { "TOPLEFT", "BOTTOMLEFT" } },
	VERTICAL = { normal = { "TOPLEFT", "TOPRIGHT" }, reverse = { "BOTTOMLEFT", "BOTTOMRIGHT" } },
}

local function Eased()
	if Motion.Level() == "off" then
		return nil
	end
	local enum = Enum and Enum.StatusBarInterpolation
	return enum and enum.ExponentialEaseOut
end

local function NewColor(name, alpha)
	if type(CreateColor) ~= "function" then
		return nil
	end
	local r, g, b, a = Widgets.Rgba(name)
	return CreateColor(r, g, b, alpha or a)
end

local function Gradient(texture, bottom, top)
	if not (bottom and top and type(texture.SetGradient) == "function") then
		Widgets.LogOnce("unitbar-gradient", "Texture:SetGradient or CreateColor is missing; unit bars draw without their shading")
		texture:Hide()
		return
	end
	texture:SetGradient("VERTICAL", bottom, top)
end

local lowCurve, lowTried

local function LowCurve()
	if lowTried then
		return lowCurve
	end
	lowTried = true
	local util = C_CurveUtil
	if not (util and type(util.CreateCurve) == "function" and UnitHealthPercent) then
		Widgets.LogOnce("unitbar-curve", "C_CurveUtil.CreateCurve or UnitHealthPercent is missing; low health keeps the bar's own colour")
		return nil
	end
	lowCurve = util.CreateCurve()
	local kinds = Enum and Enum.LuaCurveType
	if kinds and kinds.Step and lowCurve.SetType then
		lowCurve:SetType(kinds.Step)
	end
	lowCurve:AddPoint(0, 1)
	lowCurve:AddPoint(LOW_SHARE, 1)
	lowCurve:AddPoint(LOW_SHARE + LOW_STEP, 0)
	lowCurve:AddPoint(1, 0)
	Widgets.LogOnce("unitbar-curve-on", "unit bars: below 40% health a red fill shows, its alpha a C_CurveUtil step curve over UnitHealthPercent")
	return lowCurve
end

local textCurves = {}

local function TextCurves(token)
	local cache = token .. (Widgets.Readability("readableBars") and ":readable" or ":original")
	local curves = textCurves[cache]
	if curves ~= nil or not LowCurve() then
		return curves or nil
	end
	local low, high = { Tokens.Color("healthLowText") }, { Tokens.Color(token) }
	curves = {}
	for i = 1, 3 do
		local curve = C_CurveUtil.CreateCurve()
		local kinds = Enum and Enum.LuaCurveType
		if kinds and kinds.Step and curve.SetType then
			curve:SetType(kinds.Step)
		end
		curve:AddPoint(0, low[i])
		curve:AddPoint(LOW_SHARE, low[i])
		curve:AddPoint(LOW_SHARE + LOW_STEP, high[i])
		curve:AddPoint(1, high[i])
		curves[i] = curve
	end
	textCurves[cache] = curves
	return curves
end

Widgets.LOW_HEALTH_SHARE = LOW_SHARE
Widgets.LowHealthCurve = LowCurve

function Widgets.LowHealthText(text, unit, token)
	local curves = unit and TextCurves(token)
	if not curves then
		text:SetTextColor(Tokens.Color(token))
		return
	end
	text:SetTextColor(UnitHealthPercent(unit, true, curves[1]), UnitHealthPercent(unit, true, curves[2]), UnitHealthPercent(unit, true, curves[3]))
end

local function Restart(group)
	group:Stop()
	group:Play()
end

local Bar = {}

function Bar:ColorByHealth()
	local unit, low = self.healthUnit, self.lowFill
	local curve = unit and low and LowCurve()
	if not curve then
		if low then
			low:SetAlpha(0)
		end
		return
	end
	low:SetAlpha(UnitHealthPercent(unit, true, curve))
end

function Bar:SetHealthUnit(unit)
	self.healthUnit = unit
	self:ColorByHealth()
end

function Bar:SetBarColor(...)
	local c = self.colorRGBA
	c.n = math.min(select("#", ...), CHANNELS)
	c[1], c[2], c[3], c[4] = ...
	self.ownColor = true
	self:SetStatusBarColor(...)
	local r, g, b = c[1], c[2], c[3]
	if Widgets.Readability("barColors") and not (Widgets.IsSecret(r) or Widgets.IsSecret(g) or Widgets.IsSecret(b))
		and type(r) == "number" and type(g) == "number" and type(b) == "number" and type(CreateColor) == "function" then
		local gradient = self.gradients
		if gradient.lossR == r and gradient.lossG == g and gradient.lossB == b then
			return
		end
		gradient.lossR, gradient.lossG, gradient.lossB = r, g, b
		gradient.lossFallback = nil
		gradient.lossBottom = CreateColor(r + (1 - r) * 0.35, g + (1 - g) * 0.35, b + (1 - b) * 0.35, 0.75)
		gradient.lossTop = CreateColor(r + (1 - r) * 0.5, g + (1 - g) * 0.5, b + (1 - b) * 0.5, 0.75)
		Gradient(self.under:GetStatusBarTexture(), gradient.lossBottom, gradient.lossTop)
		Gradient(self.recent:GetStatusBarTexture(), gradient.lossBottom, gradient.lossTop)
	else
		local gradient = self.gradients
		local refined = Widgets.Readability("barColors")
		if gradient.lossFallback == refined then return end
		gradient.lossFallback = refined
		gradient.lossR, gradient.lossG, gradient.lossB = nil, nil, nil
		gradient.lossBottom, gradient.lossTop = NewColor("barLoss"), NewColor("barLossLit")
		Gradient(self.under:GetStatusBarTexture(), gradient.lossBottom, gradient.lossTop)
		Gradient(self.recent:GetStatusBarTexture(), gradient.lossBottom, gradient.lossTop)
	end
end

function Bar:SetBarValue(value)
	local eased = Eased()
	if eased then
		self:SetValue(value, eased)
	else
		self:SetValue(value)
	end
	if self.sparkAnim and Motion.Slides() then
		self.sparkFrame:Show()
		Restart(self.sparkAnim)
	end
end

function Bar:SetBarRange(low, high)
	self:SetMinMaxValues(low, high)
	self.under:SetMinMaxValues(low, high)
	self.recent:SetMinMaxValues(low, high)
end

function Bar:ReleaseLoss()
	local eased = Eased()
	if eased then
		self.under:SetValue(self.lossValue, eased)
		self.recent:SetValue(self.lossValue, eased)
	else
		self.under:SetValue(self.lossValue)
		self.recent:SetValue(self.lossValue)
	end
end

function Bar:SetHealth(value, instant)
	if instant or not (self.lossOn and self.lossKnown) or not Eased() then
		self:SetValue(value)
		self.under:SetValue(value)
		self.recent:SetValue(value)
		self.lossValue, self.lossKnown = value, true
		self.lossAnim:Stop()
		self.flash:Hide()
		self.recentAnim:Stop()
		self.recentFlash:Hide()
		if self.sparkAnim then
			self.sparkAnim:Stop()
			self.sparkFrame:Hide()
		end
		self:ColorByHealth()
		return
	end
	if not self.lossAnim:IsPlaying() then
		self.under:SetValue(self.lossValue)
	end
	self.recent:SetValue(self.lossValue)
	self.lossValue = value
	self:SetBarValue(value)
	local flash = Motion.Fades()
	if self.flashMotion ~= Motion.Level() then
		self.flashMotion = Motion.Level()
		local hit = Motion.FadeDuration(Tokens.Duration("hitFlash"))
		self.lossFade:SetDuration(hit)
		self.recentFade:SetDuration(hit)
		self.lossHold:SetDuration(Motion.Slides() and math.max(Tokens.Duration("lossHold"), hit) or hit)
	end
	self.flash:SetShown(flash)
	self.recentFlash:SetShown(flash)
	Restart(self.lossAnim)
	Restart(self.recentAnim)
	self:ColorByHealth()
end

function Bar:SetLoss(on)
	self.lossOn = on ~= false
	if not self.lossOn then
		self.lossAnim:Stop()
		self.flash:Hide()
		self.recentAnim:Stop()
		self.recentFlash:Hide()
		self.lossKnown = false
	end
	self.under:GetStatusBarTexture():SetShown(self.lossOn)
	self.recent:GetStatusBarTexture():SetShown(self.lossOn)
end

local function Reversed(self)
	local reverse = self:GetReverseFill()
	return not Widgets.IsSecret(reverse) and reverse == true
end

local function Span(self, getter, fallback)
	local value = self[getter](self)
	if type(value) ~= "number" or Widgets.IsSecret(value) or value <= 0 then
		return fallback
	end
	return value
end

local function PlaceSpark(self)
	if not self.sparkFrame then
		return
	end
	local points = SPARK_POINTS[self.vertical and "VERTICAL" or "HORIZONTAL"][Reversed(self) and "reverse" or "normal"]
	local fill, px = self:GetStatusBarTexture(), Widgets.Border(self)
	local line, glow = self.sparkLine, self.sparkGlow
	line:ClearAllPoints()
	line:SetPoint(points[1], fill, points[1])
	line:SetPoint(points[2], fill, points[2])
	glow:ClearAllPoints()
	glow:SetPoint("CENTER", line, "CENTER")
	local width = Span(self, "GetWidth", self.opts.width or Tokens.Size("buffBarWidth"))
	local height = Span(self, "GetHeight", self.opts.height or Tokens.Size("buffBarHeight"))
	if self.vertical then
		line:SetHeight(px * SPARK_PIXELS)
		glow:SetSize(Widgets.Snap(self, width), Widgets.Snap(self, GLOW_WIDTH))
	else
		line:SetWidth(px * SPARK_PIXELS)
		glow:SetSize(Widgets.Snap(self, GLOW_WIDTH), Widgets.Snap(self, height))
	end
	line:SetColorTexture(Widgets.Rgba("white"))
	glow:SetVertexColor(Widgets.Rgba("white", GLOW_ALPHA))
end

local function Clip(owner, fill)
	local clip = CreateFrame("Frame", nil, owner)
	clip:SetClipsChildren(true)
	clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
	clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
	return clip
end

local function PlaceFill(self)
	local px = Widgets.Border(self)
	local height = Span(self, "GetHeight", self.opts.height or Tokens.Size("buffBarHeight"))
	local sheen, shade, lit = self.cleanSheen, self.cleanShade, self.cleanLit
	local span = self.vertical and self:GetStatusBarTexture() or self
	sheen:ClearAllPoints()
	shade:ClearAllPoints()
	lit:ClearAllPoints()
	sheen:SetShown(not self.vertical)
	shade:SetShown(not self.vertical)
	if self.finish == "medallions" and not self.vertical then
		local fill, side = self:GetStatusBarTexture(), Reversed(self) and "LEFT" or "RIGHT"
		lit:SetPoint("TOP" .. side, fill, "TOP" .. side)
		lit:SetPoint("BOTTOM" .. side, fill, "BOTTOM" .. side)
		lit:SetWidth(px)
		lit:SetColorTexture(Widgets.Rgba("white", MED_EDGE_ALPHA))
		sheen:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -px)
		sheen:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -px)
		sheen:SetHeight(Widgets.Snap(self, height * MED_SHEEN_SHARE))
		shade:SetAllPoints(self)
		return
	end
	lit:SetPoint("TOPLEFT", span, "TOPLEFT")
	lit:SetPoint("TOPRIGHT", span, "TOPRIGHT")
	lit:SetHeight(px)
	lit:SetColorTexture(Widgets.Rgba("white", HIGHLIGHT_ALPHA))
	sheen:SetPoint("TOPLEFT", self, "TOPLEFT")
	sheen:SetPoint("TOPRIGHT", self, "TOPRIGHT")
	sheen:SetHeight(Widgets.Snap(self, height * SHEEN_SHARE))
	shade:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT")
	shade:SetPoint("TOPRIGHT", sheen, "BOTTOMRIGHT")
end

local function PlaceUnder(self)
	local under = self.under
	Widgets.BarEdge(under)
	under:SetStatusBarColor(Widgets.Rgba("white"))
	under:GetStatusBarTexture():SetShown(self.lossOn)
	self.recent:SetStatusBarColor(Widgets.Rgba("white"))
	self.recent:GetStatusBarTexture():SetShown(self.lossOn)
	self.flash:SetColorTexture(Widgets.Rgba("white"))
	self.recentFlash:SetColorTexture(Widgets.Rgba("white"))
end

local function Paint(self)
	local gradient = self.gradients
	Gradient(self.under:GetStatusBarTexture(), gradient.lossBottom, gradient.lossTop)
	Gradient(self.recent:GetStatusBarTexture(), gradient.lossBottom, gradient.lossTop)
	if self.finish == "medallions" then
		Gradient(self.cleanSheen, gradient.medSheen, gradient.medSheen)
		Gradient(self.cleanShade, gradient.medShade, gradient.shadeTop)
		return
	end
	Gradient(self.cleanSheen, gradient.sheenBottom, gradient.sheenTop)
	Gradient(self.cleanShade, gradient.shadeBottom, gradient.shadeTop)
end

function Bar:SetFinish(finish)
	if self.finish == finish then
		return
	end
	self.finish = finish
	PlaceUnder(self)
	PlaceFill(self)
	Paint(self)
end

local function SyncLevels(self)
	local parent = self.under:GetParent()
	local base = parent and parent:GetFrameLevel() or 0
	self.under:SetFrameLevel(base + 1)
	self.underClip:SetFrameLevel(base + 1)
	self.recent:SetFrameLevel(base + 2)
	self.recentClip:SetFrameLevel(base + 2)
	self:SetFrameLevel(base + 3)
	self.fillClip:SetFrameLevel(base + 4)
	if self.sparkFrame then
		self.sparkFrame:SetFrameLevel(base + 5)
	end
end

local function Wrap(bar)
	local restyle, setOrientation, setReverse = bar.Restyle, bar.SetOrientation, bar.SetReverseFill
	local show, hide, setShown = bar.Show, bar.Hide, bar.SetShown
	bar.Restyle = function(self)
		restyle(self)
		SyncLevels(self)
		PlaceUnder(self)
		PlaceFill(self)
		PlaceSpark(self)
		if self.ownColor then self:SetBarColor(unpack(self.colorRGBA, 1, self.colorRGBA.n)) end
		Paint(self)
		self:ColorByHealth()
	end
	bar.SetOrientation = function(self, orientation, ...)
		setOrientation(self, orientation, ...)
		self.under:SetOrientation(orientation, ...)
		self.recent:SetOrientation(orientation, ...)
		self.vertical = orientation == "VERTICAL"
		PlaceFill(self)
		PlaceSpark(self)
	end
	bar.SetReverseFill = function(self, ...)
		setReverse(self, ...)
		self.under:SetReverseFill(...)
		self.recent:SetReverseFill(...)
		PlaceFill(self)
		PlaceSpark(self)
	end
	bar.Show = function(self)
		show(self)
		self.under:Show()
		SyncLevels(self)
	end
	bar.Hide = function(self)
		hide(self)
		self.under:Hide()
		if self.sparkFrame then
			self.sparkFrame:Hide()
		end
	end
	bar.SetShown = function(self, shown)
		setShown(self, shown)
		self.under:SetShown(shown)
		if self.sparkFrame and not shown then
			self.sparkFrame:Hide()
		end
	end
end

local function Under(bar, parent)
	local under = CreateFrame("StatusBar", nil, parent)
	under:SetAllPoints(bar)
	under:SetStatusBarTexture((Tokens.Texture("barFlat")))
	under:SetOrientation(bar.vertical and "VERTICAL" or "HORIZONTAL")
	under:SetReverseFill(Reversed(bar))
	local edge = Widgets.BarEdge(under)
	edge.bar = bar
	under.edgeSoft, under.edgeHard, under.track = edge.soft, edge.hard, edge.track
	local restyle = edge.Restyle
	edge.Restyle = function(self)
		restyle(self)
		self.soft:SetShown(bar.finish ~= "medallions")
		self.hard:SetVertexColor(Widgets.Rgba("white"))
		self.hard:SetColorTexture(Widgets.Rgba("black"))
		Widgets.Tint(self.track, bar.finish == "medallions" and "medFillBottom" or "barTrack")
	end
	under:SetMinMaxValues(0, 1)
	under:SetValue(0)
	local recent = CreateFrame("StatusBar", nil, under)
	recent:SetAllPoints(under)
	recent:SetStatusBarTexture((Tokens.Texture("barFlat")))
	recent:SetOrientation(bar.vertical and "VERTICAL" or "HORIZONTAL")
	recent:SetReverseFill(Reversed(bar))
	recent:SetMinMaxValues(0, 1)
	recent:SetValue(0)

	bar.recent = recent
	return under
end

local function Flash(bar)
	bar.underClip = Clip(bar.under, bar.under:GetStatusBarTexture())
	local flash = bar.underClip:CreateTexture(nil, "ARTWORK", nil, 1)
	flash:SetAllPoints(bar.under)
	flash:Hide()
	local group = flash:CreateAnimationGroup()
	local hit = Tokens.Duration("hitFlash")
	local fade = group:CreateAnimation("Alpha")
	fade:SetFromAlpha(FLASH_ALPHA)
	fade:SetToAlpha(0)
	fade:SetDuration(hit)
	local hold = group:CreateAnimation("Translation")
	hold:SetOffset(0, 0)
	hold:SetDuration(math.max(Tokens.Duration("lossHold"), hit))
	group:SetScript("OnFinished", function()
		flash:Hide()
		bar:ReleaseLoss()
	end)
	Motion.TrackGroup(group)
	bar.lossFade, bar.lossHold = fade, hold
	bar.flash, bar.lossAnim = flash, group
	bar.recentClip = Clip(bar.recent, bar.recent:GetStatusBarTexture())
	local recentFlash = bar.recentClip:CreateTexture(nil, "ARTWORK", nil, 1)
	recentFlash:SetAllPoints(bar.recent)
	recentFlash:Hide()
	local recentGroup = recentFlash:CreateAnimationGroup()
	local recentFade = recentGroup:CreateAnimation("Alpha")
	recentFade:SetFromAlpha(FLASH_ALPHA)
	recentFade:SetToAlpha(0)
	recentFade:SetDuration(hit)
	recentGroup:SetScript("OnFinished", function()
		recentFlash:Hide()
	end)
	Motion.TrackGroup(recentGroup)
	bar.recentFade = recentFade
	bar.recentFlash, bar.recentAnim = recentFlash, recentGroup
end

local function Spark(bar)
	local frame = CreateFrame("Frame", nil, bar:GetParent())
	frame:SetAllPoints(bar)
	frame:Hide()
	local line = Widgets.Crisp(frame:CreateTexture(nil, "OVERLAY", nil, 2))
	local glow = frame:CreateTexture(nil, "OVERLAY", nil, 1)
	glow:SetTexture((Tokens.Texture("glow")))
	glow:SetBlendMode("ADD")
	local group = frame:CreateAnimationGroup()
	local off = group:CreateAnimation("Alpha")
	off:SetStartDelay(Tokens.Duration("sparkHold"))
	off:SetFromAlpha(1)
	off:SetToAlpha(0)
	off:SetDuration(Tokens.Duration("sparkFade"))
	group:SetScript("OnFinished", function()
		frame:Hide()
	end)
	Motion.TrackGroup(group)
	bar.sparkFrame, bar.sparkLine, bar.sparkGlow, bar.sparkAnim = frame, line, glow, group
end

function Widgets.UnitBar(parent, opts)
	opts = opts or {}
	local bar = Widgets.StatusBar(parent, {
		name = opts.name, width = opts.width, height = opts.height, color = opts.color, orientation = opts.orientation,
		reverse = opts.reverse, texture = opts.texture or TEXTURE, background = false, smooth = true,
	})
	for key, fn in pairs(Bar) do
		bar[key] = fn
	end
	bar.unitBar = true
	bar.lowHealth = opts.lowHealth == true
	bar.lossOn = opts.loss ~= false
	bar.lossKnown = false
	bar.under = Under(bar, bar:GetParent())
	local clip = Clip(bar, bar:GetStatusBarTexture())
	bar.fillClip = clip
	bar.cleanSheen = clip:CreateTexture(nil, "ARTWORK", nil, 2)
	bar.cleanSheen:SetColorTexture(Widgets.Rgba("white"))
	bar.cleanShade = clip:CreateTexture(nil, "ARTWORK", nil, 2)
	bar.cleanShade:SetColorTexture(Widgets.Rgba("white"))
	bar.cleanLit = Widgets.Crisp(clip:CreateTexture(nil, "ARTWORK", nil, 3))
	if bar.lowHealth then
		bar.lowFill = clip:CreateTexture(nil, "ARTWORK", nil, 1)
		bar.lowFill:SetAllPoints(bar)
		bar.lowFill:SetColorTexture(Widgets.Rgba("healthLow"))
		bar.lowFill:SetAlpha(0)
	end
	bar.gradients = {
		lossBottom = NewColor("barLoss"), lossTop = NewColor("barLossLit"),
		sheenBottom = NewColor("white", SHEEN_BOTTOM), sheenTop = NewColor("white", SHEEN_TOP),
		shadeBottom = NewColor("black", SHADE_BOTTOM), shadeTop = NewColor("black", 0),
		medSheen = NewColor("white", MED_SHEEN_ALPHA), medShade = NewColor("black", MED_SHADE),
	}
	Flash(bar)
	if opts.spark ~= false then
		Spark(bar)
	end
	Wrap(bar)
	bar:Restyle()
	return bar
end
