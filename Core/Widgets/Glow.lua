-- Glow.lua: proc and selection glows made from the shadow falloff, pulsed by AnimationGroups.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Motion = ns.Tokens, ns.Motion
local max = math.max

local PULSE_LOW, PULSE_HIGH = 0.45, 1
local SPARK_SCALE = 1.35
local SPARK_SIZE = 12
local SPARK_INSET = 2
local SELECTION_ALPHA = 0.6
local SPARK_LEVEL = 3

local Glow = {}
Glow.__index = Glow

local function StopAnimations(handle)
	if handle.pulse then
		handle.pulse:Stop()
		handle.sparkPulse:Stop()
		handle.top:Hide()
		handle.pulsing = false
	end
end

local function StartAnimations(handle)
	if handle.pulse and not handle.pulsing and not Motion.ReducedMotion() then
		handle.pulsing = true
		handle.top:Show()
		handle.pulse:Play()
		handle.sparkPulse:Play()
	end
end

local function Reconcile(handle)
	if not handle.pulse or not handle.playing then
		return
	end
	if Motion.ReducedMotion() then
		StopAnimations(handle)
		handle.holder:SetAlpha(1)
	else
		StartAnimations(handle)
	end
end

local function Hidden(holder)
	holder:Hide()
	holder:SetAlpha(1)
end

function Glow:Restyle()
	local spread = self.spread
	Widgets.LayoutSlice(self.slice, self.holder, spread * 2, spread)
	local own = self.colorRGB
	local r, g, b
	if own then
		r, g, b = own[1], own[2], own[3]
	else
		r, g, b = Tokens.Color(self.colorName)
	end
	Widgets.ColorSlice(self.slice, r, g, b, 1)
	if self.spark then
		Widgets.Size(self.spark, SPARK_SIZE, SPARK_SIZE)
		self.spark:ClearAllPoints()
		self.spark:SetPoint("CENTER", self.frame, "TOPRIGHT", -Widgets.Snap(self.frame, SPARK_INSET), -Widgets.Snap(self.frame, SPARK_INSET))
		self.spark:SetVertexColor(Widgets.Rgba("textHover"))
	end
	Reconcile(self)
end

function Glow:SetColor(name)
	Tokens.Color(name)
	self.colorName = name
	self.colorRGB = nil
	self:Restyle()
end

function Glow:SetColorRGB(r, g, b)
	if type(r) == "number" and type(g) == "number" and type(b) == "number" and not Widgets.IsSecret(r) and not Widgets.IsSecret(g) and not Widgets.IsSecret(b) then
		local own = self.colorRGB or {}
		own[1], own[2], own[3] = r, g, b
		self.colorRGB = own
	else
		self.colorRGB = nil
	end
	self:Restyle()
end

function Glow:IsPlaying()
	return self.playing
end

function Glow:Start()
	if self.playing then
		return
	end
	self.playing = true
	local holder = self.holder
	Motion.FadeIn(holder, Tokens.Duration("fade"), self.kind == "selection" and SELECTION_ALPHA or 1)
	StartAnimations(self)
end

function Glow:Stop()
	if not self.playing then
		return
	end
	self.playing = false
	local holder = self.holder
	Motion.Tween(holder, "SetAlpha", holder:GetAlpha(), 0, Tokens.Duration("fade"), Tokens.Easing("fade"), self.onFaded)
end

function Glow:SetIntensity(t)
	if self.playing then
		return
	end
	local holder = self.holder
	if t > 0 then
		holder:SetAlpha(t * SELECTION_ALPHA)
		holder:Show()
	else
		Hidden(holder)
	end
end

local function Pulse(owner, low, high, duration)
	local group = owner:CreateAnimationGroup()
	group:SetLooping("BOUNCE")
	local alpha = group:CreateAnimation("Alpha")
	alpha:SetFromAlpha(low)
	alpha:SetToAlpha(high)
	alpha:SetDuration(duration)
	alpha:SetSmoothing("IN_OUT")
	return group
end

function Widgets.Glow(frame, opts)
	opts = opts or {}
	local kind = opts.kind or "proc"
	if kind ~= "proc" and kind ~= "selection" then
		error("KstyleUI.Widgets.Glow: kind must be proc or selection, got " .. tostring(kind), 2)
	end
	local holder = CreateFrame("Frame", nil, frame)
	holder:SetAllPoints(frame)
	holder:SetFrameLevel(max(0, frame:GetFrameLevel() - 1))
	holder:Hide()
	local handle = setmetatable({
		frame = frame,
		holder = holder,
		kind = kind,
		colorName = opts.color or "accent",
		spread = opts.spread or Tokens.Size("gapMedium"),
		playing = false,
	}, Glow)
	handle.onFaded = function()
		if not handle.playing then
			Hidden(holder)
			StopAnimations(handle)
		end
	end
	local body = holder
	if kind == "proc" then
		body = CreateFrame("Frame", nil, holder)
		body:SetAllPoints(holder)
		handle.pulse = Pulse(body, PULSE_LOW, PULSE_HIGH, Tokens.Duration("procPulse") / 2)
		local top = CreateFrame("Frame", nil, frame)
		top:SetAllPoints(frame)
		top:SetFrameLevel(frame:GetFrameLevel() + SPARK_LEVEL)
		top:Hide()
		handle.top = top
		local spark = top:CreateTexture(nil, "OVERLAY")
		spark:SetTexture((Tokens.Texture("glow")))
		spark:SetBlendMode("ADD")
		handle.spark = spark
		local sparkPulse = Pulse(top, PULSE_LOW, PULSE_HIGH, Tokens.Duration("procPulse") / 2)
		local grow = sparkPulse:CreateAnimation("Scale")
		grow:SetScaleFrom(1, 1)
		grow:SetScaleTo(SPARK_SCALE, SPARK_SCALE)
		grow:SetDuration(Tokens.Duration("procPulse") / 2)
		grow:SetSmoothing("IN_OUT")
		handle.sparkPulse = sparkPulse
	end
	handle.slice = Widgets.NineSlice(body, "shadow", "BACKGROUND", 0)
	for _, piece in ipairs(handle.slice) do
		piece:SetBlendMode("ADD")
	end
	handle:Restyle()
	return Widgets.Track(handle)
end
