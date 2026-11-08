-- Style.lua: the fonts, accent tints, glows and tooltips the Cooldowns icons share.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets = K.Tokens, K.Widgets

local Style = {}
ns.Style = Style

function Style.FontPath(choice, role)
	if choice == "kit" or type(choice) ~= "string" then
		return (Tokens.Font(role or "number"))
	end
	return choice
end

function Style.Font(text, choice, size, outline, role)
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
	local ok = text:SetFont(Style.FontPath(choice, role), size * scale, flags)
	if ok == false then
		ns.LogOnce("font-" .. tostring(choice), "the font " .. tostring(choice) .. " did not load; using the kit's font")
		text:SetFont(Style.FontPath("kit", role), size * scale, flags)
	end
end

local formatter

local function Formatter()
	if formatter ~= nil then
		return formatter or nil
	end
	formatter = false
	local util, E = C_StringUtil, Enum
	if not (util and type(util.CreateSecondsFormatter) == "function" and E and E.SecondsFormatterAbbreviation and E.SecondsFormatterRounding and E.SecondsFormatterInterval) then
		ns.LogOnce("countdown", "C_StringUtil.CreateSecondsFormatter is missing; countdowns keep the engine's numbers")
		return nil
	end
	local ok, made = pcall(function()
		local f = util.CreateSecondsFormatter()
		f:SetDefaultAbbreviation(E.SecondsFormatterAbbreviation.OneLetter)
		f:SetRounding(E.SecondsFormatterRounding.Truncate)
		f:SetCanRoundUpLastUnit(true)
		f:SetMinInterval(E.SecondsFormatterInterval.Seconds)
		f:SetDesiredUnitCount(1)
		if E.SecondsFormatterIntervalWhitespace and E.SecondsFormatterIntervalWhitespace.Strip ~= nil then
			f:SetStripIntervalWhitespace(E.SecondsFormatterIntervalWhitespace.Strip)
		end
		return f
	end)
	if ok and made then
		formatter = made
		ns.LogOnce("countdown", "countdowns read with a one-letter seconds formatter (4s, 2m)")
	else
		ns.LogOnce("countdown", "the countdown formatter failed (" .. tostring(made) .. "); countdowns keep the engine's numbers")
	end
	return formatter or nil
end

function Style.Countdown(cooldown)
	if type(cooldown) ~= "table" or type(cooldown.SetCountdownFormatter) ~= "function" then
		return false
	end
	local f = Formatter()
	if not f then
		return false
	end
	local ok, err = pcall(cooldown.SetCountdownFormatter, cooldown, f)
	if not ok then
		ns.LogOnce("countdown-set", "SetCountdownFormatter failed (" .. tostring(err) .. "); countdowns keep the engine's numbers")
	end
	return ok
end

local function Custom()
	local current = ns.Settings.current
	return current.accent == "custom" and current.accentR ~= nil
end

function Style.Accent(icon)
	if Custom() then
		local r, g, b = ns.Settings.Accent()
		icon:SetAccent(r, g, b)
		icon.readyGlow:SetColorRGB(r, g, b)
	else
		icon:SetAccent()
		icon.readyGlow:SetColorRGB()
	end
end

local function AfterPaint(icon)
	local usable = icon.usable and icon:IsEnabled() ~= false
	if usable and icon.greyWhileCooling and icon.onCooldown then
		local tint = icon.tint
		K.Icons.Shade(icon.icon, tint[1], tint[2], tint[3], true)
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
	icon.readyGlow = Widgets.Glow(icon, { kind = "selection" })
	Style.Tooltips(icon)
	return icon
end

function Style.Tooltips(frame)
	frame:HookScript("OnEnter", ShowTooltip)
	frame:HookScript("OnLeave", HideTooltip)
end

function Style.SetProc(icon, on)
	on = on and true or false
	if icon.proc == on then
		return
	end
	icon:SetProc(on)
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
