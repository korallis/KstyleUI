-- IconButton.lua: the chamfered square icon button with hover, pressed, cooldown, proc, selected and disabled states.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale = ns.Tokens, ns.Scale

local REST_EDGE_ALPHA = 0.5
local COOLING_EDGE_ALPHA = 0.35
local PRESSED_EDGE_ALPHA = 0.6
local DISABLED_EDGE_ALPHA = 0.5
local PRESS_DIM = 0.25
local UNUSABLE_BRIGHTNESS = 0.55
local SWIPE_ALPHA = 0.65
local ICON_INSET_LINES = 2
local TEXT_INSET = 3
local ICON_CROP = 0.07
local OVERLAY_LEVEL = 2

local IconButton = {}

local function PlaceIcon(self)
	if not Widgets.MayMove(self) then
		return
	end
	local offset = Widgets.PressOffset(self)
	if self.placedOffset == offset then
		return
	end
	self.placedOffset = offset
	local inset = Widgets.Border(self) * ICON_INSET_LINES
	self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset - offset)
	self.icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, inset - offset)
end

function IconButton:Paint()
	local hover, press = self.hoverT or 0, self.pressT or 0
	local usable = self.usable and self:IsEnabled() ~= false
	local chrome = self.chrome
	if not usable then
		chrome:SetEdge("textDisabled", DISABLED_EDGE_ALPHA)
	elseif self.proc or self.selected then
		chrome:SetEdge("accent", 1)
	elseif self.cooling then
		chrome:SetEdge("text", COOLING_EDGE_ALPHA)
	else
		local r, g, b, a = Widgets.MixTokens("accent", REST_EDGE_ALPHA, "accent", 1, hover)
		local pr, pg, pb, pa = Widgets.Rgba("text", PRESSED_EDGE_ALPHA)
		chrome:SetEdgeRGBA(Widgets.Mix(r, g, b, a, pr, pg, pb, pa, press))
	end
	local v = usable and (1 - PRESS_DIM * press) or UNUSABLE_BRIGHTNESS
	ns.Icons.Shade(self.icon, v, v, v, not usable)
	self.hoverGlow:SetIntensity(usable and hover or 0)
	PlaceIcon(self)
end

function IconButton:SetIcon(texture)
	ns.Icons.Reset(self.icon)
	self.icon:SetTexture(texture)
end

function IconButton:SetCooldown(start, duration)
	if Widgets.IsSecret(start) or Widgets.IsSecret(duration) then
		Widgets.LogOnce("cooldown-secret", "IconButton refused a secret cooldown; pass a duration object to SetCooldownFromDuration")
		return false
	end
	self.cooldown:SetCooldown(start, duration)
	return true
end

function IconButton:SetCooldownFromDuration(durationObject)
	local cooldown = self.cooldown
	if type(cooldown.SetCooldownFromDurationObject) ~= "function" then
		Widgets.LogOnce("cooldown-object", "Cooldown:SetCooldownFromDurationObject is missing; the cooldown is not shown")
		return false
	end
	cooldown:SetCooldownFromDurationObject(durationObject)
	return true
end

function IconButton:ClearCooldown()
	self.cooldown:Clear()
end

function IconButton:SetProc(on)
	self.proc = on and true or false
	if self.proc and not self.procGlow then
		self.procGlow = Widgets.Glow(self, { kind = "proc" })
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
		self.placedOffset = nil
		local inset = Widgets.Snap(self, TEXT_INSET)
		self.hotkey:ClearAllPoints()
		self.hotkey:SetPoint("TOPRIGHT", self, "TOPRIGHT", -inset, -inset)
		self.count:ClearAllPoints()
		self.count:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, inset)
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
	button.usable = true
	button.chrome = Widgets.Chrome(button, { shape = "tile", fill = "raised", shadow = false })
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
	button.hoverGlow = Widgets.Glow(button, { kind = "selection" })
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
	button.cooldown = cooldown
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
