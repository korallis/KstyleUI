-- Socket.lua: the Lumen socket states the action buttons add to the kit's icon button: a quiet rim, the keybind at the top left, a centred timer, a gilt breathing proc, cool no-resource and red out-of-range tints, and quiet empty sockets.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Motion = K.Widgets, K.Tokens, K.Motion

local Socket = {}
ns.Socket = Socket

Socket.TOKENS = {
	gilt = "giltLit",
	quietRim = "edgeInner",
	cool = "rare",
}

local TEXT_INSET = 3
local QUIET_HOVER = 0.5
local POWER_DIM = 0.7
local EMPTY_REST, EMPTY_COMBAT = 0.35, 0.12
local BREATH = 0.7
local BREATH_LOW, BREATH_HIGH = 0.45, 1
local GLOW_ALPHA = 0.55
local GLOW_LEVEL = 1

Socket.inCombat = false

function Socket.EmptyAlpha()
	return Socket.inCombat and EMPTY_COMBAT or EMPTY_REST
end

function Socket.SetCombat(on)
	Socket.inCombat = on == true
end

local function Quiet()
	return ns.Config("accent") == "quiet"
end

local function Usable(b)
	return b.usable and b:IsEnabled() ~= false
end

local function AfterPaint(b)
	if not Usable(b) then
		return
	end
	local chrome = b.chrome
	if b.proc then
		local r, g, bl = Tokens.Color(Socket.TOKENS.gilt)
		chrome:SetRim(r, g, bl, 1)
	elseif Quiet() and not b.selected and not (b.cooling and b.realCooldown) then
		local r, g, bl, a = Tokens.Color(Socket.TOKENS.quietRim)
		local hr, hg, hb, ha = Tokens.Color("textHover")
		chrome:SetRim(Widgets.Mix(r, g, bl, a, hr, hg, hb, ha, QUIET_HOVER * (b.hoverT or 0)))
	end
	if b.lacksPower then
		local r, g, bl = b.icon:GetVertexColor()
		if Widgets.IsSecret(r) or Widgets.IsSecret(g) or Widgets.IsSecret(bl) or type(r) ~= "number" then
			b.icon:SetDesaturated(true)
		else
			Widgets.ShadeIcon(b.icon, r * POWER_DIM, g * POWER_DIM, bl * POWER_DIM, true)
		end
	end
end

function Socket.Place(b)
	if not Widgets.MayMove(b) then
		return
	end
	local inset = Widgets.Snap(b, TEXT_INSET)
	b.hotkey:ClearAllPoints()
	b.hotkey:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
	b.hotkey:SetJustifyH("LEFT")
	local countdown = b.countdown
	if countdown then
		countdown:ClearAllPoints()
		countdown:SetPoint("CENTER", b.icon, "CENTER")
		countdown:SetJustifyH("CENTER")
	end
end

local function Glow(b)
	local glow = b.lumenGlow
	if glow then
		return glow
	end
	glow = CreateFrame("Frame", nil, b)
	glow:SetAllPoints(b.icon)
	glow:SetFrameLevel(b.cooldown:GetFrameLevel() + GLOW_LEVEL)
	local texture = glow:CreateTexture(nil, "OVERLAY")
	texture:SetTexture((Tokens.Texture("glow")))
	texture:SetBlendMode("ADD")
	texture:SetAllPoints(glow)
	texture:AddMaskTexture(b.mask)
	glow.texture = texture
	local breath = glow:CreateAnimationGroup()
	breath:SetLooping("BOUNCE")
	local alpha = breath:CreateAnimation("Alpha")
	alpha:SetFromAlpha(BREATH_HIGH)
	alpha:SetToAlpha(BREATH_LOW)
	alpha:SetDuration(BREATH)
	alpha:SetSmoothing("IN_OUT")
	glow.breath = breath
	glow:Hide()
	b.lumenGlow = glow
	return glow
end

function Socket.SetProc(b, on)
	on = on == true
	if on == (b.proc == true) then
		return
	end
	b.proc = on
	local glow = Glow(b)
	if on then
		local r, g, bl = Tokens.Color(Socket.TOKENS.gilt)
		glow.texture:SetVertexColor(r, g, bl, GLOW_ALPHA)
		glow:SetAlpha(BREATH_HIGH)
		glow:Show()
		if Motion.ReducedMotion() then
			glow.breath:Stop()
		else
			glow.breath:Play()
		end
	else
		glow.breath:Stop()
		glow:Hide()
	end
	b:Paint()
end

function Socket.Tint(b, key)
	local color = key == "rangeColor" and ns.Config(key)
	if color then
		b.hotkey:SetTextColor(color.r, color.g, color.b)
	else
		Widgets.TextColor(b.hotkey, "textEmphasis")
	end
end

function Socket.Decorate(b)
	local paint, restyle = b.Paint, b.Restyle
	b.Paint = function(self)
		paint(self)
		AfterPaint(self)
	end
	b.Restyle = function(self)
		restyle(self)
		Socket.Place(self)
	end
	b.SetProc = Socket.SetProc
	Socket.Place(b)
	b:Paint()
	return b
end
