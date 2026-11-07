-- Unit.lua: reads a unit into a group frame: name, health, power, colours, status, portrait and range, passing secrets straight to the widgets.
local _, ns = ...

local K = KstyleUI
local Tokens, Theme, L = K.Tokens, K.Theme, K.L
local Settings, Style = ns.Settings, ns.Style

local Unit = {}
ns.Unit = Unit

local PERCENT_FORMAT = "%.0f%%"
local DEFICIT_FORMAT = "-%s"
local CURRENT_MAX_FORMAT = "%s / %s"
local CURRENT_PERCENT_FORMAT = "%s  %.0f%%"
local UNKNOWN_LEVEL = "??"

local UNIT_EVENTS = {
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_POWER_UPDATE",
	"UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_LEVEL", "UNIT_IN_RANGE_UPDATE",
}
Unit.EVENTS = UNIT_EVENTS

local STATUS_TEXT = { offline = L["Offline"], dead = L["Dead"], ghost = L["Ghost"] }

local frames = {}
Unit.frames = frames

local issecretvalue = issecretvalue or function()
	return false
end

local function IsSecret(v)
	return issecretvalue(v) == true
end
Unit.IsSecret = IsSecret

local percentCurve, fullCurve
local function Curves()
	if percentCurve ~= nil then
		return percentCurve or nil, fullCurve or nil
	end
	percentCurve, fullCurve = false, false
	local util = C_CurveUtil
	local constants = CurveConstants
	if constants and constants.ScaleTo100 then
		percentCurve = constants.ScaleTo100
	elseif util and util.CreateCurve then
		local curve = util.CreateCurve()
		curve:AddPoint(0, 0)
		curve:AddPoint(1, 100)
		percentCurve = curve
	end
	if util and util.CreateCurve and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then
		local curve = util.CreateCurve()
		curve:SetType(Enum.LuaCurveType.Step)
		curve:AddPoint(0, 1)
		curve:AddPoint(1, 0)
		fullCurve = curve
	end
	if not UnitHealthPercent then
		percentCurve, fullCurve = false, false
		Style.LogOnce("noPercent", "UnitHealthPercent is missing; percent health shows the current value instead")
	elseif not percentCurve then
		Style.LogOnce("noCurve", "C_CurveUtil and CurveConstants are missing; percent health shows the current value instead")
	else
		Style.LogOnce("curve", "health text uses UnitHealthPercent with a curve")
	end
	return percentCurve or nil, fullCurve or nil
end

local function Abbreviate(value)
	if AbbreviateNumbers then
		return AbbreviateNumbers(value)
	end
	return value
end

local function Status(f)
	local unit = f.unit
	local status
	local connected = UnitIsConnected(unit)
	if not IsSecret(connected) and connected == false then
		status = "offline"
	else
		local dead = UnitIsDeadOrGhost(unit)
		if not IsSecret(dead) and dead == true then
			local ghost = UnitIsGhost and UnitIsGhost(unit)
			status = (not IsSecret(ghost) and ghost == true) and "ghost" or "dead"
		end
	end
	f.status = status
end

local function HealthText(f)
	local text = f.healthText
	if f.status then
		text:SetAlpha(1)
		text:SetText(STATUS_TEXT[f.status])
		return
	end
	local format = Settings.current[f.kind].healthText
	if format == "NONE" then
		text:SetText("")
		return
	end
	text:SetAlpha(1)
	local unit = f.unit
	local percent, full = Curves()
	if format == "PERCENT" and percent then
		text:SetFormattedText(PERCENT_FORMAT, UnitHealthPercent(unit, true, percent))
	elseif format == "DEFICIT" then
		text:SetFormattedText(DEFICIT_FORMAT, Abbreviate(UnitHealthMissing(unit)))
		if full then
			text:SetAlpha(UnitHealthPercent(unit, true, full))
		end
	elseif format == "CURRENT_MAX" then
		text:SetFormattedText(CURRENT_MAX_FORMAT, Abbreviate(UnitHealth(unit)), Abbreviate(UnitHealthMax(unit)))
	elseif format == "CURRENT_PERCENT" and percent then
		text:SetFormattedText(CURRENT_PERCENT_FORMAT, Abbreviate(UnitHealth(unit)), UnitHealthPercent(unit, true, percent))
	else
		text:SetText(Abbreviate(UnitHealth(unit)))
	end
end

function Unit.ClassColor(class)
	return Theme.ClassColorForWidget(class)
end

local function Colors(f)
	local unit = f.unit
	local _, class = UnitClass(unit)
	local cr, cg, cb = Unit.ClassColor(class)
	local health = Settings.current.health
	if f.status then
		f.health:SetBarColor(Tokens.Color("textDisabled"))
	elseif health.colorSource == "class" then
		f.health:SetBarColor(cr, cg, cb)
	elseif health.colorSource == "reaction" then
		f.health:SetBarColor(Theme.ReactionColor(UnitReaction and UnitReaction(unit, "player")))
	else
		local c = health.color
		f.health:SetBarColor(c.r, c.g, c.b)
	end
	if Settings.current.text.nameColorSource == "class" then
		f.name:SetTextColor(cr, cg, cb)
	end
	if f.showPortrait then
		f.ring:SetVertexColor(cr, cg, cb)
	end
end

local function PowerColor(f)
	if not f.showPower then
		return
	end
	local power = Settings.current.power
	if power.colorSource == "custom" then
		local c = power.color
		f.power:SetBarColor(c.r, c.g, c.b)
		return
	end
	local unit = f.unit
	if power.colorSource == "class" then
		local _, class = UnitClass(unit)
		f.power:SetBarColor(Unit.ClassColor(class))
		return
	end
	local _, token = UnitPowerType(unit)
	local color = not IsSecret(token) and type(PowerBarColor) == "table" and type(token) == "string" and PowerBarColor[token]
	if type(color) == "table" and type(color.r) == "number" then
		f.power:SetBarColor(color.r, color.g, color.b)
	else
		f.power:SetBarColor(Tokens.Color("rare"))
	end
end

local function Power(f)
	if not f.showPower then
		return
	end
	local unit = f.unit
	f.power:SetBarRange(0, UnitPowerMax(unit))
	f.power:SetBarValue(UnitPower(unit))
end

local function Health(f)
	local unit = f.unit
	f.health:SetBarRange(0, UnitHealthMax(unit))
	if f.fresh then
		f.health:SetValue(UnitHealth(unit))
	else
		f.health:SetBarValue(UnitHealth(unit))
	end
	HealthText(f)
end

local function Name(f)
	local name = UnitName(f.unit)
	if IsSecret(name) or type(name) == "string" then
		f.name:SetText(name)
	else
		f.name:SetText("")
	end
end

local function Portrait(f)
	if f.showPortrait and SetPortraitTexture then
		SetPortraitTexture(f.portrait, f.unit)
	end
end

local function Level(f)
	if not f.showPortrait then
		return
	end
	local level = UnitLevel(f.unit)
	if not IsSecret(level) and (type(level) ~= "number" or level <= 0) then
		f.level:SetText(UNKNOWN_LEVEL)
	else
		f.level:SetText(level)
	end
end

local function IsPlayer(unit)
	if unit == "player" then
		return true
	end
	local same = UnitIsUnit(unit, "player")
	return not IsSecret(same) and same == true
end

local function Range(f)
	local range = Settings.current.range
	local unit = f.unit
	if not range.fade or IsPlayer(unit) or f.status == "offline" then
		f:SetAlpha(1)
		return
	end
	local inRange = UnitInRange(unit)
	if f.SetAlphaFromBoolean then
		f:SetAlphaFromBoolean(inRange, 1, range.alpha)
	elseif not issecretvalue(inRange) then
		f:SetAlpha(inRange and 1 or range.alpha)
	else
		f:SetAlpha(1)
	end
end
Unit.Range = Range

local function Target(f)
	local isTarget = UnitIsUnit(f.unit, "target")
	if f.target.SetAlphaFromBoolean then
		f.target:SetAlphaFromBoolean(isTarget, 1, 0)
	elseif not IsSecret(isTarget) then
		f.target:SetAlpha(isTarget and 1 or 0)
	end
end
Unit.Target = Target

local function StatusChanged(f)
	Status(f)
	Colors(f)
	HealthText(f)
	Range(f)
end

local HANDLERS = {
	UNIT_HEALTH = function(f)
		local before = f.status
		Status(f)
		if f.status ~= before then
			Colors(f)
			Range(f)
		end
		Health(f)
	end,
	UNIT_MAXHEALTH = Health,
	UNIT_NAME_UPDATE = function(f)
		Name(f)
		Colors(f)
	end,
	UNIT_CONNECTION = StatusChanged,
	UNIT_FLAGS = StatusChanged,
	UNIT_POWER_UPDATE = Power,
	UNIT_MAXPOWER = Power,
	UNIT_DISPLAYPOWER = function(f)
		PowerColor(f)
		Power(f)
	end,
	UNIT_PORTRAIT_UPDATE = Portrait,
	UNIT_MODEL_CHANGED = Portrait,
	UNIT_LEVEL = Level,
	UNIT_IN_RANGE_UPDATE = Range,
}
Unit.HANDLERS = HANDLERS

function Unit.OnEvent(f, event)
	local handler = HANDLERS[event]
	if handler and f.unit then
		handler(f)
	end
end

function Unit.Refresh(f)
	if not f.unit then
		return
	end
	Status(f)
	Name(f)
	Health(f)
	Colors(f)
	PowerColor(f)
	Power(f)
	Portrait(f)
	Level(f)
	Range(f)
	Target(f)
	local extra = Unit.extra
	for i = 1, #extra do
		extra[i](f)
	end
end

Unit.extra = {}

function Unit.Listen(f)
	f:UnregisterAllEvents()
	local unit = f.unit
	if not unit or not Unit.running then
		return
	end
	for i = 1, #UNIT_EVENTS do
		f:RegisterUnitEvent(UNIT_EVENTS[i], unit)
	end
	local more = Unit.events
	for i = 1, #more do
		f:RegisterUnitEvent(more[i], unit)
	end
end

Unit.events = {}

local known = {}
for i = 1, #UNIT_EVENTS do
	known[UNIT_EVENTS[i]] = true
end

function Unit.Chain(event, fn)
	local previous = HANDLERS[event]
	if previous then
		HANDLERS[event] = function(f)
			previous(f)
			fn(f)
		end
	else
		HANDLERS[event] = fn
	end
	if not known[event] then
		known[event] = true
		Unit.events[#Unit.events + 1] = event
	end
end

function Unit.Set(f, unit)
	if IsSecret(unit) then
		unit = nil
	end
	if f.unit ~= unit then
		f.unit = unit
		f.fresh = true
		Unit.Listen(f)
		local changed = Unit.changed
		for i = 1, #changed do
			changed[i](f)
		end
	end
	if unit and Unit.running then
		Unit.Refresh(f)
		f.fresh = false
	end
end

Unit.changed = {}

function Unit.Track(f)
	frames[#frames + 1] = f
end

function Unit.ForEach(fn)
	for i = 1, #frames do
		fn(frames[i])
	end
end

function Unit.RefreshAll()
	for i = 1, #frames do
		local f = frames[i]
		if f.unit then
			Unit.Refresh(f)
		end
	end
end

function Unit.TargetAll()
	for i = 1, #frames do
		local f = frames[i]
		if f.unit then
			Target(f)
		end
	end
end

function Unit.ListenAll()
	for i = 1, #frames do
		Unit.Listen(frames[i])
	end
end
