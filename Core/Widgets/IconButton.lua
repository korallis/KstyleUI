-- IconButton.lua: the chamfered square icon button with hover, pressed, cooldown, proc, selected and disabled states, and the icon chrome every square icon shares.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale = ns.Tokens, ns.Scale

local REST_LIFT, HOVER_LIFT = 0.15, 0.25
local COOLING_EDGE_ALPHA = 0.62
local PRESSED_EDGE_ALPHA = 0.77
local PRESS_DIM = 0.45
local DIM_FILL_LIFT = 0.75
local UNUSABLE_BRIGHTNESS = 0.45
local COOLING_BRIGHTNESS = 0.4
local SWIPE_ALPHA = 0.65
local HOVER_GLOW_SPREAD, HOVER_GLOW_ALPHA, HOVER_WASH = 10, 0.3, 0.2
local PROC_HALO_ALPHA = 0.1
local RIM_HALO = 0.45
local RIM_SIDE = 0.65
local ICON_BEVEL = { top = 1, bottom = 1, side = RIM_SIDE, cut = 1 }
local COUNTDOWN_RISE = 0.25
local COUNTDOWN_CORNER_X, COUNTDOWN_CORNER_Y = 0.2, 0.1
local ICON_INSET_LINES = 3
local ICON_INSET_SHARE = 0.11
local ICON_INSET_MAX_SHARE = 0.2
local TEXT_INSET = 3
local ICON_CROP = 0.07
local OVERLAY_LEVEL = 2

Widgets.SECONDARY_RIM = 1

local IconButton = {}

local function Plain(v)
	return type(v) == "number" and not Widgets.IsSecret(v)
end

function Widgets.IconRim(r, g, b, strength, lift)
	if not (Plain(r) and Plain(g) and Plain(b)) then
		r, g, b = Tokens.Color("accent")
	end
	local wr, wg, wb = Tokens.Color("textHover")
	r, g, b = Widgets.Mix(r, g, b, 1, wr, wg, wb, 1, lift or REST_LIFT)
	if Plain(strength) and strength < 1 then
		local er, eg, eb, ea = Widgets.Rgba("edgeInner")
		return Widgets.Mix(er, eg, eb, ea, r, g, b, 1, strength)
	end
	return r, g, b, 1
end

local function PaintRim(chrome)
	local r, g, b, a
	if chrome.rimAccent then
		local own = chrome.rimOwn
		r, g, b, a = Widgets.IconRim(own and own[1], own and own[2], own and own[3], chrome.rimStrength)
	elseif chrome.rimSet then
		local c = chrome.rimColor
		r, g, b, a = c[1], c[2], c[3], c[4]
	else
		chrome:SetEdge("edgeInner")
		chrome:SetOuter()
		return
	end
	chrome:SetEdgeRGBA(r, g, b, a)
	chrome:SetOuterRGBA(r, g, b, a * RIM_HALO)
end

local function SetRim(chrome, r, g, b, a)
	chrome.rimAccent = false
	if Plain(r) and Plain(g) and Plain(b) then
		local c = chrome.rimColor
		c[1], c[2], c[3], c[4] = r, g, b, Plain(a) and a or 1
		chrome.rimSet = true
	else
		chrome.rimSet = false
	end
	PaintRim(chrome)
end

local function SetRimAccent(chrome, r, g, b, strength)
	chrome.rimAccent = true
	if Plain(r) and Plain(g) and Plain(b) then
		local own = chrome.rimOwn or {}
		own[1], own[2], own[3] = r, g, b
		chrome.rimOwn = own
	else
		chrome.rimOwn = nil
	end
	chrome.rimStrength = Plain(strength) and strength or nil
	PaintRim(chrome)
end

function Widgets.IconChrome(owner, opts)
	opts = opts or {}
	local share = Tokens.Share("chamferIcon")
	local chrome = Widgets.Chrome(owner, {
		shape = "tile", fill = "buttonFill", shadow = opts.bezel ~= nil, bezel = opts.bezel,
		chamfer = opts.size and opts.size * share or nil, share = share, fade = false, bevel = ICON_BEVEL,
	})
	chrome.rimColor = { 0, 0, 0, 0 }
	chrome.rimSet, chrome.rimAccent = false, false
	local paint = chrome.Paint
	chrome.Paint = function(self)
		paint(self)
		PaintRim(self)
	end
	chrome.SetRim, chrome.SetRimAccent = SetRim, SetRimAccent
	return chrome
end

local function PlaceIcon(self)
	if not Widgets.MayMove(self) then
		return
	end
	local offset = Widgets.PressOffset(self)
	if self.placedOffset == offset then
		return
	end
	self.placedOffset = offset
	local size = self.opts.size or Tokens.Size("actionButton")
	local inset
	if type(self.opts.iconInset) == "number" then
		inset = Widgets.Snap(self, self.opts.iconInset)
	else
		inset = math.max(Widgets.Border(self) * ICON_INSET_LINES, Widgets.Snap(self, size * ICON_INSET_SHARE))
		inset = math.min(inset, Widgets.Snap(self, size * ICON_INSET_MAX_SHARE))
	end
	self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset - offset)
	self.icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, inset - offset)
end

local function Accent(self)
	local own = self.accent
	if own then
		return own[1], own[2], own[3]
	end
	local r, g, b = Tokens.Color("accent")
	return r, g, b
end

function IconButton:Paint()
	local hover, press = self.hoverT or 0, self.pressT or 0
	local usable = self.usable and self:IsEnabled() ~= false
	local cooling = self.cooling and self.realCooldown
	local chrome = self.chrome
	local r, g, b, a
	local lift = 0
	if not usable then
		r, g, b, a = Tokens.Color("textDisabled")
		lift = DIM_FILL_LIFT
	elseif self.proc or self.selected then
		r, g, b = Accent(self)
		a = 1
	elseif cooling then
		r, g, b, a = Widgets.Rgba("text", COOLING_EDGE_ALPHA)
		lift = DIM_FILL_LIFT
	else
		local ar, ag, ab = Accent(self)
		local strength = self.opts.primary and 1 or Widgets.SECONDARY_RIM
		r, g, b, a = Widgets.IconRim(ar, ag, ab, strength, REST_LIFT + (HOVER_LIFT - REST_LIFT) * hover)
		local pr, pg, pb, pa = Widgets.Rgba("text", PRESSED_EDGE_ALPHA)
		r, g, b, a = Widgets.Mix(r, g, b, a, pr, pg, pb, pa, press)
		lift = DIM_FILL_LIFT * press
	end
	chrome:SetRim(r, g, b, a)
	local fr, fg, fb, fa = Tokens.Color("buttonFill")
	if lift > 0 then
		local xr, xg, xb, xa = Tokens.Color("raised")
		fr, fg, fb, fa = Widgets.Mix(fr, fg, fb, fa, xr, xg, xb, xa, lift)
	end
	chrome:SetFillRGBA(fr, fg, fb, fa)
	local v, desaturated = UNUSABLE_BRIGHTNESS, not usable
	if usable then
		if cooling then
			v = COOLING_BRIGHTNESS
		else
			v = 1 - PRESS_DIM * press
			desaturated = press >= 0.5
		end
	end
	local tint = self.tint
	ns.Icons.Shade(self.icon, v * tint[1], v * tint[2], v * tint[3], desaturated)
	self.hoverGlow:SetIntensity(usable and hover or 0)
	PlaceIcon(self)
end

local function ColorGlow(self, glow)
	local own = self.accent
	if own then
		glow:SetColorRGB(own[1], own[2], own[3])
	else
		glow:SetColorRGB()
	end
end

function IconButton:SetAccent(r, g, b)
	if Plain(r) and Plain(g) and Plain(b) then
		local own = self.accent or {}
		own[1], own[2], own[3] = r, g, b
		self.accent = own
	else
		self.accent = nil
	end
	ColorGlow(self, self.hoverGlow)
	if self.procGlow then
		ColorGlow(self, self.procGlow)
	end
	self:Paint()
end

function IconButton:SetTint(r, g, b)
	local tint = self.tint
	g, b = g or r, b or r
	if Plain(r) and Plain(g) and Plain(b) then
		tint[1], tint[2], tint[3] = r, g, b
	else
		tint[1], tint[2], tint[3] = 1, 1, 1
	end
	self:Paint()
end

function IconButton:SetIcon(texture)
	ns.Icons.Reset(self.icon)
	self.icon:SetTexture(texture)
end

local function SetRealCooldown(self, real)
	if self.realCooldown ~= real then
		self.realCooldown = real
		self:Paint()
	end
end

function IconButton:SetCooldown(start, duration, gcd)
	if Widgets.IsSecret(start) or Widgets.IsSecret(duration) then
		Widgets.LogOnce("cooldown-secret", "IconButton refused a secret cooldown; pass a duration object to SetCooldownFromDuration")
		return false
	end
	self.cooldown:SetCooldown(start, duration)
	SetRealCooldown(self, gcd ~= true)
	return true
end

function IconButton:SetCooldownFromDuration(durationObject, gcd)
	local cooldown = self.cooldown
	if type(cooldown.SetCooldownFromDurationObject) ~= "function" then
		Widgets.LogOnce("cooldown-object", "Cooldown:SetCooldownFromDurationObject is missing; the cooldown is not shown")
		return false
	end
	cooldown:SetCooldownFromDurationObject(durationObject)
	SetRealCooldown(self, gcd ~= true)
	return true
end

function IconButton:ClearCooldown()
	self.cooldown:Clear()
	SetRealCooldown(self, false)
end

function IconButton:SetChargeCooldownFromDuration(durationObject)
	local charge = self.chargeCooldown
	if not charge then
		charge = CreateFrame("Cooldown", nil, self, "CooldownFrameTemplate")
		charge:SetAllPoints(self.icon)
		charge:SetDrawSwipe(false)
		charge:SetDrawEdge(true)
		charge:SetDrawBling(false)
		charge:SetHideCountdownNumbers(true)
		charge:SetFrameLevel(self.cooldown:GetFrameLevel() + 1)
		self.chargeCooldown = charge
	end
	if type(charge.SetCooldownFromDurationObject) ~= "function" then
		Widgets.LogOnce("charge-object", "Cooldown:SetCooldownFromDurationObject is missing; charge recharges are not shown")
		return false
	end
	charge:SetCooldownFromDurationObject(durationObject)
	return true
end

function IconButton:ClearChargeCooldown()
	if self.chargeCooldown then
		self.chargeCooldown:Clear()
	end
end

function IconButton:SetProc(on)
	self.proc = on and true or false
	if self.proc and not self.procGlow then
		self.procGlow = Widgets.Glow(self, { kind = "proc", alpha = PROC_HALO_ALPHA })
		if self.accent then
			ColorGlow(self, self.procGlow)
		end
	end
	if self.procGlow then
		if self.proc then
			self.procGlow:Start()
		else
			self.procGlow:Stop()
		end
	end
	self:Paint()
end

function IconButton:SetUsable(on)
	self.usable = on and true or false
	self:Paint()
end

function IconButton:SetSelected(on)
	self.selected = on and true or false
	self:Paint()
end

function IconButton:SetHotkey(text)
	Widgets.SetText(self.hotkey, text)
end

function IconButton:SetCount(text)
	Widgets.SetText(self.count, text)
end

function IconButton:Restyle()
	if Widgets.MayMove(self) then
		local size = self.opts.size or Tokens.Size("actionButton")
		Widgets.Size(self, size, size)
		self.chrome:SetChamfer(size * Tokens.Share("chamferIcon"))
		self.placedOffset = nil
		local inset = Widgets.Snap(self, TEXT_INSET)
		self.hotkey:ClearAllPoints()
		self.hotkey:SetPoint("TOPRIGHT", self, "TOPRIGHT", -inset, -inset)
		self.count:ClearAllPoints()
		self.count:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, inset)
		if self.countdown then
			self.countdown:ClearAllPoints()
			if self.opts.countdownCorner then
				self.countdown:SetPoint("TOPRIGHT", self, "TOPRIGHT", -Widgets.Snap(self, size * COUNTDOWN_CORNER_X), -Widgets.Snap(self, size * COUNTDOWN_CORNER_Y))
				self.countdown:SetJustifyH("RIGHT")
			else
				self.countdown:SetPoint("CENTER", self.cooldown, "BOTTOM", 0, Widgets.Snap(self, size * COUNTDOWN_RISE))
				self.countdown:SetJustifyH("CENTER")
			end
		end
		self.hoverGlow:Restyle()
		if self.procGlow then
			self.procGlow:Restyle()
		end
	end
	self:Paint()
end

local function WatchCooldown(button, cooldown)
	local function started()
		button.cooling = true
		button:Paint()
	end
	local function ended()
		button.cooling = false
		button:Paint()
	end
	cooldown:HookScript("OnShow", started)
	cooldown:HookScript("OnHide", ended)
	cooldown:HookScript("OnCooldownDone", ended)
end

function Widgets.IconButton(parent, opts)
	opts = opts or {}
	local button = CreateFrame("Button", opts.name, parent or Scale.Root(), opts.template)
	for k, fn in pairs(IconButton) do
		button[k] = fn
	end
	button.opts = opts
	button.onClick = opts.onClick
	button.silent = opts.silent == true
	button.usable = true
	button.tint = { 1, 1, 1 }
	local size = opts.size or Tokens.Size("actionButton")
	button.chrome = Widgets.IconChrome(button, { size = size, bezel = Tokens.Size("buttonBezel") })
	local maskPath = Tokens.Texture("iconMask")
	local icon = button:CreateTexture(nil, "ARTWORK")
	if opts.crop ~= false then
		icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	end
	local mask = button:CreateMaskTexture()
	mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	button.icon, button.mask = icon, mask
	button.hoverGlow = Widgets.Glow(button, { kind = "selection", spread = HOVER_GLOW_SPREAD, alpha = HOVER_GLOW_ALPHA, core = HOVER_WASH })
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints(icon)
	cooldown:SetSwipeTexture(maskPath)
	cooldown:SetSwipeColor(Widgets.Rgba("black", SWIPE_ALPHA))
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetHideCountdownNumbers(opts.hideNumbers == true)
	local countdown = cooldown:GetCountdownFontString()
	if countdown then
		Widgets.StyleText(countdown, "number")
		Widgets.TextColor(countdown, "textEmphasis")
	end
	WatchCooldown(button, cooldown)
	button.cooldown, button.countdown = cooldown, countdown
	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetAllPoints(button)
	overlay:SetFrameLevel(cooldown:GetFrameLevel() + OVERLAY_LEVEL)
	button.overlay = overlay
	button.hotkey = Widgets.Text(overlay, "caption", "textEmphasis")
	button.count = Widgets.Text(overlay, "number", "textEmphasis")
	Widgets.HookPointer(button)
	if opts.icon then
		button:SetIcon(opts.icon)
	end
	if opts.tooltip and Widgets.AttachTooltip then
		Widgets.AttachTooltip(button, opts.tooltip)
	end
	button:Restyle()
	return Widgets.Track(button)
end
