-- Format.lua: health and power text that passes secret values straight to the font string, and the room each format needs.
local _, ns = ...

local K = KstyleUI
local L = K.L

local Format = {}
ns.Format = Format

local ceil = math.ceil

local COLUMN = { none = 0, legacy = 0, auto = 3.8, percent = 3.2, current = 3.8, currentMax = 7, both = 10.4 }
local PERCENT = { [0] = "%.0f%%", [true] = "%.1f%%", [2] = "%.2f%%", bare = "%.0f", trim = "%s%%" }
local CURRENT_MAX = "%s / %s"
local BOTH = { [0] = "%s / %s  %.0f%%", [true] = "%s / %s  %.1f%%", [2] = "%s / %s  %.2f%%", bare = "%s / %s  %.0f", trim = "%s / %s  %s%%" }
local MAX = "/ %s"

local VALUE_EM = { current = 0.9, currentMax = 1.8, both = 1.8 }

function Format.ColumnWidth(format, size, decimal, values)
	local em = COLUMN[format] or 0
	if decimal and (format == "percent" or format == "both") then
		em = em + ((decimal == 2 or decimal == -2) and 1 or 0.4)
	end
	if values then em = em + (VALUE_EM[format] or 0) end
	return ceil(em * size)
end

local curve
local curveTried = false

local function Log(message)
	K.DevTest.Log("UnitFrames", message)
end

local function Linear(low, high)
	local util = C_CurveUtil
	if not (util and type(util.CreateCurve) == "function") then
		return nil
	end
	local ok, made = pcall(util.CreateCurve)
	if not (ok and made) then
		return nil
	end
	local kinds = Enum and Enum.LuaCurveType
	if kinds and kinds.Linear and made.SetType then
		made:SetType(kinds.Linear)
	end
	made:AddPoint(0, low)
	made:AddPoint(1, high)
	return made
end

local function Curve()
	if curveTried then
		return curve
	end
	curveTried = true
	curve = Linear(0, 100)
	if curve then
		Log("percent text: C_CurveUtil curve scaled to 100")
		return curve
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

local trims = {}
local TRIM_PROBES = { { { 415.5, "41.5" }, { 410.5, "41" }, { 0.5, "0" } }, { { 4127.5, "41.27" }, { 4120.5, "41.2" }, { 4100.5, "41" } } }
local function Trim(places)
	if trims[places] ~= nil then return trims[places] end
	trims[places] = false
	local scale = 10 ^ places
	if type(AbbreviateNumbers) ~= "function" then
		Log("trailing zeros: AbbreviateNumbers is missing; decimals keep their zeros")
		return nil
	end
	local options = { breakpointData = { { breakpoint = 0, abbreviation = "", significandDivisor = 1, fractionDivisor = scale, abbreviationIsGlobal = false } } }
	for _, probe in ipairs(TRIM_PROBES[places]) do
		local ok, text = pcall(AbbreviateNumbers, probe[1], options)
		if not ok or K.Widgets.IsSecret(text) or type(text) ~= "string" or text:gsub(",", ".") ~= probe[2] then
			Log("trailing zeros: AbbreviateNumbers writes " .. tostring(text) .. "; decimals keep their zeros")
			return nil
		end
	end
	local made = Linear(0.5, 100 * scale + 0.5)
	if not made then
		Log("trailing zeros: C_CurveUtil.CreateCurve failed; decimals keep their zeros")
		return nil
	end
	trims[places] = { curve = made, options = options, scale = scale }
	return trims[places]
end

local Abbreviate = K.Widgets.ShortNumber

local TWO = {}
for i, point in ipairs({ { 1e9, "B", 1e7 }, { 1e6, "M", 1e4 }, { 1e3, "K", 10 }, { 1, "", 1 } }) do
	TWO[i] = { breakpoint = point[1], abbreviation = point[2], significandDivisor = point[3], fractionDivisor = point[3] > 1 and 100 or 1, abbreviationIsGlobal = false }
end
local twoOptions

local function TwoPlaces(value)
	if not K.Widgets.IsSecret(value) then
		if type(value) ~= "number" or value ~= value or value < 1000 or value == math.huge then return Abbreviate(value) end
		for _, point in ipairs(TWO) do
			if value >= point.breakpoint then return (math.floor(value / point.significandDivisor) / point.fractionDivisor) .. point.abbreviation end
		end
	end
	if twoOptions == nil then
		local ok, text = false, nil
		if type(AbbreviateNumbers) == "function" then ok, text = pcall(AbbreviateNumbers, 240550, { breakpointData = TWO }) end
		twoOptions = ok and not K.Widgets.IsSecret(text) and text == "240.55K" and { breakpointData = TWO } or false
		if not twoOptions then Log("boss values: AbbreviateNumbers does not write two decimals; secret values keep one") end
	end
	return twoOptions and AbbreviateNumbers(value, twoOptions) or Abbreviate(value)
end

local function Short(text, value)
	return text.twoPlaces and TwoPlaces(value) or Abbreviate(value)
end

local function Gone(unit)
	if UnitIsConnected and not UnitIsConnected(unit) then
		return L["Offline"]
	end
	if UnitIsGhost and UnitIsGhost(unit) then
		return L["Ghost"]
	end
	if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
		return L["Dead"]
	end
	return nil
end

local function Status(text, unit)
	local label = Gone(unit)
	if label then
		text:SetText(label)
		return true
	end
	return false
end

local function Write(text, format, current, max, percent, hasPercent, decimal, bare)
	if hasPercent and not decimal then percent = K.Widgets.WholePercent(percent) end
	local places = bare and "bare" or decimal or 0
	if format == "current" then
		text:SetText(Short(text, current))
	elseif format == "percent" and hasPercent then
		text:SetFormattedText(PERCENT[places], percent)
	elseif format == "both" and hasPercent then
		text:SetFormattedText(BOTH[places], Short(text, current), Short(text, max), percent)
	else
		text:SetFormattedText(CURRENT_MAX, Short(text, current), Short(text, max))
	end
end

function Format.Health(text, unit, format, decimal)
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
			local trim = decimal and decimal ~= true and decimal < 0 and Trim(-decimal)
			if trim then
				percent, decimal = AbbreviateNumbers(UnitHealthPercent(unit, true, trim.curve), trim.options), "trim"
			else
				percent = UnitHealthPercent(unit, true, c)
				if decimal and decimal ~= true and decimal < 0 then decimal = decimal == -2 and 2 or true end
			end
		end
	end
	Write(text, format, UnitHealth(unit), UnitHealthMax(unit), percent, hasPercent, decimal)
end

function Format.Main(format)
	return format == "both" and "percent" or format
end

function Format.Shown(format, detailShown)
	local main = detailShown and Format.Main(format) or format
	if (main == "percent" or main == "both") and not (Curve() and UnitHealthPercent) then
		return "currentMax"
	end
	return main
end

function Format.HealthDetail(text, unit, format)
	if format ~= "both" or Gone(unit) or not (Curve() and UnitHealthPercent) then
		text:SetText("")
		return
	end
	Write(text, "currentMax", UnitHealth(unit), UnitHealthMax(unit))
end

function Format.Max(text, unit)
	if Gone(unit) then
		text:SetText("")
		return
	end
	text:SetFormattedText(MAX, Short(text, UnitHealthMax(unit)))
end

function Format.SampleMax(text, max)
	text:SetFormattedText(MAX, Short(text, max))
end

function Format.PowerMode(unit, format, powerType)
	if format == "legacy" then return "none" end
	if format ~= "auto" then return format end
	if issecretvalue and issecretvalue(powerType) then return "current" end
	if powerType == nil and UnitPowerType then powerType = UnitPowerType(unit) end
	return powerType == 0 and "percent" or "current"
end

function Format.Power(text, unit, format, powerType, bare)
	format = Format.PowerMode(unit, format, powerType)
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
	Write(text, format, UnitPower(unit, powerType), UnitPowerMax(unit, powerType), percent, hasPercent, nil, bare)
end

function Format.SampleDetail(text, format, current, max)
	if format ~= "both" then
		text:SetText("")
		return
	end
	Write(text, "currentMax", current, max)
end

function Format.Sample(text, format, current, max, decimal, bare)
	if format == "legacy" then format = "none" end
	if format == "auto" then format = "percent" end
	if format == "none" then
		text:SetText("")
		return
	end
	local percent = max > 0 and current / max * 100 or 0
	local trim = decimal and decimal ~= true and decimal < 0 and Trim(-decimal)
	if trim then
		percent, decimal = AbbreviateNumbers(percent * trim.scale + 0.5, trim.options), "trim"
	elseif decimal and decimal ~= true and decimal < 0 then
		decimal = decimal == -2 and 2 or true
	end
	Write(text, format, current, max, percent, true, decimal, bare)
end
