-- Medallion.lua: the round unit medallion, a portrait or badge in a steel bezel with a class or reaction enamel ring, a level plaque, a low-health ring whose alpha is a health curve, an idle sheen and a flip-in, all drawn by the engine with no per-frame Lua.
local _, ns = ...

local Widgets, Tokens, Motion, Scale = ns.Widgets, ns.Tokens, ns.Motion, ns.Scale

local PORTRAIT_SHARE = 0.82
local PLAQUE_SHARE = 16 / 86
local PLAQUE_ALONG, PLAQUE_DOWN = 0.5 - 0.5 * math.sqrt(0.5), 0.5 + 0.5 * math.sqrt(0.5)
local PLAQUE_FONT, LEVEL_FLOOR = 0.6, 9
local LOW_SPREAD, OLD_LOW_SPREAD = 1.12, 1.3
local SHOW_LOW = { player = true }
local SHEEN_ALPHA = 0.45
local FLIP, FLIP_FROM = 0.18, 0.05
local PULSE, PULSE_LOW = 0.4, 0.45
local SHEEN, SHEEN_PERIOD = 1.75, 5
local LEVEL_PLAQUE, LEVEL_RING = 2, 1
local BURST, BURST_SHARE, BURST_FROM, BURST_TO, BURST_RISE = 1.2, 2.2, 0.6, 1.15, 0.2
local CLASS_WORD = {
	DRUID = "Druid", HUNTER = "Hunter", MAGE = "Mage", PALADIN = "Paladin", PRIEST = "Priest",
	ROGUE = "Rogue", SHAMAN = "Shaman", WARLOCK = "Warlock", WARRIOR = "Warrior",
}
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

local dangerCurve
local function DangerCurve()
	if not dangerCurve and C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function" and UnitHealthPercent then
		dangerCurve = C_CurveUtil.CreateCurve()
		if dangerCurve.SetType and Enum and Enum.LuaCurveType then dangerCurve:SetType(Enum.LuaCurveType.Linear) end
		dangerCurve:AddPoint(0, 0.7)
		dangerCurve:AddPoint(0.15, 0.7)
		dangerCurve:AddPoint(0.4, 0)
		dangerCurve:AddPoint(1, 0)
	end
	return dangerCurve
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
	self.lowFrame:SetFrameLevel(level + (self.cleanLow and 0 or LEVEL_RING))
	self.plaque:SetFrameLevel(level + LEVEL_PLAQUE)
	local inner = Snap(self, size * PORTRAIT_SHARE)
	self.portrait:SetSize(inner, inner)
	local spread = Snap(self, size * (self.cleanLow and LOW_SPREAD or OLD_LOW_SPREAD))
	self.lowFrame:SetSize(spread, spread)
	self.sheen:ClearAllPoints()
	self.sheen:SetSize(inner, inner)
	self.sheen:SetPoint("CENTER", self.portrait, "CENTER", -inner, 0)
	self.sheenAnim.move:SetOffset(2 * inner, 0)
	if not plaqueSide then
		self.plaque:Hide()
		return
	end
	local px = Widgets.Border(self)
	local least = Widgets.FontSize(self.levelText, math.ceil(LEVEL_FLOOR / (Scale.AppliedUserScale() * Scale.Pixel(1)) - 1e-6) * px)
	local s = math.max(Snap(self, size * PLAQUE_SHARE), math.ceil(least / PLAQUE_FONT / px - 1e-6) * px)
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
	local effects = ns.Effects
	if effects then
		if unit == "player" then
			effects.playerMedallion = self
		elseif effects.playerMedallion == self then
			effects.playerMedallion = nil
		end
	end
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

function Medallion:LowHealth(unit, enemy, clean)
	clean = clean ~= false
	if self.cleanLow ~= clean then
		self.cleanLow = clean
		self.lowFrame:SetFrameLevel(self:GetFrameLevel() + (clean and 0 or LEVEL_RING))
		local spread = Snap(self, self.size * (clean and LOW_SPREAD or OLD_LOW_SPREAD))
		self.lowFrame:SetSize(spread, spread)
		self.low:SetBlendMode(clean and "BLEND" or "ADD")
		self.low:SetVertexColor(Tokens.Color(clean and "healthLow" or "white"))
		if self.dangerPulse then ns.Effects.Vignette.Breath(clean and self.lowFrame or nil, self.dangerPulse) end
	end
	if clean then
		self.pulse:Stop()
		local player = unit and SHOW_LOW[unit]
		local curve = player and DangerCurve()
		self.low:SetTexture((Tokens.Texture(player and "medDangerAnnulus" or "medDangerRim")))
		self.lowFrame:SetShown(unit ~= nil and (curve ~= nil or enemy == true))
		if curve then
			self.low:SetAlpha(UnitHealthPercent(unit, true, curve))
			if not self.dangerPulse then self.dangerPulse = ns.Effects.Vignette.Breath(self.lowFrame) end
		else
			self.low:SetAlpha(1)
		end
		return
	end
	self.low:SetTexture((Tokens.Texture("medLowHealthRing")))
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

local function SheenParts(self)
	if not self.sheenStart then
		self.sheenStart = function()
			self.sheen:Show()
			self.sheenAnim:Play()
		end
		self.sheenStop = function()
			self.sheenAnim:Pause()
			self.sheen:Hide()
		end
	end
end

function Medallion:Sheen(on)
	local effects = ns.Effects
	if effects and effects.Ambient then
		SheenParts(self)
		if on == true then
			effects.Ambient(self, self.sheenStart, self.sheenStop)
		else
			effects.Ambient(self, nil, nil)
			self.sheenAnim:Stop()
			self.sheen:Hide()
		end
		return
	end
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
	local effects = ns.Effects
	if effects and effects.ClaimFor then
		if not self.flipStop then
			self.flipStop = function()
				self.flip:Stop()
			end
		end
		if not effects.ClaimFor(self, effects.PRIORITY.target, FLIP, self.flipStop) then
			return
		end
	end
	self.flip:Stop()
	self.flip:Play()
end

local function BurstParts(self)
	local burst = self.burst
	if not burst then
		burst = self:CreateTexture(nil, "BACKGROUND", nil, -8)
		burst:SetBlendMode("ADD")
		burst:SetPoint("CENTER", self, "CENTER", 0, 0)
		burst:SetAlpha(0)
		local group = burst:CreateAnimationGroup()
		local grow = group:CreateAnimation("Scale")
		grow:SetScaleFrom(BURST_FROM, BURST_FROM)
		grow:SetScaleTo(BURST_TO, BURST_TO)
		grow:SetOrigin("CENTER", 0, 0)
		grow:SetDuration(BURST)
		grow:SetSmoothing("OUT")
		local rise = group:CreateAnimation("Alpha")
		rise:SetFromAlpha(0)
		rise:SetToAlpha(1)
		rise:SetDuration(BURST * BURST_RISE)
		local fall = group:CreateAnimation("Alpha")
		fall:SetFromAlpha(1)
		fall:SetToAlpha(0)
		fall:SetStartDelay(BURST * BURST_RISE)
		fall:SetDuration(BURST * (1 - BURST_RISE))
		group:SetScript("OnFinished", function()
			burst:SetAlpha(0)
		end)
		burst.anim = group
		self.burst = burst
		self.burstPlay = function()
			group:Stop()
			group:Play()
		end
		self.burstStop = function()
			group:Stop()
			burst:SetAlpha(0)
		end
	end
	return burst
end

function Medallion:Burst(class)
	local effects = ns.Effects
	if not (effects and effects.Burst and self:IsVisible()) then
		return false
	end
	local burst = BurstParts(self)
	local word = CLASS_WORD[class]
	local path, own = effects.Texture(word and ("medBurst" .. word) or "glow", "glow")
	burst:SetTexture(path)
	local c = not own and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		burst:SetVertexColor(c.r, c.g, c.b, 1)
	else
		burst:SetVertexColor(Tokens.Color("white"))
	end
	local side = Snap(self, self.size * BURST_SHARE)
	burst:SetSize(side, side)
	return effects.Burst(self, effects.PRIORITY.burst, self, class or "", self.size * BURST_SHARE, BURST, self.burstPlay, self.burstStop)
end
