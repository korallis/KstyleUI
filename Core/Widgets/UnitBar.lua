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
local LOW_SHARE = 0.35
local LOW_STEP = 0.001
local CHANNELS = 4
local MIN_HOLD = 0.01

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

local function Plain(r, g, b)
	if Widgets.IsSecret(r) or Widgets.IsSecret(g) or Widgets.IsSecret(b) then
		return false
	end
	return type(r) == "number" and type(g) == "number" and type(b) == "number"
end

local curves = {}

local function LowCurve(r, g, b)
	local util = C_CurveUtil
	if not (util and type(util.CreateColorCurve) == "function" and type(CreateColor) == "function" and UnitHealthPercent) then
		Widgets.LogOnce("unitbar-curve", "C_CurveUtil.CreateColorCurve or UnitHealthPercent is missing; low health keeps the bar's own colour")
		return nil
	end
	local key = string.format("%.3f:%.3f:%.3f", r, g, b)
	local curve = curves[key]
	if curve then
		return curve
	end
	curve = util.CreateColorCurve()
	local kinds = Enum and Enum.LuaCurveType
	if kinds and kinds.Step and curve.SetType then
		curve:SetType(kinds.Step)
	end
	local low, base = NewColor("healthLow"), CreateColor(r, g, b, 1)
	curve:AddPoint(0, low)
	curve:AddPoint(LOW_SHARE, low)
	curve:AddPoint(LOW_SHARE + LOW_STEP, base)
	curve:AddPoint(1, base)
	curves[key] = curve
	Widgets.LogOnce("unitbar-curve-on", "unit bars: low health turns the bar red through a C_CurveUtil step curve over UnitHealthPercent")
	return curve
end

local function Restart(group)
	group:Stop()
	group:Play()
end

local Bar = {}

function Bar:ColorByHealth()
	local unit, curve = self.healthUnit, self.curve
	if not (unit and curve) then
		return
	end
	local color = UnitHealthPercent(unit, true, curve)
	if color and not Widgets.IsSecret(color) then
		self:SetStatusBarColor(color:GetRGBA())
	end
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
	self.curve = self.lowHealth and Plain(r, g, b) and LowCurve(r, g, b) or nil
	self:ColorByHealth()
end

function Bar:SetBarValue(value)
	local eased = Eased()
	if eased then
		self:SetValue(value, eased)
	else
		self:SetValue(value)
	end
	if self.sparkAnim and not Motion.ReducedMotion() then
		Restart(self.sparkAnim)
	end
end

function Bar:SetBarRange(low, high)
	self:SetMinMaxValues(low, high)
	self.under:SetMinMaxValues(low, high)
end

function Bar:ReleaseLoss()
	local eased = Eased()
	if eased then
		self.under:SetValue(self.lossValue, eased)
	else
		self.under:SetValue(self.lossValue)
	end
end

function Bar:SetHealth(value, instant)
	if instant or not (self.lossOn and self.lossKnown) or not Eased() then
		self:SetValue(value)
		self.under:SetValue(value)
		self.lossValue, self.lossKnown = value, true
		self.lossAnim:Stop()
		if self.sparkAnim then
			self.sparkAnim:Stop()
		end
		self:ColorByHealth()
		return
	end
	self.under:SetValue(self.lossValue)
	self.lossValue = value
	self:SetBarValue(value)
	Restart(self.lossAnim)
	self:ColorByHealth()
end

function Bar:SetLoss(on)
	self.lossOn = on ~= false
	if not self.lossOn then
		self.lossAnim:Stop()
		self.lossKnown = false
	end
	self.under:GetStatusBarTexture():SetShown(self.lossOn)
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

local function PlaceFill(self)
	local fill, px = self:GetStatusBarTexture(), Widgets.Border(self)
	local height = Span(self, "GetHeight", self.opts.height or Tokens.Size("buffBarHeight"))
	local sheen, shade, lit = self.cleanSheen, self.cleanShade, self.cleanLit
	sheen:ClearAllPoints()
	shade:ClearAllPoints()
	lit:ClearAllPoints()
	sheen:SetShown(not self.vertical)
	shade:SetShown(not self.vertical)
	lit:SetPoint("TOPLEFT", fill, "TOPLEFT")
	lit:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
	lit:SetHeight(px)
	lit:SetColorTexture(Widgets.Rgba("white", HIGHLIGHT_ALPHA))
	sheen:SetPoint("TOPLEFT", fill, "TOPLEFT")
	sheen:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
	sheen:SetHeight(Widgets.Snap(self, height * SHEEN_SHARE))
	shade:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT")
	shade:SetPoint("TOPRIGHT", sheen, "BOTTOMRIGHT")
end

local function PlaceUnder(self)
	local under, px = self.under, Widgets.Border(self)
	local soft, hard = under.edgeSoft, under.edgeHard
	soft:ClearAllPoints()
	soft:SetPoint("TOPLEFT", self, "TOPLEFT", -2 * px, 2 * px)
	soft:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 2 * px, -2 * px)
	soft:SetColorTexture(Widgets.Rgba("barEdgeSoft"))
	hard:ClearAllPoints()
	hard:SetPoint("TOPLEFT", self, "TOPLEFT", -px, px)
	hard:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", px, -px)
	hard:SetColorTexture(Widgets.Rgba("black"))
	under.track:SetColorTexture(Widgets.Rgba("barTrack"))
	under:SetStatusBarColor(Widgets.Rgba("white"))
	under:GetStatusBarTexture():SetShown(self.lossOn)
	self.flash:SetColorTexture(Widgets.Rgba("white"))
	self.flashFade:SetFromAlpha(Motion.ReducedMotion() and 0 or FLASH_ALPHA)
end

local function Paint(self)
	local gradient = self.gradients
	Gradient(self.under:GetStatusBarTexture(), gradient.lossBottom, gradient.lossTop)
	Gradient(self.cleanSheen, gradient.sheenBottom, gradient.sheenTop)
	Gradient(self.cleanShade, gradient.shadeBottom, gradient.shadeTop)
end

local function Wrap(bar)
	local restyle, setOrientation, setReverse = bar.Restyle, bar.SetOrientation, bar.SetReverseFill
	local show, hide, setShown = bar.Show, bar.Hide, bar.SetShown
	bar.Restyle = function(self)
		restyle(self)
		PlaceUnder(self)
		PlaceFill(self)
		PlaceSpark(self)
		Paint(self)
		self:ColorByHealth()
	end
	bar.SetOrientation = function(self, orientation, ...)
		setOrientation(self, orientation, ...)
		self.under:SetOrientation(orientation, ...)
		self.vertical = orientation == "VERTICAL"
		PlaceFill(self)
		PlaceSpark(self)
	end
	bar.SetReverseFill = function(self, ...)
		setReverse(self, ...)
		self.under:SetReverseFill(...)
		PlaceSpark(self)
	end
	bar.Show = function(self)
		show(self)
		self.under:Show()
	end
	bar.Hide = function(self)
		hide(self)
		self.under:Hide()
	end
	bar.SetShown = function(self, shown)
		setShown(self, shown)
		self.under:SetShown(shown)
	end
end

local function Under(bar, parent)
	local under = CreateFrame("StatusBar", nil, parent)
	under:SetAllPoints(bar)
	under:SetStatusBarTexture((Tokens.Texture("barFlat")))
	under:SetOrientation(bar.vertical and "VERTICAL" or "HORIZONTAL")
	under:SetReverseFill(Reversed(bar))
	under.edgeSoft = Widgets.Crisp(under:CreateTexture(nil, "BACKGROUND", nil, -8))
	under.edgeHard = Widgets.Crisp(under:CreateTexture(nil, "BACKGROUND", nil, -7))
	under.track = Widgets.Crisp(under:CreateTexture(nil, "BACKGROUND", nil, -6))
	under.track:SetAllPoints(under)
	under:SetMinMaxValues(0, 1)
	under:SetValue(0)
	bar:SetFrameLevel(under:GetFrameLevel() + 1)
	return under
end

local function Flash(bar)
	local flash = bar.under:CreateTexture(nil, "ARTWORK", nil, 1)
	flash:SetAllPoints(bar.under:GetStatusBarTexture())
	flash:SetAlpha(0)
	local group = flash:CreateAnimationGroup()
	group:SetToFinalAlpha(true)
	local fade = group:CreateAnimation("Alpha")
	fade:SetOrder(1)
	fade:SetFromAlpha(FLASH_ALPHA)
	fade:SetToAlpha(0)
	fade:SetDuration(Tokens.Duration("hitFlash"))
	local hold = group:CreateAnimation("Alpha")
	hold:SetOrder(2)
	hold:SetFromAlpha(0)
	hold:SetToAlpha(0)
	hold:SetDuration(math.max(Tokens.Duration("lossHold") - Tokens.Duration("hitFlash"), MIN_HOLD))
	group:SetScript("OnFinished", function()
		bar:ReleaseLoss()
	end)
	bar.flash, bar.flashFade, bar.lossAnim = flash, fade, group
end

local function Spark(bar)
	local frame = CreateFrame("Frame", nil, bar)
	frame:SetAllPoints(bar)
	frame:SetAlpha(0)
	local line = Widgets.Crisp(frame:CreateTexture(nil, "OVERLAY", nil, 2))
	local glow = frame:CreateTexture(nil, "OVERLAY", nil, 1)
	glow:SetTexture((Tokens.Texture("glow")))
	glow:SetBlendMode("ADD")
	local group = frame:CreateAnimationGroup()
	group:SetToFinalAlpha(true)
	local on = group:CreateAnimation("Alpha")
	on:SetOrder(1)
	on:SetFromAlpha(1)
	on:SetToAlpha(1)
	on:SetDuration(Tokens.Duration("sparkHold"))
	local off = group:CreateAnimation("Alpha")
	off:SetOrder(2)
	off:SetFromAlpha(1)
	off:SetToAlpha(0)
	off:SetDuration(Tokens.Duration("sparkFade"))
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
	bar.cleanSheen = bar:CreateTexture(nil, "ARTWORK", nil, 2)
	bar.cleanSheen:SetColorTexture(Widgets.Rgba("white"))
	bar.cleanShade = bar:CreateTexture(nil, "ARTWORK", nil, 2)
	bar.cleanShade:SetColorTexture(Widgets.Rgba("white"))
	bar.cleanLit = Widgets.Crisp(bar:CreateTexture(nil, "ARTWORK", nil, 3))
	bar.gradients = {
		lossBottom = NewColor("barLoss"), lossTop = NewColor("barLossLit"),
		sheenBottom = NewColor("white", SHEEN_BOTTOM), sheenTop = NewColor("white", SHEEN_TOP),
		shadeBottom = NewColor("black", SHADE_BOTTOM), shadeTop = NewColor("black", 0),
	}
	Flash(bar)
	if opts.spark ~= false then
		Spark(bar)
	end
	Wrap(bar)
	bar:Restyle()
	return bar
end
