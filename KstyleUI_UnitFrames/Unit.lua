-- Unit.lua: fills a unit frame's parts from the unit API, passing health, power and other secret values straight to widget setters.
local _, ns = ...

local K = KstyleUI
local Tokens, Theme = K.Tokens, K.Theme
local Format = ns.Format

local Unit = {}
ns.Unit = Unit

local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"
local UNKNOWN_LEVEL = "??"
local ELITE_SUFFIX = "+"
local ELITE = { elite = true, rareelite = true }

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

local function SetColor(bar, r, g, b)
	bar:SetBarColor(r, g, b)
end

local function ClassFile(unit)
	local _, file = UnitClass(unit)
	return file
end

local function ReactionColor(unit)
	return Theme.ReactionColor(UnitReaction(unit, "player"))
end

local function UnitColor(unit, source)
	if source == "class" and UnitIsPlayer(unit) then
		local file = ClassFile(unit)
		if HasClass(file) then
			return Theme.ClassColor(file)
		end
	end
	return ReactionColor(unit)
end

function Unit.HealthColor(view, unit)
	local s = view.s
	local bar = view.health
	if UnitIsConnected and not UnitIsConnected(unit) or UnitIsTapDenied and UnitIsTapDenied(unit) then
		SetColor(bar, Tokens.Color("textDisabled"))
		return
	end
	if s.healthColor == "custom" then
		local c = s.healthCustom
		SetColor(bar, c.r, c.g, c.b)
		return
	end
	SetColor(bar, UnitColor(unit, s.healthColor))
end

local function PowerTypeColor(unit)
	local _, token = UnitPowerType(unit)
	local colors = PowerBarColor
	local c = type(token) == "string" and not IsSecret(token) and colors and colors[token]
	if type(c) == "table" and type(c.r) == "number" then
		return Theme.Brighten(c.r, c.g, c.b)
	end
	return Tokens.Color("rare")
end

function Unit.PowerColor(view, unit)
	local s = view.s
	local source = s.powerColor
	if source == "custom" then
		local c = s.powerCustom
		SetColor(view.power, c.r, c.g, c.b)
	elseif source == "power" then
		SetColor(view.power, PowerTypeColor(unit))
	else
		SetColor(view.power, UnitColor(unit, source))
	end
end

local function SetValue(bar, value, instant)
	if instant then
		bar:SetValue(value)
	else
		bar:SetBarValue(value)
	end
end

function Unit.Prediction(view, unit)
	if not view.s.healPrediction then
		view.incoming:Hide()
		view.absorb:Hide()
		return
	end
	local max = UnitHealthMax(unit)
	view.incoming:SetBarRange(0, max)
	view.absorb:SetBarRange(0, max)
	local calc = view.calculator
	if calc == nil and CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
		calc = CreateUnitHealPredictionCalculator()
		view.calculator = calc
		LogOnce("prediction", "heal prediction: CreateUnitHealPredictionCalculator")
	end
	if calc then
		UnitGetDetailedHealPrediction(unit, "player", calc)
		view.incoming:SetBarValue((calc:GetIncomingHeals()))
		view.absorb:SetBarValue((calc:GetDamageAbsorbs()))
		view.absorb:Show()
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
	view.incoming:Show()
end

function Unit.Health(view, unit, instant)
	local bar = view.health
	bar:SetBarRange(0, UnitHealthMax(unit))
	SetValue(bar, UnitHealth(unit), instant)
	Format.Health(view.healthText, unit, view.s.healthText)
	Unit.Prediction(view, unit)
end

function Unit.Power(view, unit, instant)
	if not view.s.power then
		return
	end
	local bar = view.power
	bar:SetBarRange(0, UnitPowerMax(unit))
	SetValue(bar, UnitPower(unit), instant)
	Format.Power(view.powerText, unit, view.s.powerText)
end

function Unit.Name(view, unit)
	local name = UnitName(unit)
	if IsSecret(name) then
		view.name:SetText(name)
		return
	end
	if type(name) ~= "string" then
		name = ""
	end
	if view.s.nameCaps then
		name = name:upper()
	end
	view.name:SetText(name)
end

local function LevelColor(unit)
	if GetCreatureDifficultyColor and UnitCanAttack and UnitCanAttack("player", unit) then
		local level = UnitLevel(unit)
		if not IsSecret(level) and type(level) == "number" and level > 0 then
			local c = GetCreatureDifficultyColor(level)
			if type(c) == "table" and type(c.r) == "number" then
				return Theme.Brighten(c.r, c.g, c.b)
			end
		end
	end
	return Tokens.Color("textEmphasis")
end

function Unit.Level(view, unit)
	local text = view.levelText
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
	text:SetTextColor(LevelColor(unit))
end

local function ClassIcon(texture, unit)
	local file = ClassFile(unit)
	if not HasClass(file) then
		return false
	end
	if GetClassAtlas then
		texture:SetTexCoord(0, 1, 0, 1)
		texture:SetAtlas(GetClassAtlas(file))
		return true
	end
	local coords = not IsSecret(file) and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[file]
	if coords then
		texture:SetTexture(CLASS_CIRCLES)
		texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		return true
	end
	return false
end

function Unit.Portrait(view, unit)
	if not view.s.portrait then
		return
	end
	local texture = view.portrait
	if view.s.portraitStyle == "class" and ClassIcon(texture, unit) then
		return
	end
	texture:SetTexCoord(0, 1, 0, 1)
	if SetPortraitTexture then
		SetPortraitTexture(texture, unit)
	else
		LogOnce("portrait", "SetPortraitTexture is missing; portraits show the class icon")
		ClassIcon(texture, unit)
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
end
