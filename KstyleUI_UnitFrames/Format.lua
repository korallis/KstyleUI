-- Format.lua: health and power text that passes secret values straight to the font string, and the room each format needs.
local _, ns = ...

local K = KstyleUI
local L = K.L

local Format = {}
ns.Format = Format

local ceil = math.ceil

local COLUMN = { none = 0, percent = 3.2, current = 3.8, currentMax = 7, both = 10.4 }
local PERCENT = "%.0f%%"
local CURRENT_MAX = "%s / %s"
local BOTH = "%s / %s  %.0f%%"

function Format.ColumnWidth(format, size)
	return ceil((COLUMN[format] or 0) * size)
end

local curve
local curveTried = false

local function Log(message)
	K.DevTest.Log("UnitFrames", message)
end

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end

local function Curve()
	if curveTried then
		return curve
	end
	curveTried = true
	local util = C_CurveUtil
	if util and type(util.CreateCurve) == "function" then
		local ok, made = pcall(util.CreateCurve)
		if ok and made then
			local kinds = Enum and Enum.LuaCurveType
			if kinds and kinds.Linear and made.SetType then
				made:SetType(kinds.Linear)
			end
			made:AddPoint(0, 0)
			made:AddPoint(1, 100)
			curve = made
			Log("percent text: C_CurveUtil curve scaled to 100")
			return curve
		end
	end
	local constants = CurveConstants
	if constants and constants.ScaleTo100 then
		curve = constants.ScaleTo100
		Log("percent text: CurveConstants.ScaleTo100")
		return curve
	end
	Log("percent text: no curve API; percentages show current and max instead")
	return nil
end

function Format.ResetCurve()
	curve, curveTried = nil, false
end

local function Abbreviate(value)
	if AbbreviateNumbers then
		return AbbreviateNumbers(value)
	end
	LogOnce("abbreviate", "AbbreviateNumbers is missing; numbers show in full")
	return tostring(value)
end

local function Status(text, unit)
	if UnitIsConnected and not UnitIsConnected(unit) then
		text:SetText(L["Offline"])
		return true
	end
	if UnitIsGhost and UnitIsGhost(unit) then
		text:SetText(L["Ghost"])
		return true
	end
	if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
		text:SetText(L["Dead"])
		return true
	end
	return false
end

local function Write(text, format, current, max, percent, hasPercent)
	if format == "current" then
		text:SetText(Abbreviate(current))
	elseif format == "percent" and hasPercent then
		text:SetFormattedText(PERCENT, percent)
	elseif format == "both" and hasPercent then
		text:SetFormattedText(BOTH, Abbreviate(current), Abbreviate(max), percent)
	else
		text:SetFormattedText(CURRENT_MAX, Abbreviate(current), Abbreviate(max))
	end
end

function Format.Health(text, unit, format)
	if format == "none" then
		text:SetText("")
		return
	end
	if Status(text, unit) then
		return
	end
	local percent, hasPercent
	if format == "percent" or format == "both" then
		local c = Curve()
		if c and UnitHealthPercent then
			hasPercent = true
			percent = UnitHealthPercent(unit, true, c)
		end
	end
	Write(text, format, UnitHealth(unit), UnitHealthMax(unit), percent, hasPercent)
end

function Format.Power(text, unit, format, powerType)
	if format == "none" then
		text:SetText("")
		return
	end
	if UnitIsConnected and not UnitIsConnected(unit) then
		text:SetText("")
		return
	end
	local percent, hasPercent
	if format == "percent" or format == "both" then
		local c = Curve()
		if c and UnitPowerPercent then
			hasPercent = true
			percent = UnitPowerPercent(unit, powerType, false, c)
		end
	end
	Write(text, format, UnitPower(unit, powerType), UnitPowerMax(unit, powerType), percent, hasPercent)
end

function Format.Sample(text, format, current, max)
	if format == "none" then
		text:SetText("")
		return
	end
	local percent = max > 0 and current / max * 100 or 0
	Write(text, format, current, max, percent, true)
end
