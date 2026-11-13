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
	local halo = { holder = holder, button = button }
	for i, spec in ipairs(HALO) do
		local t = holder:CreateTexture(nil, "BACKGROUND")
		t:SetTexture((Tokens.Texture("glow")))
		t:SetTexCoord(spec[5], spec[6], spec[7], spec[8])
		t:SetBlendMode("ADD")
		halo[i] = t
	end
	return halo
end

local function PlaceHalo(halo, spread)
	local holder = halo.holder
	local inset = 3 * Widgets.Border(halo.button)
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
		self.hoverOut:Stop()
		if Animated() then
			layer:SetAlpha(0)
			layer:Show()
			Replay(self.hoverIn)
		else
			layer:SetAlpha(1)
			layer:Show()
		end
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
	if down and not held then
		self:Flash()
	end
end

function Slot:Flash()
	if not Animated() then
		return
	end
	self.pressLayer:SetAlpha(0)
	self.pressLayer:Show()
	Replay(self.press)
end

local function Breathe(self)
	local breath = self.lumenGlow.breath
	if self.proc and not Motion.ReducedMotion() then
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
	self.chrome:SetProc(on)
	self.lumenGlow:SetShown(on)
	self:Paint()
end

local function Height(self)
	local size = self:GetHeight()
	if Widgets.IsSecret(size) or type(size) ~= "number" or size <= 0 then
		return self.opts.size or Tokens.Size("actionButton")
	end
	return size
end

local function PlaceLayers(self)
	local line = Widgets.Border(self)
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
	PlaceRing(self.hoverRim, self, -line, line)
	PlaceRing(self.pressRim, self, line, line)
	PlaceHalo(self.pressHalo, Widgets.Snap(self, PRESS_SPREAD))
	PlaceHalo(self.procHalo, Widgets.Snap(self, PROC_SPREAD))
	local inset = Widgets.Snap(self, TEXT_INSET)
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

local function PaintLayers(self)
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
	ColorRing(self.hoverRim, Widgets.Rgba("textHover", HOVER_RIM))
	ColorRing(self.pressRim, Tokens.Color("slotPress"))
	ColorHalo(self.pressHalo, Widgets.Rgba("slotPress", PRESS_HALO))
	self.lumenGlow.texture:SetVertexColor(Widgets.Rgba("giltLit", PROC_GLOW))
	ColorHalo(self.procHalo, Widgets.Rgba("giltLit", PROC_HALO))
	self.readyWash:SetColorTexture(Tokens.Color("giltLit"))
	if self.countdown then
		Widgets.TextColor(self.countdown, "slotNumber")
	end
	local cooldown = self.cooldown
	cooldown:SetDrawEdge(true)
	if type(cooldown.SetEdgeColor) == "function" then
		cooldown:SetEdgeColor(Tokens.Color("slotEdge"))
	end
end

local function Lit(self)
	return self.usable and self:IsEnabled() ~= false and not self.proc and not self.selected and not (self.cooling and self.realCooldown)
end

function Widgets.Slot(parent, opts)
	opts = opts or {}
	opts.fill = opts.fill or "slotFill"
	local b = Widgets.IconButton(parent, opts)
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
	b.hoverRim = Ring(hover, "OVERLAY", 1)
	Wash(b, hover, "white", HOVER_WASH)
	b.hoverIn = hover:CreateAnimationGroup()
	b.hoverIn:SetToFinalAlpha(true)
	Fade(b.hoverIn, 0, 1, Tokens.Duration("hover"), "OUT")
	b.hoverOut = hover:CreateAnimationGroup()
	b.hoverOut:SetToFinalAlpha(true)
	Fade(b.hoverOut, 1, 0, Tokens.Duration("hover"), "OUT")
	b.hoverOut:SetScript("OnFinished", function()
		if not b.hovered then
			hover:Hide()
		end
	end)
	local press = Layer(b)
	b.pressLayer = press
	b.pressHalo = Halo(b, press)
	b.pressRim = Ring(press, "OVERLAY", 1)
	Wash(b, press, "white", PRESS_WASH)
	b.press = press:CreateAnimationGroup()
	local rise = Tokens.Duration("pressIn")
	Fade(b.press, 0, 1, rise, "OUT")
	Fade(b.press, 1, 0, Tokens.Duration("pressOut"), "IN", rise)
	b.press:SetScript("OnFinished", function()
		press:Hide()
	end)
	local glow = Layer(b, b.icon)
	local texture = glow:CreateTexture(nil, "OVERLAY")
	texture:SetTexture((Tokens.Texture("glow")))
	texture:SetBlendMode("ADD")
	texture:SetAllPoints(glow)
	glow.texture = Masked(b, texture)
	b.procHalo = Halo(b, glow)
	glow.breath = glow:CreateAnimationGroup()
	glow.breath:SetLooping("BOUNCE")
	Fade(glow.breath, BREATH_HIGH, BREATH_LOW, Tokens.Duration("procPulse"), "IN_OUT")
	b.lumenGlow = glow
	b.readyFade:SetFromAlpha(READY_ALPHA)
	b.readyFade:SetDuration(Tokens.Duration("readyFlash"))
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
		PaintLayers(self)
	end
	b:Restyle()
	return b
end
