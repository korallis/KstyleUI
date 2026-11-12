-- Socket.lua: the action bars' state on the shared slot: the countdown formatter, the quiet or accent rim, and the range and resource tints.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens

local Socket = {}
ns.Socket = Socket

Socket.TOKENS = {
	gilt = "giltLit",
	quietRim = "slotRim",
	cool = "rare",
}

local POWER_DIM = 0.7

local formatter

local function Formatter()
	if formatter ~= nil then
		return formatter or nil
	end
	formatter = false
	local util, E = C_StringUtil, Enum
	if not (util and type(util.CreateSecondsFormatter) == "function" and E and E.SecondsFormatterAbbreviation and E.SecondsFormatterRounding and E.SecondsFormatterInterval) then
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
	formatter = ok and made or false
	return formatter or nil
end

local function Countdown(b)
	local cooldown = b.cooldown
	if b.kCountdown or type(cooldown) ~= "table" or type(cooldown.SetCountdownFormatter) ~= "function" then
		return
	end
	local f = Formatter()
	if f and pcall(cooldown.SetCountdownFormatter, cooldown, f) then
		b.kCountdown = true
	end
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
	Countdown(b)
end

function Socket.Tint(b, key)
	local color = key == "rangeColor" and ns.Config(key)
	if color then
		b.hotkey:SetTextColor(color.r, color.g, color.b)
	else
		Widgets.TextColor(b.hotkey, "white")
	end
end

function Socket.Decorate(b)
	local paint, restyle = b.Paint, b.Restyle
	b.Paint = function(self)
		self.rimToken = Quiet() and Socket.TOKENS.quietRim or nil
		paint(self)
		AfterPaint(self)
	end
	b.Restyle = function(self)
		Socket.Place(self)
		restyle(self)
	end
	Socket.Place(b)
	Socket.Tint(b)
	b:Paint()
	return b
end
