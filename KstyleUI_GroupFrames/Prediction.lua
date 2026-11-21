-- Prediction.lua: incoming heals and absorbs after the health fill and heal absorbs back from its end, from the heal prediction calculator, values passed straight to the bars.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local Settings, Style, Unit, Button = ns.Settings, ns.Style, ns.Unit, ns.Button

local Prediction = {}
ns.Prediction = Prediction

local HEALER = "player"
local LEVEL_ABOVE_HEALTH = 1
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

local ACROSS = { BOTTOM = "TOP", TOP = "BOTTOM", LEFT = "RIGHT", RIGHT = "LEFT" }
local CORNER = { BOTTOM = "BOTTOMLEFT", TOP = "TOPLEFT", LEFT = "TOPLEFT", RIGHT = "TOPRIGHT" }

local function Line(f, bar, rect, thickness, place, color)
	local upright = place == "LEFT" or place == "RIGHT"
	bar:SetOrientation(upright and "VERTICAL" or "HORIZONTAL")
	if upright or bar.reversed then
		bar.reversed = upright and Settings.current.prediction.shieldGrow == "DOWN"
		bar:SetReverseFill(bar.reversed)
	end
	bar:SetBarTexture(Settings.current.health.texture)
	bar.opts.width, bar.opts.height = upright and thickness or rect.width, upright and rect.height or thickness
	bar:Restyle()
	bar:ClearAllPoints()
	local above = place == "BOTTOM" and f.behind
	bar:SetPoint(CORNER[place], above and f.power or f.health, above and "TOPLEFT" or CORNER[place], 0, 0)
	bar:SetBarColor(color.r, color.g, color.b, SHIELD_ALPHA)
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
	f.predict:SetFrameLevel(f.health:GetFrameLevel() + LEVEL_ABOVE_HEALTH)
	for _, bar in ipairs({ f.heals, f.absorbs }) do
		bar:SetOrientation(cfg.health.orientation)
		bar:SetBarTexture(cfg.health.texture)
		bar.opts.width, bar.opts.height = rect.width, rect.height
		bar:Restyle()
		bar:ClearAllPoints()
	end
	local healFill = f.heals:GetStatusBarTexture()
	local fromEnd = cfg.prediction.absorbPlace == "END"
	if fromEnd or f.absorbsFromEnd then
		f.absorbs:SetReverseFill(fromEnd)
		f.absorbsFromEnd = fromEnd
	end
	if vertical then
		f.heals:SetPoint("BOTTOMLEFT", fill, "TOPLEFT", 0, 0)
		f.absorbs:SetPoint(fromEnd and "TOPLEFT" or "BOTTOMLEFT", fromEnd and f.health or healFill, "TOPLEFT", 0, 0)
	else
		f.heals:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
		f.absorbs:SetPoint(fromEnd and "TOPRIGHT" or "TOPLEFT", fromEnd and f.health or healFill, "TOPRIGHT", 0, 0)
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
	local p = cfg.prediction
	local line = Widgets.Border(f) * p.shieldLines
	local c = p.absorbColor
	Line(f, f.shield, rect, line, p.shieldPlace, c)
	f.shield:SetShown(p.shield)
	if p.healAbsorbLine and not f.healAbsorbLine then
		f.healAbsorbLine = Widgets.StatusBar(f.predict, { background = false, smooth = true })
	end
	if f.healAbsorbLine then
		Line(f, f.healAbsorbLine, rect, line, ACROSS[p.shieldPlace], p.healAbsorbColor)
		f.healAbsorbLine:SetShown(p.healAbsorbLine)
	end
	if p.overshield and not f.overClip then
		f.overClip = CreateFrame("Frame", nil, f.predict)
		f.overClip:SetClipsChildren(true)
		f.overshield = Widgets.StatusBar(f.overClip, { background = false, smooth = true, reverse = true })
	end
	if f.overClip then
		local over = f.overshield
		f.overClip:ClearAllPoints()
		f.overClip:SetPoint(vertical and "BOTTOMLEFT" or "TOPLEFT", f.health, vertical and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
		f.overClip:SetPoint(vertical and "TOPRIGHT" or "BOTTOMRIGHT", fill, vertical and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
		over:SetOrientation(cfg.health.orientation)
		over:SetReverseFill(true)
		over:SetBarTexture(cfg.health.texture)
		over.opts.width, over.opts.height = rect.width, rect.height
		over:Restyle()
		over:ClearAllPoints()
		over:SetPoint("TOPRIGHT", f.health, "TOPRIGHT", 0, 0)
		Paint(over, c)
		f.overClip:SetShown(p.overshield)
	end
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
	local cfg = Settings.current.prediction
	local unit = f.unit
	if cfg.healAbsorbLine and f.healAbsorbLine then
		f.healAbsorbLine:SetBarValue(TotalHealAbsorbs(unit))
	end
	if not cfg.shield and not cfg.overshield then
		return
	end
	local total = 0
	if type(UnitGetTotalAbsorbs) == "function" then
		total = UnitGetTotalAbsorbs(unit)
	else
		Style.LogOnce("noTotalAbsorbs", "UnitGetTotalAbsorbs is missing; the shield line stays empty")
	end
	if cfg.shield then f.shield:SetBarValue(total) end
	if cfg.overshield and f.overshield then f.overshield:SetBarValue(total) end
end

local function Ranges(f)
	local cfg = Settings.current.prediction
	local maximum = UnitHealthMax(f.unit)
	if cfg.shield then
		f.shield:SetBarRange(0, maximum)
	end
	if cfg.overshield and f.overshield then
		f.overshield:SetBarRange(0, maximum)
	end
	if cfg.healAbsorbLine and f.healAbsorbLine then
		f.healAbsorbLine:SetBarRange(0, maximum)
	end
	if cfg.healAbsorbs then
		f.healAbsorbs:SetBarRange(0, maximum)
	end
	if cfg.heals then
		f.heals:SetBarRange(0, maximum)
	end
	if cfg.absorbs then
		f.absorbs:SetBarRange(0, maximum)
	end
	f.predictionRangeDirty = false
end

local function Update(f)
	local cfg = Settings.current.prediction
	if f.predictionRangeDirty ~= false then
		Ranges(f)
	end
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
	if cfg.healAbsorbs then
		f.healAbsorbs:SetBarValue(eaten)
	end
	if cfg.heals then
		f.heals:SetBarValue(heals)
	end
	if cfg.absorbs then
		f.absorbs:SetBarValue(absorbs)
	end
end
local function Invalidate(f)
	f.predictionRangeDirty = true
end

local function Refresh(f)
	Invalidate(f)
	Update(f)
end
Prediction.Update = Refresh

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
	if f.overshield then
		f.overshield:SetBarRange(0, 1)
		f.overshield:SetBarValue(cfg.overshield and sample.overshield or 0)
	end
	if f.healAbsorbLine then
		f.healAbsorbLine:SetBarRange(0, 1)
		f.healAbsorbLine:SetBarValue(cfg.healAbsorbLine and sample.healAbsorb or 0)
	end
end
Style.painters[#Style.painters + 1] = PaintSample

local settingsRefresh = Settings.Refresh
function Settings.Refresh()
	local cfg = settingsRefresh()
	Unit.ForEach(Invalidate)
	return cfg
end

Unit.changed[#Unit.changed + 1] = Invalidate
Unit.extra[#Unit.extra + 1] = Refresh
Unit.Chain("UNIT_HEAL_PREDICTION", Update)
Unit.Chain("UNIT_ABSORB_AMOUNT_CHANGED", Update)
Unit.Chain("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", Update)
Unit.Chain("UNIT_HEALTH", Update)
Unit.Chain("UNIT_MAXHEALTH", Refresh)
