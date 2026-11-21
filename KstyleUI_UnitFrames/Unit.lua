-- Unit.lua: fills unit frames from unit APIs and fits readable names without inspecting secret text.
local _, ns = ...

local K = KstyleUI
local Tokens, Theme, L = K.Tokens, K.Theme, K.L
local Format, Indicators = ns.Format, ns.Indicators

local Unit = {}
ns.Unit = Unit

local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"
local UNKNOWN_LEVEL = "??"
local HOSTILE_MAX = 3
local THIN_SPACE = "\226\128\137"
local CODEPOINT = "([\1-\127\194-\244][\128-\191]*)"
local ELITE_SUFFIX = "+"
local ELITE = { elite = true, rareelite = true }
local DOT = " \194\183 "
local CLASS_WORDS = { elite = L["elite"], rareelite = L["rare elite"], rare = L["rare"] }
local CAP_WORDS = { elite = L["Elite"], rareelite = L["Rare elite"], rare = L["Rare"], worldboss = L["Boss"] }
local GLOW_POINTS = { { 0, 1 }, { 0.25, 0.9 }, { 0.5, 0.55 }, { 0.8, 0.12 }, { 1, 0 } }
Unit.GLOW_POINTS = GLOW_POINTS
local HEALTH_STOPS = { { 0, "hostile" }, { 0.5, "neutral" }, { 1, "friendly" } }

local issecretvalue = issecretvalue or function()
	return false
end

local function IsSecret(value)
	return issecretvalue(value) == true
end

local function HasClass(file)
	return IsSecret(file) or type(file) == "string"
end

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

local function SetColor(bar, r, g, b, a)
	if a < 1 then
		bar:SetBarColor(r, g, b, a)
	else
		bar:SetBarColor(r, g, b)
	end
end
Unit.SetColor = SetColor

function Unit.ShareColor(share)
	local low, high = HEALTH_STOPS[1], HEALTH_STOPS[2]
	if share > high[1] then low, high = high, HEALTH_STOPS[3] end
	local t = math.max(0, math.min(1, (share - low[1]) / (high[1] - low[1])))
	local r1, g1, b1 = Tokens.Color(low[2])
	local r2, g2, b2 = Tokens.Color(high[2])
	return r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t
end

local shareCurves, sharesTried
local function ShareCurves()
	if sharesTried then return shareCurves end
	sharesTried = true
	local util, kinds = C_CurveUtil, Enum and Enum.LuaCurveType
	if not (util and type(util.CreateCurve) == "function" and UnitHealthPercent) then
		Log("health colour by health left: no curve API; the bar keeps the class colour")
		return nil
	end
	shareCurves = {}
	for channel = 1, 3 do
		local curve = util.CreateCurve()
		if kinds and kinds.Linear and curve.SetType then curve:SetType(kinds.Linear) end
		for _, stop in ipairs(HEALTH_STOPS) do curve:AddPoint(stop[1], (select(channel, Tokens.Color(stop[2])))) end
		shareCurves[channel] = curve
	end
	return shareCurves
end

local function ShareColor(unit)
	local curves = ShareCurves()
	return UnitHealthPercent(unit, true, curves[1]), UnitHealthPercent(unit, true, curves[2]), UnitHealthPercent(unit, true, curves[3])
end

local function ClassFile(unit)
	local _, file = UnitClass(unit)
	return file
end

function Unit.ReactionColor(reaction)
	if not IsSecret(reaction) and type(reaction) == "number" and reaction <= HOSTILE_MAX then
		return K.ColorVision.Color(2, Tokens.Color("healthHostile"))
	end
	return K.ColorVision.ReactionColor(reaction)
end

local function ReactionColor(unit)
	return Unit.ReactionColor(UnitReaction(unit, "player"))
end

local function HudColor(unit)
	local reaction = UnitReaction and UnitReaction(unit, "player")
	if not IsSecret(reaction) and type(reaction) == "number" and reaction <= HOSTILE_MAX then
		return K.ColorVision.Color(2, ns.Lumen.Color("hudTargetHealth"))
	end
	if unit == "player" then
		return ns.Lumen.Color("hudPlayerHealth")
	end
	return K.ColorVision.ReactionColor(reaction)
end

local function UnitColor(unit, source)
	if source == "hud" then
		return HudColor(unit)
	end
	if source == "class" and UnitIsPlayer(unit) then
		local file = ClassFile(unit)
		if HasClass(file) then
			return Theme.ClassColorForWidget(file)
		end
	end
	return ReactionColor(unit)
end

function Unit.HealthColor(view, unit)
	local s = view.s
	local r, g, b
	local grey = UnitIsConnected and not UnitIsConnected(unit) or UnitIsTapDenied and UnitIsTapDenied(unit)
	view.health:SetHealthUnit(nil)
	view.healthByShare = false
	if grey then
		r, g, b = Tokens.Color("textDisabled")
	elseif s.healthColor == "custom" then
		local c = s.healthCustom
		r, g, b = c.r, c.g, c.b
	elseif s.healthColor == "health" and ShareCurves() then
		view.healthByShare = true
	else
		r, g, b = UnitColor(unit, (s.healthColor == "health" or view.form == "slab" and s.healthColor == "hud" and unit == "player") and "class" or s.healthColor)
	end
	if not view.healthByShare then SetColor(view.health, r, g, b, s.healthAlpha) end
	local reaction = UnitReaction and UnitReaction(unit, "player")
	local hostile = not IsSecret(reaction) and type(reaction) == "number" and reaction <= HOSTILE_MAX
	if not (grey or hostile or view.healthByShare or s.healthAlpha < 1) then
		view.health:SetHealthUnit(unit)
	end
	ns.Style.HealthTint(view, r, g, b)
	ns.Slab.Colors(view, unit)
	if s.levelDifficulty then Unit.Level(view, unit) end
end

local function ManaType()
	local types = Enum and Enum.PowerType
	return types and types.Mana or 0
end

local function ShownPower(view, unit)
	if not view.s.powerMana then return nil end
	local mana = ManaType()
	local max = UnitPowerMax(unit, mana)
	if IsSecret(max) or type(max) ~= "number" or max <= 0 then return nil end
	return mana
end

local function PowerTypeColor(unit, column, token)
	if unit and not token then
		local _, own = UnitPowerType(unit)
		token = own
	end
	token = token or "MANA"
	local colors = PowerBarColor
	if column and not IsSecret(token) and token == "MANA" and not Theme.Palette(token) then
		return Tokens.Color("hudMana")
	end
	local c = type(token) == "string" and not IsSecret(token) and (Theme.Palette(token) or colors and colors[token])
	if type(c) == "table" and type(c.r) == "number" then
		return Theme.Brighten(c.r, c.g, c.b)
	end
	return Tokens.Color("rare")
end

Unit.PowerTypeColor = PowerTypeColor

function Unit.PowerColor(view, unit)
	local s = view.s
	local source = s.powerColor
	if source == "custom" then
		local c = s.powerCustom
		ns.Style.PowerTint(view, c.r, c.g, c.b)
	elseif source == "power" then
		ns.Style.PowerTint(view, PowerTypeColor(unit, s.form == "column", ShownPower(view, unit) and "MANA"))
	else
		ns.Style.PowerTint(view, UnitColor(unit, source))
	end
end

local function SetValue(bar, value, instant)
	if instant then
		bar:SetValue(value)
	else
		bar:SetBarValue(value)
	end
end

local function Hide(region)
	if region and region:IsShown() then region:Hide() end
end

function Unit.Prediction(view, unit)
	local s, eaten = view.s, view.healAbsorb
	local wanted = s.healPrediction and s.healAbsorbs
	if view.healAbsorbShown and not wanted then
		eaten:Hide()
		view.healAbsorbShown = false
	end
	local glow = s.absorbGlow and (view.shieldGlow or ns.Style.ShieldGlow(view))
	local strip = s.absorbBar ~= "" and view.absorbBar
	if s.absorbBar ~= "" and not strip then
		strip, view.predictionRange = ns.Style.AbsorbBar(view), false
	end
	if not glow then Hide(view.shieldGlow) end
	if not strip then Hide(view.absorbBar) end
	if not s.healPrediction then
		view.incoming:Hide()
		view.absorb:Hide()
		if not (glow or strip) then return end
	end
	if wanted and not eaten then
		eaten, view.predictionRange = ns.Style.HealAbsorb(view), false
	end
	if not view.predictionRange then
		local max = view.rangeMax or UnitHealthMax(unit)
		view.incoming:SetBarRange(0, max)
		view.absorb:SetBarRange(0, max)
		if eaten then eaten:SetBarRange(0, max) end
		if strip then strip:SetBarRange(0, max) end
		view.predictionRange = true
	end
	local calc = view.calculator
	if calc == nil and CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
		calc = CreateUnitHealPredictionCalculator()
		local modes = Enum and Enum.UnitHealAbsorbClampMode
		if modes and modes.CurrentHealth and calc.SetHealAbsorbClampMode then calc:SetHealAbsorbClampMode(modes.CurrentHealth) end
		view.calculator = calc
		LogOnce("prediction", "heal prediction: CreateUnitHealPredictionCalculator")
	end
	if calc then
		UnitGetDetailedHealPrediction(unit, "player", calc)
		local absorbs, over = calc:GetDamageAbsorbs()
		local total = absorbs
		if (s.absorbPlacement ~= "" or strip) and UnitGetTotalAbsorbs then total = UnitGetTotalAbsorbs(unit) end
		if s.healPrediction then
			view.incoming:SetBarValue((calc:GetIncomingHeals()))
			view.absorb:SetBarValue(s.absorbPlacement ~= "" and total or absorbs)
			view.absorb:SetShown(s.absorbs ~= false)
		end
		if glow then
			if IsSecret(over) then
				glow:SetAlphaFromBoolean(over, 1, 0)
				glow.lit = nil
			elseif glow.lit ~= (over == true) then
				glow.lit = over == true
				glow:SetAlpha(glow.lit and 1 or 0)
			end
			if not glow:IsShown() then glow:Show() end
		end
		if strip then
			strip:SetBarValue(total)
			if not strip:IsShown() then strip:Show() end
		end
		if wanted and calc.GetHealAbsorbs then
			eaten:SetBarValue((calc:GetHealAbsorbs()))
			if not view.healAbsorbShown then
				eaten:Show()
				view.healAbsorbShown = true
			end
		end
	elseif not s.healPrediction then
		return
	elseif UnitGetIncomingHeals then
		LogOnce("prediction", "heal prediction: UnitGetIncomingHeals, no absorbs")
		local heals = UnitGetIncomingHeals(unit)
		if issecretvalue(heals) then
			view.incoming:SetBarValue(heals)
		else
			view.incoming:SetBarValue(heals or 0)
		end
		view.absorb:Hide()
	else
		LogOnce("prediction", "heal prediction: no API; incoming heals are not shown")
		view.incoming:Hide()
		view.absorb:Hide()
		return
	end
	if s.healPrediction then view.incoming:Show() end
end

local glowCurve, glowTried

local function GlowCurve()
	if glowTried then
		return glowCurve
	end
	glowTried = true
	local util = C_CurveUtil
	if not (util and type(util.CreateCurve) == "function" and UnitHealthPercent) then
		Log("low-health ring: no curve API; the ring does not glow")
		return nil
	end
	local ok, curve = pcall(util.CreateCurve)
	if not ok or not curve then
		Log("low-health ring: CreateCurve failed; the ring does not glow")
		return nil
	end
	local kinds = Enum and Enum.LuaCurveType
	if kinds and kinds.Linear and curve.SetType then
		curve:SetType(kinds.Linear)
	end
	for _, point in ipairs(GLOW_POINTS) do
		curve:AddPoint(point[1], point[2])
	end
	glowCurve = curve
	Log("low-health ring: its alpha is a C_CurveUtil curve over UnitHealthPercent")
	return curve
end

function Unit.ResetGlow()
	glowCurve, glowTried = nil, false
end

function Unit.Glow(view, unit)
	local glow = view.ringGlow
	if view.form ~= "vitals" or not (view.geometry and view.geometry.portrait) then
		glow:Hide()
		return
	end
	local curve = GlowCurve()
	if not curve then
		glow:Hide()
		return
	end
	glow:SetVertexColor(Tokens.Color("healthHostile"))
	glow:SetAlpha(UnitHealthPercent(unit, true, curve))
	glow:Show()
end

local function LumenHealth(view, unit, form, format)
	if form == "bar" then
		Format.Health(view.healthText, unit, format == "none" and "none" or "percent", view.s.healthDecimal)
		Format.HealthDetail(view.healthSub, unit, format == "none" and "none" or "both")
	elseif form == "column" and view.geometry.mirror then
		Format.Health(view.healthText, unit, Format.Main(format), view.s.healthDecimal)
	elseif form == "vitals" or form == "column" then
		local main, split = format, false
		if format == "both" or format == "currentMax" then
			main, split = "current", true
		end
		Format.Health(view.healthText, unit, main, view.s.healthDecimal)
		if split then
			Format.Max(view.healthSub, unit)
		else
			view.healthSub:SetText("")
		end
	elseif form == "card" then
		Format.Health(view.healthText, unit, Format.Main(format), view.s.healthDecimal)
	elseif form == "slab" then
		local percent = view.kind == "target" and view.s.percentLead and format == "both"
		Format.Health(view.healthText, unit, percent and "percent" or format == "both" and "currentMax" or format, view.s.healthDecimal)
		local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
		local gone = not IsSecret(dead) and dead == true
		if percent then
			Format.HealthDetail(view.healthSub, unit, gone and "none" or "both")
		else
			Format.Health(view.healthSub, unit, format == "both" and not gone and "percent" or "none", view.s.healthDecimal)
		end
	elseif form == "row" then
		Format.Health(view.healthText, unit, format, view.s.healthDecimal)
	end
end

local function LostShare(view, unit)
	if not (view.s and view.s.maxHealthLoss) or type(GetUnitTotalModifiedMaxHealthPercent) ~= "function" then return nil end
	local share = GetUnitTotalModifiedMaxHealthPercent(unit)
	if IsSecret(share) or type(share) ~= "number" or share ~= share then return 0 end
	return math.max(0, math.min(share, 0.9))
end

function Unit.HealthRange(view, unit)
	local max, lost = UnitHealthMax(unit), LostShare(view, unit)
	view.rangeMax = nil
	if lost and lost > 0 and not IsSecret(max) and type(max) == "number" and max > 0 then
		max = max / (1 - lost)
		view.rangeMax = max
	else
		lost = lost and 0
	end
	view.health:SetBarRange(0, max)
	if lost and lost > 0 then
		local bar = view.lossBar or ns.Style.LossBar(view)
		bar:SetValue(lost)
		if not bar:IsShown() then bar:Show() end
	else
		Hide(view.lossBar)
	end
	view.healthRangeUnit, view.predictionRange = unit, false
end

function Unit.Health(view, unit, instant)
	local bar = view.health
	if instant or view.healthRangeUnit ~= unit then
		Unit.HealthRange(view, unit)
	end
	bar:SetHealth(UnitHealth(unit), instant)
	if view.healthByShare then
		local r, g, b = ShareColor(unit)
		SetColor(bar, r, g, b, view.s.healthAlpha)
	end
	local format = view.s.healthText
	local form = view.geometry and view.geometry.form or "plate"
	if view.s.fonts.health.textFormat ~= "" and format ~= "none" then
		view.healthSub:SetText("")
	elseif form ~= "plate" then
		LumenHealth(view, unit, form, format)
	elseif view.geometry and view.geometry.healthSub then
		Format.Health(view.healthText, unit, Format.Main(format), view.s.healthDecimal)
		Format.HealthDetail(view.healthSub, unit, format)
	else
		Format.Health(view.healthText, unit, format, view.s.healthDecimal)
	end
	if form ~= "plate" then
		Unit.Glow(view, unit)
		ns.Slab.Health(view, unit)
	end
	Unit.Prediction(view, unit)
end

function Unit.Power(view, unit, instant)
	if not view.s.power then
		return
	end
	local bar = view.power
	if view.geometry and not view.geometry.power then
		bar:Hide()
		view.powerText:SetText("")
		return
	end
	local shown = ShownPower(view, unit)
	local max = UnitPowerMax(unit, shown)
	local empty = false
	if issecretvalue ~= nil and not issecretvalue(max) then
		empty = type(max) == "number" and max <= 0
	end
	bar:SetShown(not empty)
	if empty then
		view.powerText:SetText("")
		return
	end
	bar:SetBarRange(0, max)
	SetValue(bar, UnitPower(unit, shown), instant)
	Format.Power(view.powerText, unit, view.s.powerText, shown)
end

local function Costs(spellID)
	if spellID == nil or IsSecret(spellID) or not (C_Spell and C_Spell.GetSpellPowerCost) then return nil end
	local costs = C_Spell.GetSpellPowerCost(spellID)
	return type(costs) == "table" and costs or nil
end

local function CostOf(costs, powerType)
	for _, info in ipairs(costs or {}) do
		if type(info) == "table" and not IsSecret(info.type) and info.type == powerType then return info.cost end
	end
	return nil
end

local function BarPower(view)
	local shown = ShownPower(view, "player") or UnitPowerType("player")
	return not IsSecret(shown) and shown or nil
end

function Unit.Cost(view, spellID)
	local cost = view.s.powerCost and view.s.power and CostOf(Costs(spellID), BarPower(view))
	if cost == nil or not IsSecret(cost) and (type(cost) ~= "number" or cost <= 0) then
		Hide(view.costBar)
		return
	end
	local bar = view.costBar or ns.Style.CostBar(view)
	bar:SetBarRange(0, UnitPowerMax("player", ShownPower(view, "player")))
	bar:SetValue(cost)
	if not bar:IsShown() then bar:Show() end
end

function Unit.Spark(view, spellID)
	if not (view.s.manaSpark and view.s.power) or BarPower(view) ~= ManaType() then return end
	local cost = CostOf(Costs(spellID), ManaType())
	if IsSecret(cost) or type(cost) ~= "number" or cost <= 0 then return end
	local spark = view.manaSpark or ns.Style.Spark(view)
	spark.group:Stop()
	spark:Show()
	spark.group:Play()
end

function Unit.Name(view, unit)
	if view.s.fonts.name.textFormat ~= "" then
		view.plainName = nil
		local g = view.geometry
		if g and g.nameAuto and g.nameRoom then
			view.name:SetWidth(K.Widgets.Snap(view.name, g.nameRoom))
			view.nameBound = true
		end
		return
	end
	local name = UnitName(unit)
	if IsSecret(name) then
		Unit.SetName(view, name)
		return
	end
	if type(name) ~= "string" then
		name = ""
	end
	Unit.SetName(view, name)
end

local ownFonts
local function OwnFont(path)
	if not ownFonts then
		ownFonts = {}
		for _, face in ipairs(Tokens.MediaList("font")) do
			ownFonts[face.path] = true
		end
	end
	return ownFonts[path] == true
end

function Unit.Tracked(text, fontPath)
	text = text:upper()
	if OwnFont(fontPath) and K.Locale.TrackMode(fontPath) == "space" then
		text = text:gsub(CODEPOINT, "%1" .. THIN_SPACE):sub(1, -#THIN_SPACE - 1)
	end
	return text
end

local function Number(value)
	return not IsSecret(value) and type(value) == "number"
end

local function SetFont(text, path, size, flags)
	if not K.Widgets.ApplyFont(text, path, size, flags) then
		K.Widgets.ApplyFont(text, (Tokens.Font("body")), size, flags)
	end
end

local function BoundName(view, bound)
	local g = view.geometry
	view.nameBound = bound
	if g and g.nameAuto and g.nameRoom then
		local width = K.Widgets.Snap(view.name, g.nameRoom)
		if g.form == "slab" then
			width = math.max(K.Widgets.Border(view.name), width)
			view.name:SetShown(g.nameRoom > 0)
		end
		view.name:SetWidth(bound and width or 0)
	end
end

local function SetName(view, name)
	local text = view.name
	local path, full, flags = ns.Settings.Font(view.kind, "name")
	ns.Slab.Caption(view)
	if view.form == "slab" and text.ClearText then text:ClearText() end
	K.Widgets.Fitted(text, false)
	SetFont(text, path, full, flags)
	if IsSecret(name) then
		view.plainName = nil
		text:SetText(name)
		BoundName(view, true)
		return
	end
	view.plainName = name
	text:SetText(view.s.nameCaps and Unit.Tracked(name, path) or name)
	local bodyPath, bodySize = Tokens.Font("body")
	if not ns.Settings.ThemeFont(view.kind, "name") or Theme.RoleFont(ns.Settings.Role(view.kind, "name")) ~= "" then
		bodyPath = path
	end
	if not Number(full) then
		BoundName(view, true)
		return
	end
	local width, room = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth(), view.geometry and view.geometry.nameRoom or text:GetWidth()
	local nameFloor
	if view.form == "slab" and Number(width) and Number(room) and room > 0 then
		local pixel = K.Widgets.Border(text)
		local _, size = text:GetFont()
		nameFloor = math.min(size, math.ceil(9 / (K.Scale.AppliedUserScale() * K.Scale.Pixel(1)) - 1e-6) * pixel)
		while width > room and Number(size) and size > nameFloor do
			size = math.max(nameFloor, size - full / 10)
			K.Widgets.Fitted(text)
			SetFont(text, path, size, flags)
			width = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth()
			if not Number(width) then break end
		end
	end
	if Number(width) and Number(room) and room > 0 and width > room and not (view.form == "slab" and ns.Settings.Module().stableSlabNames ~= false) then
		local limit = math.max(nameFloor or 0, math.min(bodySize, full))
		if view.form == "slab" then
			local _, size = text:GetFont()
			limit = math.min(limit, size)
			K.Widgets.Fitted(text)
		end
		SetFont(text, bodyPath, limit, flags)
		text:SetText(name)
		width = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth()
		local _, actual = text:GetFont()
		if view.form ~= "slab" and Number(width) and width > room and Number(actual) and actual > limit then
			K.Widgets.Fitted(text)
			local pixel = K.Widgets.FontSize(text, 0)
			SetFont(text, bodyPath, math.max(pixel, actual - pixel), flags)
			width = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth()
		end
	end
	BoundName(view, not (Number(width) and Number(room) and width <= room))
end

function Unit.Refit(view)
	if view.plainName then
		SetName(view, view.plainName)
		ns.Style.Baseline(view)
	end
end

function Unit.SetName(view, name)
	local fit = view.marker and ns.Indicators.Fit
	if fit then
		fit(view)
	end
	SetName(view, name)
	if fit then
		fit(view)
	end
	ns.Style.Baseline(view)
end

local function LevelColor(unit, fallback, level, friendly)
	if unit and (friendly or UnitCanAttack and UnitCanAttack("player", unit)) then
		level = UnitLevel(unit)
	end
	if GetCreatureDifficultyColor and not IsSecret(level) and type(level) == "number" and level > 0 then
		local c = GetCreatureDifficultyColor(level)
		if type(c) == "table" and type(c.r) == "number" then
			return Theme.Brighten(c.r, c.g, c.b)
		end
	end
	if fallback ~= false then return Tokens.Color(fallback or "textEmphasis") end
end
Unit.LevelColor = LevelColor

local function Plain(value)
	return not IsSecret(value)
end

local function StanceName()
	if not (GetShapeshiftForm and GetShapeshiftFormInfo) then
		return nil
	end
	local index = GetShapeshiftForm()
	if not Plain(index) or type(index) ~= "number" or index <= 0 then
		return nil
	end
	local _, _, _, spellID = GetShapeshiftFormInfo(index)
	local spells = C_Spell
	if not Plain(spellID) or type(spellID) ~= "number" or not (spells and spells.GetSpellName) then
		return nil
	end
	return spells.GetSpellName(spellID)
end

local function SpecName()
	local info = C_SpecializationInfo
	if not (info and info.GetSpecialization and info.GetSpecializationInfo) then
		return nil
	end
	local index = info.GetSpecialization()
	if not Plain(index) or type(index) ~= "number" then
		return nil
	end
	local _, name = info.GetSpecializationInfo(index)
	return name
end

local function Shows(value)
	return IsSecret(value) or (type(value) == "string" and value ~= "")
end

local function LevelText(text, level, classification, creature, short, unit, hostile, friendly)
	local fmt, args = {}, {}
	local plainClass = Plain(classification) and classification
	if short and plainClass and CAP_WORDS[plainClass] then
		text:SetText(CAP_WORDS[plainClass])
		return
	end
	if plainClass == "worldboss" or (Plain(level) and (type(level) ~= "number" or level <= 0)) then
		fmt[1] = L["Boss"]
	else
		fmt[1] = L["Level %s"]
		local r, g, b = LevelColor(unit, false, hostile and level, friendly)
		args[1] = r and string.format("|cff%02x%02x%02x%d|r", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), level) or level
	end
	if not short and plainClass and CLASS_WORDS[plainClass] and fmt[1] ~= L["Boss"] then
		fmt[#fmt + 1] = " %s"
		args[#args + 1] = CLASS_WORDS[plainClass]
	end
	if not short and Shows(creature) then
		fmt[#fmt + 1] = DOT .. "%s"
		args[#args + 1] = creature
	end
	text:SetFormattedText(table.concat(fmt), unpack(args, 1, #args))
end

Unit.LevelText = LevelText

local function LevelLine(text, unit, short, view)
	local creature
	if not short and UnitCreatureType then
		creature = UnitCreatureType(unit)
	end
	LevelText(text, UnitLevel(unit), UnitClassification and UnitClassification(unit), creature, short, view.s.levelDifficulty and unit, nil, view.s.levelFriendly)
end

function Unit.Caption(view, unit)
	local form, text = view.form, view.caption
	if form == "vitals" then
		local name
		if unit == "player" then
			name = StanceName()
			if not Shows(name) then
				name = SpecName()
			end
		end
		if Shows(name) then
			text:SetText(name)
		else
			text:SetText("")
		end
	elseif form == "column" or form == "bar" then
		local label
		if form == "bar" or view.geometry and view.geometry.mirror then
			label = UnitCreatureType and UnitCreatureType(unit)
		else
			label = (UnitClass(unit))
		end
		if Shows(label) then
			text:SetText(label)
		else
			text:SetText("")
		end
	elseif form == "slab" then
		local label
		if view.geometry and view.geometry.caption then
			local player = UnitIsPlayer(unit)
			if not IsSecret(player) and player then
				label = (UnitClass(unit))
			else
				label = UnitCreatureType and UnitCreatureType(unit)
			end
		end
		if not IsSecret(label) and type(label) ~= "string" then label = "" end
		ns.Slab.SetCaption(view, label)
		Unit.Refit(view)
	elseif form == "sigil" then
		LevelLine(text, unit, false, view)
	elseif form == "card" then
		LevelLine(text, unit, true, view)
		view.capLabel:SetText(ns.Settings.CAP_LABELS[view.kind] or "")
	end
end

local function Rank(view, unit)
	local ring = view.portraitOrnament
	if not ring then
		return
	end
	local classification = type(UnitClassification) == "function" and UnitClassification(unit)
	local known = not IsSecret(classification)
	local player = unit == "player"
	local boss = known and (classification == "worldboss" or view.kind == "boss")
	local elite = known and (classification == "elite" or classification == "rareelite" or classification == "rare" or classification == "worldboss")
	if ring.player == player and ring.boss == boss and ring.elite == elite then
		view.health.ornament:Restyle()
	else
		ring.player, ring.boss, ring.elite = player, boss, elite
		ring:Restyle()
		ns.Style.RestyleBlocks()
	end
	view.chrome:RestyleOrnament()
end

function Unit.Level(view, unit)
	local text = view.levelText
	if view.form == "slab" then
		ns.Slab.Level(view, unit)
		Unit.Caption(view, unit)
		return
	end
	Rank(view, unit)
	if view.form and view.form ~= "plate" then
		Unit.Caption(view, unit)
		if (view.form == "vitals" or view.form == "column" or view.form == "bar") and view.s.level then
			text:SetText(UnitLevel(unit))
			text:SetTextColor(LevelColor(view.s.levelDifficulty and unit, nil, nil, view.s.levelFriendly))
		end
		return
	end
	if not view.s.level then
		return
	end
	local level = UnitLevel(unit)
	local classification = UnitClassification and UnitClassification(unit)
	if IsSecret(level) or IsSecret(classification) then
		text:SetText(level)
		return
	end
	if classification == "worldboss" or type(level) ~= "number" or level <= 0 then
		text:SetText(UNKNOWN_LEVEL)
	elseif ELITE[classification] then
		text:SetText(level .. ELITE_SUFFIX)
	else
		text:SetText(level)
	end
	text:SetTextColor(LevelColor(unit, nil, nil, view.s.levelDifficulty and view.s.levelFriendly))
end

function Unit.Crop(texture, s, l, r, t, b)
	local zoom = s.portraitZoom
	if zoom <= 0 and not s.portraitMirror then
		return
	end
	local dx, dy = (r - l) * zoom / 2, (b - t) * zoom / 2
	l, r, t, b = l + dx, r - dx, t + dy, b - dy
	if s.portraitMirror then
		l, r = r, l
	end
	texture:SetTexCoord(l, r, t, b)
end

function Unit.ClassArt(texture, file, s)
	if GetClassAtlas then
		texture:SetTexCoord(0, 1, 0, 1)
		local atlas = GetClassAtlas(file)
		texture:SetAtlas(atlas)
		local info = (s.portraitMirror or s.portraitZoom > 0) and not IsSecret(atlas) and type(atlas) == "string" and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
		if info then
			Unit.Crop(texture, s, info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
		end
		return true
	end
	local coords = not IsSecret(file) and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[file]
	if coords then
		texture:SetTexture(CLASS_CIRCLES)
		texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		Unit.Crop(texture, s, coords[1], coords[2], coords[3], coords[4])
		return true
	end
	return false
end

local function ClassIcon(texture, unit, s)
	local file = ClassFile(unit)
	return HasClass(file) and Unit.ClassArt(texture, file, s)
end

function Unit.Portrait(view, unit)
	if view.form == "slab" then
		ns.Slab.Portrait(view, unit)
		return
	end
	if not view.s.portrait then
		return
	end
	local texture = view.portrait
	if view.s.portraitStyle == "class" and ClassIcon(texture, unit, view.s) then
		return
	end
	texture:SetTexCoord(0, 1, 0, 1)
	if SetPortraitTexture then
		SetPortraitTexture(texture, unit, view.s.portraitShape ~= "round")
		Unit.Crop(texture, view.s, 0, 1, 0, 1)
	else
		LogOnce("portrait", "SetPortraitTexture is missing; portraits show the class icon")
		ClassIcon(texture, unit, view.s)
	end
end

local TEXT_ELEMENTS = { "name", "health" }
function Unit.TextTags(view, unit, event, sample)
	if not (view.s.textOptions or view.extra1 or view.extra2) then return end
	local Widgets = K.Widgets
	event = event == "MaxHealth" and "Health" or event == "PowerType" and "Power" or event
	for i = 1, 2 do
		local key = "extra" .. i
		local text, cfg = view[key], view.s[key]
		if text and text:IsShown() then
			local format = cfg.textFormat
			if not event or Widgets.ParseText(format).events[event] then Widgets.TagText(text, format, unit, sample) end
			Widgets.TextTint(text, cfg.colorMode, cfg.color, unit, sample)
		end
	end
	if not view.s.textOptions then return end
	for _, element in ipairs(TEXT_ELEMENTS) do
		local style = view.s.fonts[element]
		local text = element == "name" and view.name or view.healthText
		local format = style.textFormat
		if format ~= "" and (element ~= "health" or view.s.healthText ~= "none")
			and (not event or K.Widgets.ParseText(format).events[event]) then
			K.Widgets.TagText(text, format, unit, sample)
			if element == "name" and view.chip then K.Widgets.TagText(view.chip.name, format, unit, sample) end
			if element == "health" then view.healthSub:SetText("") end
		end
		if style.colorMode ~= "" then
			K.Widgets.TextTint(text, style.colorMode, style.color, unit, sample)
			if element == "name" and view.chip then K.Widgets.TextTint(view.chip.name, style.colorMode, style.color, unit, sample) end
			if element == "health" then K.Widgets.TextTint(view.healthSub, style.colorMode, style.color, unit, sample) end
		end
	end
end

function Unit.All(view, unit, instant)
	if not (view.s and UnitExists(unit)) then
		return
	end
	Unit.HealthColor(view, unit)
	Unit.Health(view, unit, instant)
	Unit.PowerColor(view, unit)
	Unit.Power(view, unit, instant)
	Unit.Name(view, unit)
	Unit.Level(view, unit)
	Unit.Portrait(view, unit)
	Indicators.Update(view, unit)
	Unit.TextTags(view, unit)
end
