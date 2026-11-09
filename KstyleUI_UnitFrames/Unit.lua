-- Unit.lua: fills a unit frame's parts from the unit API, passing health, power and other secret values straight to widget setters; a name too long for its line drops to the body size before it truncates.
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

function Unit.ReactionColor(reaction)
	if not IsSecret(reaction) and type(reaction) == "number" and reaction <= HOSTILE_MAX then
		return Tokens.Color("healthHostile")
	end
	return Theme.ReactionColor(reaction)
end

local function ReactionColor(unit)
	return Unit.ReactionColor(UnitReaction(unit, "player"))
end

local function UnitColor(unit, source)
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
	if UnitIsConnected and not UnitIsConnected(unit) or UnitIsTapDenied and UnitIsTapDenied(unit) then
		r, g, b = Tokens.Color("textDisabled")
	elseif s.healthColor == "custom" then
		local c = s.healthCustom
		r, g, b = c.r, c.g, c.b
	else
		r, g, b = UnitColor(unit, s.healthColor)
	end
	SetColor(view.health, r, g, b)
	ns.Style.HealthTint(view, r, g, b)
end

local function PowerTypeColor(unit)
	local token = "MANA"
	if unit then
		local _, own = UnitPowerType(unit)
		token = own
	end
	local colors = PowerBarColor
	local c = type(token) == "string" and not IsSecret(token) and colors and colors[token]
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

local glowCurve, glowTried

local function GlowCurve()
	if glowTried then
		return glowCurve
	end
	glowTried = true
	local util = C_CurveUtil
	if not (util and type(util.CreateColorCurve) == "function" and CreateColor and UnitHealthPercent) then
		Log("low-health ring: no colour curve API; the ring does not glow")
		return nil
	end
	local ok, curve = pcall(util.CreateColorCurve)
	if not ok or not curve then
		Log("low-health ring: CreateColorCurve failed; the ring does not glow")
		return nil
	end
	local kinds = Enum and Enum.LuaCurveType
	if kinds and kinds.Linear and curve.SetType then
		curve:SetType(kinds.Linear)
	end
	local r, g, b = Tokens.Color("healthHostile")
	for _, point in ipairs(GLOW_POINTS) do
		curve:AddPoint(point[1], CreateColor(r, g, b, point[2]))
	end
	glowCurve = curve
	Log("low-health ring: a C_CurveUtil colour curve over UnitHealthPercent")
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
	local color = UnitHealthPercent(unit, true, curve)
	glow:SetVertexColor(color:GetRGBA())
	glow:Show()
end

local function LumenHealth(view, unit, form, format)
	if form == "vitals" then
		local main, split = format, false
		if format == "both" or format == "currentMax" then
			main, split = "current", true
		end
		Format.Health(view.healthText, unit, main)
		if split then
			Format.Max(view.healthSub, unit)
		else
			view.healthSub:SetText("")
		end
	elseif form == "card" then
		Format.Health(view.healthText, unit, Format.Main(format))
	elseif form == "row" then
		Format.Health(view.healthText, unit, format)
	end
end

function Unit.Health(view, unit, instant)
	local bar = view.health
	bar:SetBarRange(0, UnitHealthMax(unit))
	SetValue(bar, UnitHealth(unit), instant)
	local format = view.s.healthText
	local form = view.geometry and view.geometry.form or "plate"
	if form ~= "plate" then
		LumenHealth(view, unit, form, format)
		Unit.Glow(view, unit)
	elseif view.geometry and view.geometry.healthSub then
		Format.Health(view.healthText, unit, Format.Main(format))
		Format.HealthDetail(view.healthSub, unit, format)
	else
		Format.Health(view.healthText, unit, format)
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
	local max = UnitPowerMax(unit)
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
	SetValue(bar, UnitPower(unit), instant)
	Format.Power(view.powerText, unit, view.s.powerText)
end

function Unit.Name(view, unit)
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
	if OwnFont(fontPath) and fontPath ~= Tokens.FontPath("CinzelSemiBold") then
		text = text:gsub(CODEPOINT, "%1" .. THIN_SPACE):sub(1, -#THIN_SPACE - 1)
	end
	return text
end

local function Number(value)
	return not IsSecret(value) and type(value) == "number"
end

local function SetFont(text, path, size, flags)
	if text:SetFont(path, size, flags) == false then
		text:SetFont((Tokens.Font("body")), size, flags)
	end
end

function Unit.SetName(view, name)
	local text = view.name
	local path, full, flags = ns.Settings.Font(view.kind, "name")
	SetFont(text, path, full, flags)
	if IsSecret(name) then
		text:SetText(name)
		return
	end
	text:SetText(view.s.nameCaps and Unit.Tracked(name, path) or name)
	local bodyPath, bodySize = Tokens.Font("body")
	if not Number(full) or bodySize >= full then
		return
	end
	local width, room = K.Widgets.TextWidth(text), text:GetWidth()
	if Number(width) and Number(room) and room > 0 and width > room then
		SetFont(text, bodyPath, bodySize, flags)
		text:SetText(name)
	end
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

local function LevelText(text, level, classification, creature, short)
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
		args[1] = level
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

local function LevelLine(text, unit, short)
	local creature
	if not short and UnitCreatureType then
		creature = UnitCreatureType(unit)
	end
	LevelText(text, UnitLevel(unit), UnitClassification and UnitClassification(unit), creature, short)
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
	elseif form == "sigil" then
		LevelLine(text, unit, false)
	elseif form == "card" then
		LevelLine(text, unit, true)
		view.capLabel:SetText(ns.Settings.CAP_LABELS[view.kind] or "")
	end
end

function Unit.Level(view, unit)
	local text = view.levelText
	if view.form and view.form ~= "plate" then
		Unit.Caption(view, unit)
		if view.form == "vitals" and view.s.level then
			text:SetText(UnitLevel(unit))
			text:SetTextColor(Tokens.Color("textEmphasis"))
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
		SetPortraitTexture(texture, unit, view.s.portraitShape ~= "round")
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
	Indicators.Update(view, unit)
end
