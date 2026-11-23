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
local NAME_LUMINANCE = 0.62

local UNIT_EVENTS = {
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_POWER_UPDATE",
	"UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_LEVEL", "UNIT_IN_RANGE_UPDATE",
}
Unit.EVENTS = UNIT_EVENTS

local STATUS_TEXT = { offline = L["Offline"], dead = L["Dead"], ghost = L["Ghost"] }
Unit.STATUS_TEXT = STATUS_TEXT

local frames = {}
Unit.frames = frames

local issecretvalue = issecretvalue or function()
	return false
end

local function IsSecret(v)
	return issecretvalue(v) == true
end
Unit.IsSecret = IsSecret

function Unit.Plain(value, kind)
	if IsSecret(value) or type(value) ~= kind then return nil end
	return value
end

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
Unit.Curves = Curves

local Abbreviate = K.Widgets.ShortNumber
function Unit.Abbreviate(value)
	return Abbreviate(value)
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
	if f.status ~= status then
		f.status = status
		Style.PlaceRowEnd(f)
		if Unit.OnStatus then Unit.OnStatus(f) end
	end
end

local function HealthText(f)
	local text = f.healthText
	if f.status then
		text:SetAlpha(1)
		text:SetTextColor(Tokens.Color("textEmphasis"))
		text:SetText(STATUS_TEXT[f.status])
		text:SetShown(true)
		return
	end
	local format = Settings.current[f.kind].healthText
	text:SetShown(format ~= "NONE")
	if format == "NONE" then
		text:SetText("")
		return
	end
	text:SetAlpha(1)
	local unit = f.unit
	K.Widgets.LowHealthText(text, unit, "textEmphasis")
	local percent, full = Curves()
	if format == "PERCENT" and percent then
		text:SetFormattedText(PERCENT_FORMAT, K.Widgets.WholePercent(UnitHealthPercent(unit, true, percent)))
	elseif format == "DEFICIT" then
		text:SetFormattedText(DEFICIT_FORMAT, Abbreviate(UnitHealthMissing(unit)))
		if full then
			text:SetAlpha(UnitHealthPercent(unit, true, full))
		end
	elseif format == "CURRENT_MAX" then
		text:SetFormattedText(CURRENT_MAX_FORMAT, Abbreviate(UnitHealth(unit)), Abbreviate(UnitHealthMax(unit)))
	elseif format == "CURRENT_PERCENT" and percent then
		text:SetFormattedText(CURRENT_PERCENT_FORMAT, Abbreviate(UnitHealth(unit)), K.Widgets.WholePercent(UnitHealthPercent(unit, true, percent)))
	else
		text:SetText(Abbreviate(UnitHealth(unit)))
	end
end

function Unit.ClassColor(class)
	return Theme.ClassColorForWidget(class)
end

function Unit.NameColor(class)
	return Theme.ClassTextColorForWidget(class, NAME_LUMINANCE)
end

function Unit.NameColored()
end

function Unit.ColorSources()
	local current = Settings.current
	return current.health.colorSource, current.text.nameColorSource
end

function Unit.StatusColor(status)
	local health = Settings.current.health
	if health.statusGrey then
		return Tokens.Color("textDisabled")
	end
	local c = status == "offline" and health.offlineColor or health.deadColor
	return c.r, c.g, c.b
end

function Unit.GradientStops()
	local h = Settings.current.health
	local stops = { { 0, h.gradientLow } }
	if h.gradientLowAt > 0 then stops[#stops + 1] = { h.gradientLowAt / 100, h.gradientLow } end
	stops[#stops + 1] = { 0.5, h.gradientMid }
	if h.gradientHighAt < 100 then stops[#stops + 1] = { h.gradientHighAt / 100, h.gradientHigh } end
	stops[#stops + 1] = { 1, h.gradientHigh }
	return stops
end

local gradient = {}
local function GradientCurves()
	local h = Settings.current.health
	if gradient.low == h.gradientLow and gradient.mid == h.gradientMid and gradient.high == h.gradientHigh
		and gradient.lowAt == h.gradientLowAt and gradient.highAt == h.gradientHighAt then
		return gradient.curves
	end
	gradient.low, gradient.mid, gradient.high, gradient.lowAt, gradient.highAt = h.gradientLow, h.gradientMid, h.gradientHigh, h.gradientLowAt, h.gradientHighAt
	gradient.curves = nil
	local util = C_CurveUtil
	if not (util and util.CreateCurve and UnitHealthPercent) then
		Style.LogOnce("noGradient", "C_CurveUtil or UnitHealthPercent is missing; the by-health colour keeps the full health colour")
		return nil
	end
	local curves, stops = {}, Unit.GradientStops()
	for i, channel in ipairs({ "r", "g", "b" }) do
		curves[i] = util.CreateCurve()
		for _, stop in ipairs(stops) do
			curves[i]:AddPoint(stop[1], stop[2][channel])
		end
	end
	gradient.curves = curves
	return curves
end

local function GradientColor(f)
	local alpha = Settings.current.health.alpha
	local curves = GradientCurves()
	if not curves then
		local c = Settings.current.health.gradientHigh
		f.health:SetBarColor(c.r, c.g, c.b, alpha)
		return
	end
	local unit = f.unit
	f.health:SetBarColor(UnitHealthPercent(unit, true, curves[1]), UnitHealthPercent(unit, true, curves[2]), UnitHealthPercent(unit, true, curves[3]), alpha)
end

local PowerColor

local function Colors(f)
	local unit = f.unit
	local _, class = UnitClass(unit)
	local cr, cg, cb = Unit.ClassColor(class)
	local health = Settings.current.health
	local idle = f.status and Settings.current.readable.track
	local alpha = idle and 0 or health.alpha
	local healthSource, nameSource = Unit.ColorSources(f)
	f.health:SetHealthUnit(nil)
	if (f.fillAlpha or 1) ~= alpha then
		f.health.fillClip:SetAlpha(alpha)
		f.power.fillClip:SetAlpha(idle and 0 or 1)
		f.fillAlpha = alpha
		PowerColor(f)
	end
	f.gradient = not f.status and healthSource == "gradient"
	if f.status then
		local r, g, b = Unit.StatusColor(f.status)
		f.health:SetBarColor(r, g, b, alpha)
	elseif healthSource == "class" then
		f.health:SetBarColor(cr, cg, cb, alpha)
	elseif healthSource == "reaction" then
		local r, g, b = K.ColorVision.ReactionColor(UnitReaction and UnitReaction(unit, "player"))
		f.health:SetBarColor(r, g, b, alpha)
	elseif f.gradient then
		GradientColor(f)
	else
		local c = health.color
		f.health:SetBarColor(c.r, c.g, c.b, alpha)
	end
	if not f.status and not f.gradient then
		f.health:SetHealthUnit(unit)
	end
	local text = Settings.current.text
	if f.status then
		f.name:SetTextColor(Tokens.Color("textDisabled"))
	elseif nameSource == "class" then
		f.name:SetTextColor(Unit.NameColor(class))
	elseif nameSource == "custom" then
		local c = text.nameColor
		f.name:SetTextColor(c.r, c.g, c.b)
	else
		f.name:SetTextColor(Tokens.Color("textEmphasis"))
	end
	Unit.NameColored(f, class)
	if f.showPortrait or f.showRoleRing then
		f.ring:SetVertexColor(cr, cg, cb, Settings.current[f.kind].portraitRingAlpha or 1)
	end
end

local function RoleLetter(f)
	if not f.showRoleRing then
		return
	end
	local role = UnitGroupRolesAssigned(f.unit)
	if IsSecret(role) or type(role) ~= "string" then
		f.roleText:SetText("")
		return
	end
	f.roleText:SetText(Style.ROLE_LETTERS[role] or "")
end

local function ClassLine(f)
	local line = f.classLine
	if Settings.current[f.kind].classLine ~= true then
		return
	end
	local className = UnitClass(f.unit)
	if IsSecret(className) or type(className) ~= "string" then
		f.classCaption = ""
		line:SetText(f.classCaption)
		Style.PlaceRowEnd(f)
		return
	end
	local level = UnitLevel(f.unit)
	if IsSecret(level) or type(level) ~= "number" or level <= 0 then
		f.classCaption = className
	else
		f.classCaption = className .. " " .. level
	end
	line:SetText(f.classCaption)
	Style.PlaceRowEnd(f)
end

function PowerColor(f)
	if not f.showPower then
		return
	end
	if f.status and Settings.current.readable.track then
		f.power:SetBarColor(K.Widgets.Rgba("black", 0))
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
	local color = not IsSecret(token) and type(token) == "string" and (Theme.Palette(token) or type(PowerBarColor) == "table" and PowerBarColor[token])
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
	f.health:SetHealth((f.missingFill and UnitHealthMissing or UnitHealth)(unit), f.fresh)
	HealthText(f)
end

local function Name(f)
	ns.Names.Set(f, UnitName(f.unit))
end

function Unit.SetPortrait(f)
	if SetPortraitTexture then
		SetPortraitTexture(f.portrait, f.unit)
	end
	local zoom = Settings.current[f.kind].portraitZoom or 0
	f.portrait:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
end

local function Portrait(f)
	if f.showPortrait then
		Unit.SetPortrait(f)
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
	local inRange, checkedRange = UnitInRange(unit)
	if f.SetAlphaFromBoolean then
		f:SetAlphaFromBoolean(inRange, 1, range.alpha)
		f:SetAlphaFromBoolean(checkedRange, f:GetAlpha(), 1)
	elseif not issecretvalue(inRange) and not issecretvalue(checkedRange) then
		f:SetAlpha(checkedRange and not inRange and range.alpha or 1)
	else
		f:SetAlpha(1)
	end
end
Unit.Range = Range

local function Target(f)
	if not Settings.current.accent.target then
		f.target:SetAlpha(0)
		return
	end
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
		elseif f.gradient then
			GradientColor(f)
		end
		Health(f)
	end,
	UNIT_MAXHEALTH = function(f)
		f.health:SetBarRange(0, UnitHealthMax(f.unit))
		Health(f)
		if f.gradient then GradientColor(f) end
	end,
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

function Unit.TextSlots(f, event, sample)
	local Widgets = K.Widgets
	local k = Settings.current[f.kind]
	for i = 1, 2 do
		local key = "extra" .. i
		local text, cfg = f[key], k[key]
		if text and text:IsShown() then
			local format = cfg.textFormat
			if not event or Widgets.ParseText(format).events[event] then Widgets.TagText(text, format, f.unit, sample) end
			Widgets.TextTint(text, cfg.colorMode, cfg.color, f.unit, sample)
		end
	end
end

local TAG_EVENTS = { UNIT_HEALTH = "Health", UNIT_MAXHEALTH = "Health", UNIT_NAME_UPDATE = "Name",
	UNIT_POWER_UPDATE = "Power", UNIT_MAXPOWER = "Power", UNIT_DISPLAYPOWER = "Power", UNIT_LEVEL = "Level",
	UNIT_ABSORB_AMOUNT_CHANGED = "Prediction", UNIT_TARGET = "Target" }

function Unit.OnEvent(f, event, ...)
	local handler = HANDLERS[event]
	if handler and f.unit then handler(f, ...) end
	local field = TAG_EVENTS[event]
	if not field then return end
	if f.unit and (f.extra1 or f.extra2) then Unit.TextSlots(f, field) end
end

local function PowerRole(f)
	if f.powerShown ~= nil and Style.PowerShown(f) ~= f.powerShown then
		Style.Apply(f)
		return true
	end
end

function Unit.Refresh(f)
	if not f.unit then
		return
	end
	PowerRole(f)
	Status(f)
	Name(f)
	f.health:SetBarRange(0, UnitHealthMax(f.unit))
	Health(f)
	Colors(f)
	PowerColor(f)
	Power(f)
	Portrait(f)
	Level(f)
	RoleLetter(f)
	ClassLine(f)
	Range(f)
	Target(f)
	if f.extra1 or f.extra2 then Unit.TextSlots(f) end
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
	if f.extra1 or f.extra2 then
		local k = Settings.current[f.kind]
		for event, field in pairs({ UNIT_TARGET = "Target", UNIT_ABSORB_AMOUNT_CHANGED = "Prediction" }) do
			if K.Widgets.ParseText(k.extra1.textFormat).events[field] or K.Widgets.ParseText(k.extra2.textFormat).events[field] then
				f:RegisterUnitEvent(event, unit)
			end
		end
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

local function PartyCount(deferGroups)
	local Headers = ns.Headers
	if not (Headers and Headers.SetPartyCount) then
		return
	end
	local count = type(GetNumGroupMembers) == "function" and GetNumGroupMembers() or nil
	if IsSecret(count) or type(count) ~= "number" then
		count = nil
	end
	Headers.SetPartyCount(count)
	if Headers.SetRaidCount then
		local card = Headers.cards and Headers.cards.raid
		local groups = card and card.groups
		if not deferGroups then
			groups = Unit.GroupSizes(count)
		end
		Headers.SetRaidCount(count, groups)
		return groups
	end
end

function Unit.GroupSizes(count)
	if not count or type(GetRaidRosterInfo) ~= "function" then
		return nil
	end
	local sizes = {}
	for i = 1, count do
		local _, _, group = GetRaidRosterInfo(i)
		if IsSecret(group) or type(group) ~= "number" then
			return nil
		end
		sizes[group] = (sizes[group] or 0) + 1
	end
	return sizes
end
Unit.PartyCount = PartyCount

function Unit.RefreshAll()
	for i = 1, #frames do
		local f = frames[i]
		if f.unit then
			Unit.Refresh(f)
		end
	end
	PartyCount()
end

local rosterPending = false

function Unit.FlushRoster()
	rosterPending = false
	if Unit.running then
		return PartyCount()
	end
end

function Unit.RosterChanged()
	for _, f in ipairs(frames) do
		if f.unit and (f.extra1 or f.extra2) then Unit.TextSlots(f, "Group") end
	end
	if not (C_Timer and C_Timer.After) then
		Unit.FlushRoster()
		return
	end
	if Unit.running then
		PartyCount(true)
	end
	if not rosterPending then
		rosterPending = true
		C_Timer.After(0, Unit.FlushRoster)
	end
end

function Unit.RolesChanged()
	for i = 1, #frames do
		local f = frames[i]
		if f.unit then
			RoleLetter(f)
			if PowerRole(f) then
				PowerColor(f)
				Power(f)
			end
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
