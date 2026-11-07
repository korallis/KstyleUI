-- Style.lua: the fonts, accent tints, glows and tooltips the Cooldowns icons share.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets = K.Tokens, K.Widgets

local Style = {}
ns.Style = Style

local REST_EDGE_ALPHA = 0.5
local HOVER_EDGE_ALPHA = 0.5

function Style.FontPath(choice)
	if choice == "kit" or type(choice) ~= "string" then
		return (Tokens.Font("number"))
	end
	return choice
end

function Style.Font(text, choice, size, outline)
	if not text then
		return
	end
	local scale = 1
	if K.Theme.FontScale then
		scale = K.Theme.FontScale() or 1
	end
	local flags = outline
	if flags == nil or flags == "none" then
		flags = ""
	end
	local ok = text:SetFont(Style.FontPath(choice), size * scale, flags)
	if ok == false then
		ns.LogOnce("font-" .. tostring(choice), "the font " .. tostring(choice) .. " did not load; using the kit's number font")
		text:SetFont(Style.FontPath("kit"), size * scale, flags)
	end
end

local function Custom()
	local current = ns.Settings.current
	return current.accent == "custom" and current.accentR ~= nil
end

local function TintGlow(glow)
	if Custom() then
		local r, g, b = ns.Settings.Accent()
		Widgets.ColorSlice(glow.slice, r, g, b, 1)
	end
end

function Style.WrapGlow(glow)
	if not glow or glow.cooldownsWrapped then
		return glow
	end
	glow.cooldownsWrapped = true
	local restyle = glow.Restyle
	glow.Restyle = function(self)
		restyle(self)
		TintGlow(self)
	end
	TintGlow(glow)
	return glow
end

local function AfterPaint(icon)
	local usable = icon.usable and icon:IsEnabled() ~= false
	if not usable then
		return
	end
	if icon.greyWhileCooling and icon.onCooldown then
		K.Icons.Shade(icon.icon, 1, 1, 1, true)
	end
	if Custom() and not icon.cooling then
		local r, g, b = ns.Settings.Accent()
		if icon.proc or icon.selected then
			icon.chrome:SetEdgeRGBA(r, g, b, 1)
		else
			icon.chrome:SetEdgeRGBA(r, g, b, REST_EDGE_ALPHA + HOVER_EDGE_ALPHA * (icon.hoverT or 0))
		end
	end
end

local function ShowTooltip(icon)
	local entry = icon.entry
	local tip = GameTooltip
	if not (ns.Settings.current.tooltips and entry and tip) then
		return
	end
	local spell = entry.tooltipSpellID or entry.spell
	if not spell or type(tip.SetSpellByID) ~= "function" then
		return
	end
	tip:SetOwner(icon, "ANCHOR_TOP")
	tip:SetSpellByID(spell)
	tip:Show()
end

local function HideTooltip(icon)
	local tip = GameTooltip
	if tip and type(tip.IsOwned) == "function" and tip:IsOwned(icon) then
		tip:Hide()
	end
end

function Style.Decorate(icon)
	local paint = icon.Paint
	icon.Paint = function(self)
		paint(self)
		AfterPaint(self)
	end
	local charge = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	charge:SetAllPoints(icon.icon)
	charge:SetDrawSwipe(false)
	charge:SetDrawEdge(true)
	charge:SetDrawBling(false)
	charge:SetHideCountdownNumbers(true)
	icon.charge = charge
	icon.overlay:SetFrameLevel(charge:GetFrameLevel() + 1)
	icon.readyGlow = Style.WrapGlow(Widgets.Glow(icon, { kind = "selection" }))
	icon:HookScript("OnEnter", ShowTooltip)
	icon:HookScript("OnLeave", HideTooltip)
	return icon
end

function Style.SetProc(icon, on)
	on = on and true or false
	if icon.proc == on then
		return
	end
	icon:SetProc(on)
	Style.WrapGlow(icon.procGlow)
end

function Style.SetReady(icon, on)
	on = on and true or false
	if icon.ready == on then
		return
	end
	icon.ready = on
	if on then
		icon.readyGlow:Start()
	else
		icon.readyGlow:Stop()
	end
end

function Style.Mouse(frame, tooltips)
	if tooltips then
		frame:EnableMouse(true)
		frame:SetMouseClickEnabled(false)
	else
		frame:EnableMouse(false)
	end
end
