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
	Widgets.LogOnce("unitbar-curve-on", "unit bars: below 35% health a red fill shows, its alpha a C_CurveUtil step curve over UnitHealthPercent")
	return lowCurve
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
end

function Bar:SetBarValue(value)
	local eased = Eased()
	if eased then
		self:SetValue(value, eased)
	else
		self:SetValue(value)
	end
	if self.sparkAnim and not Motion.ReducedMotion() then
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
	local flash = not Motion.ReducedMotion()
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
	self.recent:SetStatusBarColor(Widgets.Rgba("white"))
	self.recent:GetStatusBarTexture():SetShown(self.lossOn)
	self.flash:SetColorTexture(Widgets.Rgba("white"))
	self.recentFlash:SetColorTexture(Widgets.Rgba("white"))
end

local function Paint(self)
	local gradient = self.gradients
	Gradient(self.under:GetStatusBarTexture(), gradient.lossBottom, gradient.lossTop)
	Gradient(self.recent:GetStatusBarTexture(), gradient.lossBottom, gradient.lossTop)
	Gradient(self.cleanSheen, gradient.sheenBottom, gradient.sheenTop)
	Gradient(self.cleanShade, gradient.shadeBottom, gradient.shadeTop)
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
	under.edgeSoft = Widgets.Crisp(under:CreateTexture(nil, "BACKGROUND", nil, -8))
	under.edgeHard = Widgets.Crisp(under:CreateTexture(nil, "BACKGROUND", nil, -7))
	under.track = Widgets.Crisp(under:CreateTexture(nil, "BACKGROUND", nil, -6))
	under.track:SetAllPoints(under)
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
	}
	Flash(bar)
	if opts.spark ~= false then
		Spark(bar)
	end
	Wrap(bar)
	bar:Restyle()
	return bar
end
