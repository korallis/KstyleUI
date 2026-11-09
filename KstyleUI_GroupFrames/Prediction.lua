-- Prediction.lua: incoming heals and absorbs after the health fill and heal absorbs back from its end, from the heal prediction calculator, values passed straight to the bars.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local Settings, Style, Unit, Button = ns.Settings, ns.Style, ns.Unit, ns.Button

local Prediction = {}
ns.Prediction = Prediction

local HEALER = "player"
local LEVEL_ABOVE_HEALTH = 1
local SHIELD_LINES = 2
local SHIELD_ALPHA = 1

local function Build(f)
	f.predict = CreateFrame("Frame", nil, f)
	f.predict:SetAllPoints(f.health)
	f.predict:SetClipsChildren(true)
	f.predict:SetFrameLevel(f.health:GetFrameLevel() + LEVEL_ABOVE_HEALTH)
	f.heals = Widgets.StatusBar(f.predict, { background = false, smooth = true })
	f.absorbs = Widgets.StatusBar(f.predict, { background = false, smooth = true })
	f.shield = Widgets.StatusBar(f.predict, { background = false, smooth = true })
	f.healAbsorbs = Widgets.StatusBar(f.predict, { background = false, smooth = true, reverse = true })
end
Button.built[#Button.built + 1] = Build

local function Paint(bar, color)
	bar:SetBarColor(color.r, color.g, color.b, color.a or 1)
end

local function Configure(calc)
	local enum = Enum
	if enum and enum.UnitIncomingHealClampMode and calc.SetIncomingHealClampMode then
		calc:SetIncomingHealClampMode(enum.UnitIncomingHealClampMode.MissingHealth)
	end
	local modes = enum and enum.UnitDamageAbsorbClampMode
	if modes and calc.SetDamageAbsorbClampMode then
		local withHeals = Settings.current.prediction.heals
		calc:SetDamageAbsorbClampMode(withHeals and modes.MissingHealth or modes.MissingHealthWithoutIncomingHeals or modes.MissingHealth)
	end
	local healAbsorb = enum and enum.UnitHealAbsorbClampMode
	if healAbsorb and calc.SetHealAbsorbClampMode then
		calc:SetHealAbsorbClampMode(healAbsorb.CurrentHealth)
	end
end

local function Calculator(f)
	local calc = f.calc
	if calc then
		return calc
	end
	calc = CreateUnitHealPredictionCalculator()
	Configure(calc)
	f.calc = calc
	return calc
end

local function Layout(f, parts)
	local cfg = Settings.current
	local rect = parts.health
	local vertical = cfg.health.orientation == "VERTICAL"
	local fill = f.health:GetStatusBarTexture()
	for _, bar in ipairs({ f.heals, f.absorbs }) do
		bar:SetOrientation(cfg.health.orientation)
		bar:SetBarTexture(cfg.health.texture)
		bar.opts.width, bar.opts.height = rect.width, rect.height
		bar:Restyle()
		bar:ClearAllPoints()
	end
	local healFill = f.heals:GetStatusBarTexture()
	if vertical then
		f.heals:SetPoint("BOTTOMLEFT", fill, "TOPLEFT", 0, 0)
		f.absorbs:SetPoint("BOTTOMLEFT", healFill, "TOPLEFT", 0, 0)
	else
		f.heals:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
		f.absorbs:SetPoint("TOPLEFT", healFill, "TOPRIGHT", 0, 0)
	end
	Paint(f.heals, cfg.prediction.healColor)
	Paint(f.absorbs, cfg.prediction.absorbColor)
	local eaten = f.healAbsorbs
	eaten:SetOrientation(cfg.health.orientation)
	eaten:SetReverseFill(true)
	eaten:SetBarTexture(cfg.health.texture)
	eaten.opts.width, eaten.opts.height = rect.width, rect.height
	eaten:Restyle()
	eaten:ClearAllPoints()
	if vertical then
		eaten:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
	else
		eaten:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
	end
	Paint(eaten, cfg.prediction.healAbsorbColor)
	eaten:SetShown(cfg.prediction.healAbsorbs)
	if not cfg.prediction.healAbsorbs then
		eaten:SetValue(0)
	end
	local shield = f.shield
	local line = Widgets.Border(f) * SHIELD_LINES
	shield:SetOrientation("HORIZONTAL")
	shield:SetBarTexture(cfg.health.texture)
	shield.opts.width, shield.opts.height = rect.width, line
	shield:Restyle()
	shield:ClearAllPoints()
	shield:SetPoint("BOTTOMLEFT", f.health, "BOTTOMLEFT", 0, 0)
	local c = cfg.prediction.absorbColor
	shield:SetBarColor(c.r, c.g, c.b, SHIELD_ALPHA)
	shield:SetShown(cfg.prediction.shield)
	f.heals:SetShown(cfg.prediction.heals)
	f.absorbs:SetShown(cfg.prediction.absorbs)
	if not cfg.prediction.heals then
		f.heals:SetValue(0)
	end
	if f.calc then
		Configure(f.calc)
	end
end
Style.appliers[#Style.appliers + 1] = Layout

local function TotalHealAbsorbs(unit)
	if type(UnitGetTotalHealAbsorbs) == "function" then
		return UnitGetTotalHealAbsorbs(unit)
	end
	Style.LogOnce("noHealAbsorbs", "UnitGetTotalHealAbsorbs is missing; heal absorbs stay hidden")
	return 0
end

local function Values(f)
	local unit = f.unit
	if type(CreateUnitHealPredictionCalculator) == "function" and type(UnitGetDetailedHealPrediction) == "function" then
		local calc = Calculator(f)
		UnitGetDetailedHealPrediction(unit, HEALER, calc)
		local heals = calc:GetIncomingHeals()
		local absorbs = calc:GetDamageAbsorbs()
		local eaten
		if type(calc.GetHealAbsorbs) == "function" then
			eaten = calc:GetHealAbsorbs()
		else
			Style.LogOnce("calcHealAbsorbs", "the heal prediction calculator has no GetHealAbsorbs; heal absorbs read UnitGetTotalHealAbsorbs")
			eaten = TotalHealAbsorbs(unit)
		end
		return heals, absorbs, eaten
	end
	Style.LogOnce("noCalculator", "CreateUnitHealPredictionCalculator is missing; heals and absorbs read UnitGetIncomingHeals, UnitGetTotalAbsorbs and UnitGetTotalHealAbsorbs")
	local heals, absorbs = 0, 0
	if type(UnitGetIncomingHeals) == "function" then
		heals = UnitGetIncomingHeals(unit)
	end
	if type(UnitGetTotalAbsorbs) == "function" then
		absorbs = UnitGetTotalAbsorbs(unit)
	end
	return heals, absorbs, TotalHealAbsorbs(unit)
end

local function Shield(f)
	if not Settings.current.prediction.shield then
		return
	end
	local unit = f.unit
	f.shield:SetBarRange(0, UnitHealthMax(unit))
	if type(UnitGetTotalAbsorbs) == "function" then
		f.shield:SetBarValue(UnitGetTotalAbsorbs(unit))
	else
		Style.LogOnce("noTotalAbsorbs", "UnitGetTotalAbsorbs is missing; the shield line stays empty")
		f.shield:SetBarValue(0)
	end
end

local function Update(f)
	local cfg = Settings.current.prediction
	Shield(f)
	if not cfg.heals and not cfg.absorbs and not cfg.healAbsorbs then
		return
	end
	local heals, absorbs, eaten = Values(f)
	if type(heals) == "nil" then
		heals = 0
	end
	if type(absorbs) == "nil" then
		absorbs = 0
	end
	if type(eaten) == "nil" then
		eaten = 0
	end
	local unit = f.unit
	if cfg.healAbsorbs then
		f.healAbsorbs:SetBarRange(0, UnitHealthMax(unit))
		f.healAbsorbs:SetBarValue(eaten)
	end
	if cfg.heals then
		f.heals:SetBarRange(0, UnitHealthMax(unit))
		f.heals:SetBarValue(heals)
	end
	if cfg.absorbs then
		f.absorbs:SetBarRange(0, UnitHealthMax(unit))
		f.absorbs:SetBarValue(absorbs)
	end
end
Prediction.Update = Update

local function PaintSample(f, sample)
	local cfg = Settings.current.prediction
	f.heals:SetBarRange(0, 1)
	f.heals:SetBarValue(cfg.heals and sample.incoming or 0)
	f.absorbs:SetBarRange(0, 1)
	f.absorbs:SetBarValue(cfg.absorbs and sample.absorb or 0)
	f.shield:SetBarRange(0, 1)
	f.shield:SetBarValue(cfg.shield and (sample.shield or sample.absorb) or 0)
	f.healAbsorbs:SetBarRange(0, 1)
	f.healAbsorbs:SetBarValue(cfg.healAbsorbs and sample.healAbsorb or 0)
end
Style.painters[#Style.painters + 1] = PaintSample

Unit.extra[#Unit.extra + 1] = Update
Unit.Chain("UNIT_HEAL_PREDICTION", Update)
Unit.Chain("UNIT_ABSORB_AMOUNT_CHANGED", Update)
Unit.Chain("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", Update)
Unit.Chain("UNIT_HEALTH", Update)
Unit.Chain("UNIT_MAXHEALTH", Update)
