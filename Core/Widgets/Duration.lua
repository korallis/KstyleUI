-- Duration.lua: one duration format for every timer in the kit ("24s", "8m", "2h"; "8m 12s" long; tenths under three seconds): the engine's own aura formatter for secret durations, and the same bands for plain numbers.
local _, ns = ...

local Widgets = ns.Widgets

local floor, ceil, max, format = math.floor, math.ceil, math.max, string.format

local Duration = {}
Widgets.Duration = Duration

Duration.DECIMAL_BELOW = 3
local SECONDS_BAND = 91
local MINUTES_BAND = 5401
local HOURS_BAND = 129601
local MINUTE, HOUR, DAY = 60, 3600, 86400

local made = {}

local function Engine()
	local inbound = AuraContainerInbound
	if type(inbound) == "table" and type(inbound.GetDefaultAuraDurationFormatter) == "function" then
		local ok, formatter = pcall(inbound.GetDefaultAuraDurationFormatter)
		if ok and formatter ~= nil then
			return formatter
		end
	end
	return nil
end

local function Build(kind)
	local util, E = C_StringUtil, Enum
	if not (util and type(util.CreateSecondsFormatter) == "function" and E and E.SecondsFormatterAbbreviation and E.SecondsFormatterRounding and E.SecondsFormatterInterval) then
		return nil
	end
	local ok, formatter = pcall(function()
		local f = util.CreateSecondsFormatter()
		f:SetDefaultAbbreviation(E.SecondsFormatterAbbreviation.OneLetter)
		f:SetRounding(E.SecondsFormatterRounding.Truncate)
		f:SetCanRoundUpLastUnit(true)
		f:SetMinInterval(E.SecondsFormatterInterval.Seconds)
		if kind == "long" then
			f:SetDesiredUnitCount(2)
		else
			f:SetDesiredUnitCount(1)
			if kind == "decimal" then
				f:SetMillisecondsThreshold(Duration.DECIMAL_BELOW)
			end
		end
		return f
	end)
	return ok and formatter or nil
end

function Duration.Formatter(kind)
	kind = kind or "short"
	if made[kind] == nil then
		local formatter = kind == "short" and Engine() or nil
		made[kind] = formatter or Build(kind) or false
	end
	return made[kind] or nil
end

local function Short(seconds)
	if seconds < SECONDS_BAND then
		return format("%ds", floor(seconds))
	elseif seconds < MINUTES_BAND then
		return format("%dm", ceil(seconds / MINUTE))
	elseif seconds < HOURS_BAND then
		return format("%dh", ceil(seconds / HOUR))
	end
	return format("%dd", ceil(seconds / DAY))
end

local function Long(seconds)
	seconds = floor(seconds)
	if seconds < MINUTE then
		return format("%ds", seconds)
	elseif seconds < HOUR then
		return format("%dm %ds", floor(seconds / MINUTE), seconds % MINUTE)
	elseif seconds < DAY then
		return format("%dh %dm", floor(seconds / HOUR), floor(seconds % HOUR / MINUTE))
	end
	return format("%dd %dh", floor(seconds / DAY), floor(seconds % DAY / HOUR))
end

function Duration.Format(seconds, kind)
	if kind == "none" or (issecretvalue and issecretvalue(seconds)) or type(seconds) ~= "number" or seconds ~= seconds then
		return ""
	end
	seconds = max(0, seconds)
	if kind == "long" then
		return Long(seconds)
	elseif kind == "decimal" and seconds < Duration.DECIMAL_BELOW then
		return format("%.1f", floor(seconds * 10) / 10)
	end
	return Short(seconds)
end
