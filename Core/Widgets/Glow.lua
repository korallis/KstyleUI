-- Glow.lua: proc and selection glows made from the shadow falloff, pulsed by AnimationGroups.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Motion, Scale = ns.Tokens, ns.Motion, ns.Scale
local max = math.max

local PULSE_LOW, PULSE_HIGH = 0.45, 1
local SPARK_SCALE = 1.35
local SPARK_LONG, SPARK_THIN = 6, 1
local SPARK_INSET_X, SPARK_INSET_Y = 3, 2.5
local CORE_SHARE, CORE_ALPHA = 1.2, 0.35
local SELECTION_ALPHA = 0.6
local SPARK_LEVEL = 3

local Glow = {}
Glow.__index = function(self, key)
	if key == "slice" then
		self:Build()
		return rawget(self, key)
	end
	return Glow[key]
end

local function StopAnimations(handle)
	if handle.pulse then
		handle.pulse:Stop()
		handle.sparkPulse:Stop()
		handle.top:Hide()
		handle.pulsing = false
	end
end

local function StartAnimations(handle)
	if handle.pulse and not handle.pulsing and Motion.Slides() then
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
	if not Motion.Slides() then
		StopAnimations(handle)
		handle.holder:SetAlpha(handle.alpha)
	else
		StartAnimations(handle)
	end
end

local function Hidden(holder)
	holder:Hide()
	holder:SetAlpha(1)
end

local function PlaceStreak(streak, frame, insetX, insetY)
	local width, height = streak:GetSize()
	streak:ClearAllPoints()
	streak:SetPoint("TOPRIGHT", frame, "TOPRIGHT", Widgets.Snap(streak, width / 2 - insetX), Widgets.Snap(streak, height / 2 - insetY))
end

local function FrameSize(frame)
	local width, height = frame:GetSize()
	if Widgets.IsSecret(width) or Widgets.IsSecret(height) or type(width) ~= "number" or type(height) ~= "number" then
		local size = Tokens.Size("actionButton")
		return size, size
	end
	return width, height
end

function Glow:PaintShadow()
	local slice = rawget(self, "slice")
	if not slice then
		return
	end
	Widgets.PlaceSliceCorners(self.holder, slice[1], slice[3], slice[7], slice[9], self.shadowCorner, self.shadowOutset, 0, nil, self.shadowFarX, self.shadowFarY)
	slice.remainder = self.shadowRemainder
	Widgets.ColorSlice(slice, self.shadowR, self.shadowG, self.shadowB, 1)
end

function Glow:Restyle()
	local holder, spread = self.holder, self.spread
	local farX, farY = Widgets.Remainder(holder)
	local pixel = Scale.Pixel(1) / Widgets.ScaleFactor(holder)
	self.shadowCorner, self.shadowOutset = Widgets.Snap(holder, spread * 2), Widgets.Snap(holder, spread)
	self.shadowFarX, self.shadowFarY = farX * pixel, farY * pixel
	self.shadowRemainder = farX .. ":" .. farY
	local own = self.colorRGB
	local r, g, b
	if own then
		r, g, b = own[1], own[2], own[3]
	else
		r, g, b = Tokens.Color(self.colorName)
	end
	self.shadowR, self.shadowG, self.shadowB = r, g, b
	self:PaintShadow()
	if self.spark then
		Widgets.Size(self.spark, SPARK_LONG, SPARK_THIN)
		Widgets.Size(self.sparkCross, SPARK_THIN, SPARK_LONG)
		local insetX, insetY = Widgets.Snap(self.frame, SPARK_INSET_X), Widgets.Snap(self.frame, SPARK_INSET_Y)
		PlaceStreak(self.spark, self.frame, insetX, insetY)
		PlaceStreak(self.sparkCross, self.frame, insetX, insetY)
		self.spark:SetVertexColor(r, g, b, 1)
		self.sparkCross:SetVertexColor(r, g, b, 1)
	end
	if self.core then
		local width, height = FrameSize(self.frame)
		Widgets.Size(self.core, CORE_SHARE * width, CORE_SHARE * height)
		local cw, ch = self.core:GetSize()
		self.core:ClearAllPoints()
		self.core:SetPoint("TOPLEFT", self.frame, "TOPLEFT", Widgets.Snap(self.core, (width - cw) / 2), -Widgets.Snap(self.core, (height - ch) / 2))
		self.core:SetVertexColor(r, g, b, self.coreAlpha)
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

function Glow:Build()
	if not rawget(self, "slice") then
		self.slice = Widgets.NineSlice(self.body, "shadow", "BACKGROUND", 0)
		for _, piece in ipairs(self.slice) do
			piece:SetBlendMode("ADD")
		end
		self:PaintShadow()
	end
end

function Glow:Start()
	self:Build()
	if self.playing then
		return
	end
	self.playing = true
	local holder = self.holder
	Motion.FadeIn(holder, Tokens.Duration("fade"), self.alpha)
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
		self:Build()
		holder:SetAlpha(t * self.alpha)
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
	alpha:SetSmoothing(Tokens.Smoothing.loop)
	return group, alpha
end

function Widgets.ProcMotion(frame, body)
	local function Fade(from, to, duration, smoothing)
		local group = frame:CreateAnimationGroup()
		group:SetToFinalAlpha(true)
		local a = group:CreateAnimation("Alpha")
		a:SetFromAlpha(from)
		a:SetToAlpha(to)
		a:SetDuration(duration)
		a:SetSmoothing(smoothing)
		return group
	end
	frame.enter = Fade(0, 1, Tokens.Duration("procIn"), "OUT")
	frame.leave = Fade(1, 0, Tokens.Duration("procOut"), "IN")
	frame.leave:SetScript("OnFinished", function()
		if not frame.procShown then
			frame:Hide()
			frame.breath:Stop()
			if frame.onProcHidden then frame.onProcHidden() end
		end
	end)
	frame.breath, frame.breathAlpha = Pulse(body, 1, 0.55, Tokens.Duration("glowBreath"))
end

function Widgets.ShowProc(frame, on, polished, loops)
	local changed = frame.procShown ~= on or frame.procPolished ~= polished
	frame.procShown, frame.procPolished = on, polished
	if changed then
		frame.enter:Stop()
		frame.leave:Stop()
		if polished and Motion.Level() ~= "off" then
			frame:SetAlpha(on and 0 or 1)
			frame:Show()
			if on then frame.enter:Play() else frame.leave:Play() end
		else
			frame:SetAlpha(1)
			frame:SetShown(on)
		end
	end
	local visible = on and polished and loops and frame:IsVisible()
	if Widgets.IsSecret(visible) then visible = false end
	if visible then
		if not frame.breath:IsPlaying() then frame.breath:Play() end
	else
		frame.breath:Stop()
	end
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
		alpha = opts.alpha or (kind == "selection" and SELECTION_ALPHA or 1),
		playing = false,
	}, Glow)
	handle.onFaded = function()
		if not handle.playing then
			Hidden(holder)
			StopAnimations(handle)
		end
	end
	local body = holder
	local function Core(top)
		local core = top:CreateTexture(nil, "ARTWORK")
		core:SetTexture((Tokens.Texture("glow")))
		core:SetBlendMode("ADD")
		core:SetPoint("CENTER", frame, "CENTER")
		handle.core = core
	end
	if kind == "proc" then
		body = CreateFrame("Frame", nil, holder)
		body:SetAllPoints(holder)
		handle.pulse = Pulse(body, PULSE_LOW, PULSE_HIGH, Tokens.Duration("procPulse") / 2)
		local top = CreateFrame("Frame", nil, frame)
		top:SetAllPoints(frame)
		top:SetFrameLevel(frame:GetFrameLevel() + SPARK_LEVEL)
		top:Hide()
		handle.top = top
		for _, key in ipairs({ "spark", "sparkCross" }) do
			local streak = top:CreateTexture(nil, "OVERLAY")
			streak:SetTexture((Tokens.Texture("glow")))
			streak:SetBlendMode("ADD")
			handle[key] = streak
		end
		Core(top)
		handle.coreAlpha = CORE_ALPHA
		local sparkPulse = Pulse(top, PULSE_LOW, PULSE_HIGH, Tokens.Duration("procPulse") / 2)
		local grow = sparkPulse:CreateAnimation("Scale")
		grow:SetScaleFrom(1, 1)
		grow:SetScaleTo(SPARK_SCALE, SPARK_SCALE)
		grow:SetDuration(Tokens.Duration("procPulse") / 2)
		grow:SetSmoothing(Tokens.Smoothing.loop)
		handle.sparkPulse = sparkPulse
		Motion.TrackGroup(handle.pulse, function() StopAnimations(handle) end)
	elseif type(opts.core) == "number" and opts.core > 0 then
		local top = CreateFrame("Frame", nil, holder)
		top:SetAllPoints(frame)
		top:SetFrameLevel(frame:GetFrameLevel() + SPARK_LEVEL)
		handle.top = top
		Core(top)
		handle.coreAlpha = math.min(1, opts.core / handle.alpha)
	end
	handle.body = body
	handle:Restyle()
	return Widgets.Track(handle)
end
