-- Medallion.lua: the round unit medallion, a portrait or badge in a steel bezel with a class or reaction enamel ring, a level plaque, a low-health ring whose alpha is a health curve, an idle sheen and a flip-in, all drawn by the engine with no per-frame Lua.
local _, ns = ...

local Widgets, Tokens, Motion = ns.Widgets, ns.Tokens, ns.Motion

local PORTRAIT_SHARE = 0.8
local PLAQUE_SHARE, PLAQUE_MIN = 0.27, 12
local PLAQUE_ALONG, PLAQUE_DOWN = 0.18, 0.86
local PLAQUE_FONT = 0.46
local LOW_SPREAD = 1.3
local SHEEN_ALPHA = 0.45
local FLIP, FLIP_FROM = 0.18, 0.05
local PULSE, PULSE_LOW = 0.4, 0.45
local SHEEN, SHEEN_PERIOD = 1.75, 5
local LEVEL_PLAQUE, LEVEL_RING = 2, 1
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local DEAD_TINT = 0.45

local function Allows(kind)
	local effects = ns.Effects
	if effects and effects.Allows then
		return effects.Allows(kind) == true
	end
	if kind == "pulse" then
		return not Motion.ReducedMotion()
	end
	return Motion.Level() ~= "off"
end

local Medallion = {}

local function Snap(self, units)
	return Widgets.Snap(self, units)
end

local function NewFlip(self)
	local group = self:CreateAnimationGroup()
	local scale = group:CreateAnimation("Scale")
	scale:SetScaleFrom(FLIP_FROM, 1)
	scale:SetScaleTo(1, 1)
	scale:SetOrigin("CENTER", 0, 0)
	scale:SetDuration(FLIP)
	scale:SetSmoothing("OUT")
	local alpha = group:CreateAnimation("Alpha")
	alpha:SetFromAlpha(0)
	alpha:SetToAlpha(1)
	alpha:SetDuration(FLIP)
	group:SetToFinalAlpha(true)
	return group
end

local function NewPulse(frame)
	local group = frame:CreateAnimationGroup()
	group:SetLooping("BOUNCE")
	local alpha = group:CreateAnimation("Alpha")
	alpha:SetFromAlpha(1)
	alpha:SetToAlpha(PULSE_LOW)
	alpha:SetDuration(PULSE)
	alpha:SetSmoothing("IN_OUT")
	return group
end

local function NewSheen(texture)
	local group = texture:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	local move = group:CreateAnimation("Translation")
	move:SetDuration(SHEEN)
	move:SetStartDelay(SHEEN_PERIOD - SHEEN)
	move:SetSmoothing("IN_OUT")
	group.move = move
	return group
end

function Widgets.Medallion(parent)
	local m = CreateFrame("Frame", nil, parent)
	for key, fn in pairs(Medallion) do
		m[key] = fn
	end
	m.portrait = m:CreateTexture(nil, "BORDER")
	m.mask = m:CreateMaskTexture()
	m.mask:SetTexture((Tokens.Texture("dot")), MASK_WRAP, MASK_WRAP)
	m.mask:SetAllPoints(m.portrait)
	m.portrait:AddMaskTexture(m.mask)
	m.portrait:SetPoint("CENTER", m, "CENTER")
	m.sheen = m:CreateTexture(nil, "ARTWORK")
	m.sheen:SetTexture((Tokens.Texture("medPortraitSheen")))
	m.sheen:SetBlendMode("ADD")
	m.sheen:SetAlpha(SHEEN_ALPHA)
	m.sheen:AddMaskTexture(m.mask)
	m.sheen:Hide()
	m.sheenAnim = NewSheen(m.sheen)
	m.enamel = m:CreateTexture(nil, "OVERLAY", nil, 0)
	m.enamel:SetTexture((Tokens.Texture("medEnamel")))
	m.enamel:SetAllPoints(m)
	m.ring = m:CreateTexture(nil, "OVERLAY", nil, 1)
	m.ring:SetTexture((Tokens.Texture("medRing")))
	m.ring:SetAllPoints(m)
	m.lowFrame = CreateFrame("Frame", nil, m)
	m.lowFrame:SetPoint("CENTER", m, "CENTER")
	m.low = m.lowFrame:CreateTexture(nil, "OVERLAY")
	m.low:SetTexture((Tokens.Texture("medLowHealthRing")))
	m.low:SetBlendMode("ADD")
	m.low:SetAllPoints(m.lowFrame)
	m.lowFrame:Hide()
	m.pulse = NewPulse(m.lowFrame)
	m.plaque = CreateFrame("Frame", nil, m)
	m.plaqueArt = m.plaque:CreateTexture(nil, "BACKGROUND")
	m.plaqueArt:SetTexture((Tokens.Texture("medLevelPlaque")))
	m.plaqueArt:SetAllPoints(m.plaque)
	m.levelText = Widgets.FontString(m.plaque, "OVERLAY")
	m.levelText:SetJustifyH("CENTER")
	m.levelText:SetJustifyV("MIDDLE")
	m.levelText:SetWordWrap(false)
	m.levelText:SetTextColor(Tokens.Color("steelLit"))
	m.plaque:Hide()
	m.flip = NewFlip(m)
	m.size = 0
	m:SetRingColor(Tokens.Color("steel"))
	return m
end

function Medallion:Layout(size, plaqueSide)
	self.size = size
	local level = self:GetFrameLevel()
	self.lowFrame:SetFrameLevel(level + LEVEL_RING)
	self.plaque:SetFrameLevel(level + LEVEL_PLAQUE)
	local inner = Snap(self, size * PORTRAIT_SHARE)
	self.portrait:SetSize(inner, inner)
	local spread = Snap(self, size * LOW_SPREAD)
	self.lowFrame:SetSize(spread, spread)
	self.sheen:ClearAllPoints()
	self.sheen:SetSize(inner, inner)
	self.sheen:SetPoint("CENTER", self.portrait, "CENTER", -inner, 0)
	self.sheenAnim.move:SetOffset(2 * inner, 0)
	if not plaqueSide then
		self.plaque:Hide()
		return
	end
	local s = math.max(PLAQUE_MIN, Snap(self, size * PLAQUE_SHARE))
	local along = plaqueSide == "RIGHT" and 1 - PLAQUE_ALONG or PLAQUE_ALONG
	self.plaque:ClearAllPoints()
	self.plaque:SetPoint("CENTER", self, "TOPLEFT", Snap(self, size * along), -Snap(self, size * PLAQUE_DOWN))
	self.plaque:SetSize(s, s)
	self.levelText:ClearAllPoints()
	self.levelText:SetPoint("CENTER", self.plaque, "CENTER")
	self.levelText:SetSize(s, s)
	Widgets.ApplyFont(self.levelText, (Tokens.Font("number")), math.max(1, s * PLAQUE_FONT), "")
	self.plaque:Show()
end

function Medallion:SetUnit(unit, cut)
	return ns.Medallions.Portrait(self.portrait, unit, cut)
end

function Medallion:SetRingColor(r, g, b)
	self.enamel:SetVertexColor(r, g, b, 1)
end

function Medallion:SetLevel(level)
	self.levelText:SetText(level)
end

function Medallion:SetDead(dead)
	local on = dead == true
	self.portrait:SetDesaturated(on)
	local shade = on and DEAD_TINT or 1
	self.portrait:SetVertexColor(shade, shade, shade, 1)
end

function Medallion:LowHealth(unit)
	local curve = unit and UnitHealthPercent and Widgets.LowHealthCurve()
	if not curve then
		self.pulse:Stop()
		self.lowFrame:Hide()
		return
	end
	self.low:SetAlpha(UnitHealthPercent(unit, true, curve))
	self.lowFrame:Show()
	if not Allows("pulse") then
		self.pulse:Stop()
	elseif not self.pulse:IsPlaying() then
		self.pulse:Play()
	end
end

function Medallion:Sheen(on)
	local want = on == true and Allows("ambient")
	self.sheen:SetShown(want)
	if want and not self.sheenAnim:IsPlaying() then
		self.sheenAnim:Play()
	elseif not want then
		self.sheenAnim:Stop()
	end
end

function Medallion:FlipIn()
	if not Allows("flare") then
		return
	end
	self.flip:Stop()
	self.flip:Play()
end
