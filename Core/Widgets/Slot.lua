-- Slot.lua: the action slot every tray shares: an opaque well, a lit rim and bevel, the key at the top left, a centred cooldown number over a sweep with a lit edge, and the press flash, hover lift, proc glow and ready flash as animation groups.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Motion = ns.Tokens, ns.Motion

local TEXT_INSET = 3
local BEVEL_TOP, BEVEL_BOTTOM = 0.16, 0.2
local BEVEL_LIGHT, BEVEL_SHADE = 0.24, 0.6
local INNER_ALPHA = 0.8
local HOVER_RIM, HOVER_WASH = 0.7, 0.12
local PRESS_WASH, PRESS_HALO, PRESS_SPREAD = 0.3, 0.6, 6
local PROC_GLOW, PROC_HALO, PROC_SPREAD = 0.55, 1, 10
local BREATH_LOW, BREATH_HIGH = 0.45, 1
local READY_ALPHA = 0.6
local LAYER_LEVEL = 1

local Slot = {}

local function Solid(frame, layer, sublevel)
	local t = frame:CreateTexture(nil, layer, nil, sublevel)
	t:SetColorTexture(Tokens.Color("white"))
	return t
end

local function Ring(frame, layer, sublevel)
	local ring = {}
	for i = 1, 4 do
		ring[i] = Widgets.Crisp(Solid(frame, layer, sublevel))
	end
	return ring
end

local function PlaceRing(ring, target, outset, line)
	local top, bottom, left, right = ring[1], ring[2], ring[3], ring[4]
	for i = 1, 4 do
		ring[i]:ClearAllPoints()
	end
	top:SetPoint("TOPLEFT", target, "TOPLEFT", -outset, outset)
	top:SetPoint("TOPRIGHT", target, "TOPRIGHT", outset, outset)
	top:SetHeight(line)
	bottom:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -outset, -outset)
	bottom:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", outset, -outset)
	bottom:SetHeight(line)
	left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
	left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
	left:SetWidth(line)
	right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
	right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
	right:SetWidth(line)
end

local function ColorRing(ring, r, g, b, a)
	for i = 1, 4 do
		ring[i]:SetVertexColor(r, g, b, a)
	end
end

local function Masked(button, texture)
	texture:AddMaskTexture(button.mask)
	return texture
end

local function Wash(button, frame, colorName, alpha)
	local t = Solid(frame, "OVERLAY", 0)
	t:SetBlendMode("ADD")
	t:SetAllPoints(button.icon)
	t:SetVertexColor(Widgets.Rgba(colorName, alpha))
	return Masked(button, t)
end

local function Layer(button, target)
	local frame = CreateFrame("Frame", nil, button)
	frame:SetAllPoints(target or button)
	frame:SetFrameLevel(button.cooldown:GetFrameLevel() + LAYER_LEVEL)
	frame:Hide()
	return frame
end

local HALO = {
	{ "TOPLEFT", "TOPLEFT", -1, 1, 0, 0.5, 0, 0.5 },
	{ "TOP", "TOP", 0, 1, 0.5, 0.5, 0, 0.5 },
	{ "TOPRIGHT", "TOPRIGHT", 1, 1, 0.5, 1, 0, 0.5 },
	{ "LEFT", "LEFT", -1, 0, 0, 0.5, 0.5, 0.5 },
	{ "RIGHT", "RIGHT", 1, 0, 0.5, 1, 0.5, 0.5 },
	{ "BOTTOMLEFT", "BOTTOMLEFT", -1, -1, 0, 0.5, 0.5, 1 },
	{ "BOTTOM", "BOTTOM", 0, -1, 0.5, 0.5, 0.5, 1 },
	{ "BOTTOMRIGHT", "BOTTOMRIGHT", 1, -1, 0.5, 1, 0.5, 1 },
}

local function Halo(button, layer)
	local holder = CreateFrame("Frame", nil, layer)
	return { holder = holder, button = button }
end

local function BuildHalo(halo)
	for i, spec in ipairs(HALO) do
		local t = halo.holder:CreateTexture(nil, "BACKGROUND")
		t:SetTexture((Tokens.Texture("glow")))
		t:SetTexCoord(spec[5], spec[6], spec[7], spec[8])
		t:SetBlendMode("ADD")
		halo[i] = t
	end
end

local function PlaceHalo(halo, spread, inset)
	local holder = halo.holder
	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", halo.button, "TOPLEFT", inset, -inset)
	holder:SetPoint("BOTTOMRIGHT", halo.button, "BOTTOMRIGHT", -inset, inset)
	spread = spread + inset
	for i, spec in ipairs(HALO) do
		local t = halo[i]
		t:ClearAllPoints()
		local dx, dy = spec[3], spec[4]
		if dx ~= 0 and dy ~= 0 then
			t:SetPoint(spec[1], holder, spec[2], dx * spread, dy * spread)
			t:SetSize(spread, spread)
		elseif dx == 0 then
			t:SetPoint(dy > 0 and "BOTTOMLEFT" or "TOPLEFT", holder, dy > 0 and "TOPLEFT" or "BOTTOMLEFT")
			t:SetPoint(dy > 0 and "BOTTOMRIGHT" or "TOPRIGHT", holder, dy > 0 and "TOPRIGHT" or "BOTTOMRIGHT")
			t:SetHeight(spread)
		else
			t:SetPoint(dx > 0 and "TOPLEFT" or "TOPRIGHT", holder, dx > 0 and "TOPRIGHT" or "TOPLEFT")
			t:SetPoint(dx > 0 and "BOTTOMLEFT" or "BOTTOMRIGHT", holder, dx > 0 and "BOTTOMRIGHT" or "BOTTOMLEFT")
			t:SetWidth(spread)
		end
	end
end

local function ColorHalo(halo, r, g, b, a)
	for i = 1, #HALO do
		halo[i]:SetVertexColor(r, g, b, a)
	end
end

local function Fade(group, from, to, duration, smoothing, delay)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetSmoothing(smoothing)
	if delay then
		a:SetStartDelay(delay)
	end
	return a
end

local function Animated()
	return Motion.Level() ~= "off"
end

local function Replay(group)
	group:Stop()
	group:Play()
end

function Slot:AnimateHover(on)
	on = on == true
	if self.hovered == on then
		return
	end
	self.hovered = on
	local layer = self.hoverLayer
	if on then
		self:BuildState("hover")
		self.hoverOut:Stop()
		if Animated() then
			layer:SetAlpha(0)
			layer:Show()
			Replay(self.hoverIn)
		else
			layer:SetAlpha(1)
			layer:Show()
		end
	elseif self.opts.inputContinuity and Animated() and self.hoverIn:IsPlaying() then
		return
	elseif Animated() and layer:IsShown() and not self.hoverIn:IsPlaying() then
		Replay(self.hoverOut)
	else
		self.hoverIn:Stop()
		layer:Hide()
	end
end

function Slot:AnimatePress(down)
	down = down == true
	local held = self.pressHeld
	self.pressHeld = down
	if self.opts.inputContinuity and not self.slabDressed and (down or self.heldLayer) then
		if not self.heldLayer then
			local heldLayer = Layer(self)
			self.heldLayer, self.heldRim = heldLayer, Ring(heldLayer, "OVERLAY", 1)
			local line = self.stateLine or Widgets.Border(self)
			PlaceRing(self.heldRim, self, line, line)
			ColorRing(self.heldRim, Tokens.Color("slotPress"))
			self.heldRelease = heldLayer:CreateAnimationGroup()
			Fade(self.heldRelease, 0.6, 0, 0.1, "IN")
			self.heldRelease:SetScript("OnFinished", function() heldLayer:Hide() end)
		end
		self.heldRelease:Stop()
		if down then
			self.heldLayer:SetAlpha(0.6)
			self.heldLayer:Show()
		elseif Animated() then
			self.heldRelease:Play()
		else
			self.heldLayer:Hide()
		end
	end
	if down and not held then
		self:Flash()
	end
end

function Slot:Flash()
	if not Animated() or self.slabDressed then
		return
	end
	self:BuildState("press")
	self.pressLayer:SetAlpha(0)
	self.pressLayer:Show()
	Replay(self.press)
end

local function Breathe(self)
	if self.opts.procTransitions then
		local on = self.proc == true and not self.slabProc
		Widgets.ShowProc(self.lumenGlow, on, true, on and not Motion.ReducedMotion())
		return
	end
	if self.lumenGlow.procPolished then
		Widgets.ShowProc(self.lumenGlow, self.proc == true and not self.slabProc, false, false)
	end
	local breath = self.lumenGlow.breath
	local visible = self.lumenGlow:IsVisible()
	if Widgets.IsSecret(visible) then
		visible = true
	end
	if self.proc and visible and not Motion.ReducedMotion() then
		if not breath:IsPlaying() then
			breath:Play()
		end
	elseif breath:IsPlaying() then
		breath:Stop()
		self.lumenGlow:SetAlpha(BREATH_HIGH)
	end
end

function Slot:SetProc(on)
	on = on == true
	if on == (self.proc == true) then
		return
	end
	self.proc = on
	if on then
		self:BuildState("proc")
		if self.opts.procTransitions then
			self.readyFlash:Stop()
			self.readyWash:Hide()
		end
	end
	self.chrome:SetProc(on)
	if not self.opts.procTransitions then self.lumenGlow:SetShown(on) end
	self:Paint()
end

local function Height(self)
	local size = self:GetHeight()
	if Widgets.IsSecret(size) or type(size) ~= "number" or size <= 0 then
		return self.opts.size or Tokens.Size("actionButton")
	end
	return size
end

local function PlaceStates(self)
	local line = self.stateLine
	if not line then
		return
	end
	if self.heldRim then PlaceRing(self.heldRim, self, line, line) end
	if self.hoverRim then
		PlaceRing(self.hoverRim, self, -line, line)
	end
	if self.pressRim then
		PlaceRing(self.pressRim, self, line, line)
		PlaceHalo(self.pressHalo, self.statePressSpread, self.stateInset)
	end
	if self.lumenGlow.texture then
		PlaceHalo(self.procHalo, self.stateProcSpread, self.stateInset)
	end
end

local function PlaceLayers(self)
	local line = Widgets.Border(self)
	self.stateLine, self.stateInset = line, 3 * line
	self.statePressSpread, self.stateProcSpread = Widgets.Snap(self, self.opts.inputContinuity and 4 or PRESS_SPREAD), Widgets.Snap(self, self.opts.procTransitions and 5.6 or PROC_SPREAD)
	local size = Height(self)
	PlaceRing(self.innerLine, self.icon, 0, line)
	local top, bottom = self.bevelTop, self.bevelBottom
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", self.icon, "TOPLEFT")
	top:SetPoint("TOPRIGHT", self.icon, "TOPRIGHT")
	top:SetHeight(Widgets.Snap(self, size * BEVEL_TOP))
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", self.icon, "BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT", self.icon, "BOTTOMRIGHT")
	bottom:SetHeight(Widgets.Snap(self, size * BEVEL_BOTTOM))
	PlaceStates(self)
	local inset = Widgets.Snap(self, self.opts.readableCountdown and 2 or TEXT_INSET)
	self.hotkey:ClearAllPoints()
	self.hotkey:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset)
	self.hotkey:SetJustifyH("LEFT")
	local countdown = self.countdown
	if countdown then
		countdown:ClearAllPoints()
		Widgets.Point(countdown, "CENTER", self.icon, "CENTER")
		countdown:SetJustifyH("CENTER")
	end
end

local function StoreColor(self, key, r, g, b, a)
	local color = self[key]
	if not color then
		color = {}
		self[key] = color
	end
	color[1], color[2], color[3], color[4] = r, g, b, a
end

local function PaintStates(self)
	if self.hoverRim then
		ColorRing(self.hoverRim, unpack(self.hoverRimColor))
	end
	if self.pressRim then
		ColorRing(self.pressRim, unpack(self.pressRimColor))
		ColorHalo(self.pressHalo, unpack(self.pressHaloColor))
	end
	if self.lumenGlow.texture then
		self.lumenGlow.texture:SetVertexColor(unpack(self.procGlowColor))
		ColorHalo(self.procHalo, unpack(self.procHaloColor))
	end
end

local function PaintLayers(self)
	StoreColor(self, "hoverRimColor", Widgets.Rgba("textHover", HOVER_RIM))
	StoreColor(self, "pressRimColor", Tokens.Color("slotPress"))
	StoreColor(self, "pressHaloColor", Widgets.Rgba("slotPress", PRESS_HALO))
	StoreColor(self, "procGlowColor", Widgets.Rgba("giltLit", self.opts.procTransitions and 0.25 or PROC_GLOW))
	StoreColor(self, "procHaloColor", Widgets.Rgba("giltLit", PROC_HALO))
	ColorRing(self.innerLine, Widgets.Rgba("black", INNER_ALPHA))
	if type(self.bevelTop.SetGradient) == "function" and type(CreateColor) == "function" then
		local wr, wg, wb = Tokens.Color("white")
		local br, bg, bb = Tokens.Color("black")
		self.bevelTop:SetGradient("VERTICAL", CreateColor(wr, wg, wb, 0), CreateColor(wr, wg, wb, BEVEL_LIGHT))
		self.bevelBottom:SetGradient("VERTICAL", CreateColor(br, bg, bb, BEVEL_SHADE), CreateColor(br, bg, bb, 0))
	else
		Widgets.LogOnce("slot-bevel", "Texture:SetGradient or CreateColor is missing; slots draw without their bevel")
		self.bevelTop:Hide()
		self.bevelBottom:Hide()
	end
	self.well:SetVertexColor(Tokens.Color("slotWell"))
	PaintStates(self)
	self.readyWash:SetColorTexture(Widgets.Rgba(self.opts.procTransitions and "steelLit" or "giltLit"))
	if self.countdown then
		Widgets.TextColor(self.countdown, "slotNumber")
	end
	self.slotEdge = true
	self:StyleCooldown()
end

local function Lit(self)
	return self.usable and self:IsEnabled() ~= false and not self.proc and not self.selected and not (self.cooling and self.realCooldown)
end

function Slot:BuildState(kind)
	if kind == "hover" and not self.hoverRim then
		self.hoverRim = Ring(self.hoverLayer, "OVERLAY", 1)
		self.hoverWash = Wash(self, self.hoverLayer, "white", HOVER_WASH)
	elseif kind == "press" and not self.pressRim then
		BuildHalo(self.pressHalo)
		self.pressRim = Ring(self.pressLayer, "OVERLAY", 1)
		Wash(self, self.pressLayer, "white", PRESS_WASH)
	elseif kind == "proc" and not self.lumenGlow.texture then
		local glow = self.lumenGlow
		local texture = glow.body:CreateTexture(nil, "OVERLAY")
		texture:SetTexture((Tokens.Texture("glow")))
		texture:SetBlendMode("ADD")
		texture:SetAllPoints(glow)
		glow.texture = Masked(self, texture)
		BuildHalo(self.procHalo)
	else
		return
	end
	PlaceStates(self)
	PaintStates(self)
	self:SetSlabDress(self.slabProc)
end

function Slot:SetSlabDress(on)
	self.slabProc = on == true
	self.slabDressed = on == true and self.opts.inputContinuity == true
	if self.hoverWash then self.hoverWash:SetShown(not self.slabDressed) end
	for _, rim in ipairs(self.hoverRim or {}) do rim:SetShown(not self.slabDressed) end
	if self.slabDressed then
		self.pressLayer:Hide()
	end
	if self.heldLayer and (self.slabDressed or not self.opts.inputContinuity) then self.heldLayer:Hide() end
end

function Widgets.Slot(parent, opts)
	opts = opts or {}
	opts.fill = opts.fill or "slotFill"
	local b = Widgets.IconButton(parent, opts)
	local flashReady = b.FlashReady
	b.FlashReady = function(self)
		if not (self.opts.procTransitions and self.proc) then
			flashReady(self)
			self.readyFade:SetDuration(Motion.FadeDuration(self.opts.procTransitions and 0.18 or Tokens.Duration("readyFlash")))
		end
	end
	for k, fn in pairs(Slot) do
		b[k] = fn
	end
	local well = b:CreateTexture(nil, "ARTWORK", nil, -8)
	well:SetTexture((Tokens.Texture("glow")))
	well:SetAllPoints(b.icon)
	b.well = Masked(b, well)
	b.innerLine = Ring(b, "ARTWORK", 3)
	for i = 1, 4 do
		Masked(b, b.innerLine[i])
	end
	b.bevelTop = Masked(b, Solid(b, "ARTWORK", 2))
	b.bevelBottom = Masked(b, Solid(b, "ARTWORK", 2))
	local hover = Layer(b)
	b.hoverLayer = hover
	b.hoverIn = hover:CreateAnimationGroup()
	b.hoverIn:SetToFinalAlpha(true)
	Fade(b.hoverIn, 0, 1, Tokens.Duration("hover"), "OUT")
	b.hoverOut = hover:CreateAnimationGroup()
	b.hoverOut:SetToFinalAlpha(true)
	b.hoverOutFade = Fade(b.hoverOut, 1, 0, opts.inputContinuity and 0.1 or Tokens.Duration("hover"), opts.inputContinuity and "IN" or "OUT")
	b.hoverIn:SetScript("OnFinished", function()
		if opts.inputContinuity and not b.hovered then Replay(b.hoverOut) end
	end)
	b.hoverOut:SetScript("OnFinished", function()
		if not b.hovered then
			hover:Hide()
		end
	end)
	local press = Layer(b)
	b.pressLayer = press
	b.pressHalo = Halo(b, press)
	b.press = press:CreateAnimationGroup()
	local rise = Tokens.Duration("pressIn")
	Fade(b.press, 0, 1, rise, "OUT")
	Fade(b.press, 1, 0, Tokens.Duration("pressOut"), "IN", rise)
	b.press:SetScript("OnFinished", function()
		press:Hide()
	end)
	local glow = Layer(b, b.icon)
	glow.body = CreateFrame("Frame", nil, glow)
	glow.body:SetAllPoints(glow)
	b.procHalo = Halo(b, glow.body)
	Widgets.ProcMotion(glow, glow.body)
	b.lumenGlow = glow
	glow:HookScript("OnShow", function()
		Breathe(b)
	end)
	glow:HookScript("OnHide", function()
		Breathe(b)
	end)
	b.readyFade:SetFromAlpha(READY_ALPHA)
	b.readyFade:SetDuration(Tokens.Duration("readyFlash"))
	b.legacyReady, b.legacyReadyFade = b.readyFlash, b.readyFade
	b.modernReady = b.readyWash:CreateAnimationGroup()
	b.readyAttack = Fade(b.modernReady, 0, 0.45, 0.06, "OUT")
	b.readyDecay = Fade(b.modernReady, 0.45, 0, 0.18, "IN", 0.06)
	b.modernReady:SetScript("OnFinished", function() b.readyWash:Hide() end)
	b.rimToken = opts.rim or "slotRim"
	b:HookScript("OnClick", function(self, _, down)
		self:AnimatePress(down)
	end)
	local paint, restyle = b.Paint, b.Restyle
	b.Paint = function(self)
		paint(self)
		if Lit(self) and self.rimToken then
			self.chrome:SetRim(Tokens.Color(self.rimToken))
		end
		Breathe(self)
	end
	b.Restyle = function(self)
		restyle(self)
		if Widgets.MayMove(self) then
			PlaceLayers(self)
		end
		local proc, input = not not self.opts.procTransitions, not not self.opts.inputContinuity
		if self.motionProc ~= proc or self.motionInput ~= input then
			self.motionProc, self.motionInput = proc, input
			self.hoverOutFade:SetDuration(input and 0.1 or Tokens.Duration("hover"))
			self.hoverOutFade:SetSmoothing(input and "IN" or "OUT")
			local a = self.lumenGlow.breathAlpha
			a:SetToAlpha(proc and 0.55 or BREATH_LOW)
			a:SetDuration(Tokens.Duration(proc and "glowBreath" or "procPulse"))
			local ready = proc and self.modernReady or self.legacyReady
			if self.readyFlash ~= ready then
				self.readyFlash:Stop()
				self.readyWash:Hide()
			end
			self.readyFlash = ready
			self.readyFade = proc and self.readyDecay or self.legacyReadyFade
		end
		self:SetSlabDress(self.slabProc)
		PaintLayers(self)
	end
	b:Restyle()
	return b
end
