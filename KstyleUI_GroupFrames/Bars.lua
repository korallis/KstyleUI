-- Bars.lua: optional health bar looks: the bar filling with missing health, patterned shields and heal absorbs, the shield glow and lost maximum health.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local Settings, Style, Unit = ns.Settings, ns.Style, ns.Unit

local STRIPES = { absorbs = "RaidFrame-Shield-Overlay", healAbsorbs = "RaidFrame-Absorb-Overlay", maxLoss = "raidframe-MaximumHealthReduction-Overlay" }
local GLOW = "RaidFrame-Shield-Overshield"
local GLOW_WIDTH = 8

local function HasAtlas(name)
	local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
	if not info then
		Style.LogOnce("atlas:" .. name, "the " .. name .. " atlas is missing; that bar keeps its plain look")
	end
	return info ~= nil
end

local function Stripes(bar, atlas, color, striped, own)
	if striped and not bar.stripes and HasAtlas(atlas) then
		bar.stripes = bar:CreateTexture(nil, "ARTWORK", nil, 1)
		bar.stripes:SetAtlas(atlas, false, nil, nil, "REPEAT", "REPEAT")
		bar.stripes:SetHorizTile(true)
		bar.stripes:SetVertTile(true)
	end
	local stripes = bar.stripes
	if not stripes then
		return
	end
	stripes:SetShown(striped)
	if striped then
		local alpha = color.a or 1
		stripes:SetAllPoints(bar:GetStatusBarTexture())
		stripes:SetVertexColor(Widgets.Rgba("white", alpha))
		local p = Settings.current.prediction
		bar:SetBarColor(color.r, color.g, color.b, alpha * (own and p.backingOwn and p[own] or p.backing))
	end
end

local function Missing(f, vertical)
	local wanted = Settings.current.health.missing
	local missing = wanted and type(UnitHealthMissing) == "function"
	if wanted and not missing then
		Style.LogOnce("noMissing", "UnitHealthMissing is missing; the health bar fills with health")
	end
	if missing ~= (f.missingFill == true) then
		f.missingFill = missing
		f.health:SetReverseFill(missing)
		f.health:SetLoss(not missing)
	end
	if not missing then
		return
	end
	local fill = f.health:GetStatusBarTexture()
	f.heals:ClearAllPoints()
	f.healAbsorbs:ClearAllPoints()
	if vertical then
		f.heals:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0)
		f.healAbsorbs:SetPoint("TOPLEFT", fill, "BOTTOMLEFT", 0, 0)
	else
		f.heals:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
		f.healAbsorbs:SetPoint("TOPRIGHT", fill, "TOPLEFT", 0, 0)
	end
	if f.overClip then
		f.overClip:ClearAllPoints()
		f.overClip:SetPoint(vertical and "BOTTOMLEFT" or "TOPLEFT", f.health)
		f.overClip:SetPoint(vertical and "TOPRIGHT" or "BOTTOMRIGHT", fill, vertical and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, 0)
	end
end

local function Glow(f, vertical)
	local on = Settings.current.prediction.glow and not vertical
	if on and not f.shieldGlow and HasAtlas(GLOW) then
		f.shieldGlow = f.predict:CreateTexture(nil, "OVERLAY")
		f.shieldGlow:SetAtlas(GLOW)
		f.shieldGlow:SetBlendMode("ADD")
	end
	local glow = f.shieldGlow
	if not glow then
		return
	end
	glow:SetShown(on)
	glow:ClearAllPoints()
	glow:SetPoint("TOPRIGHT", f.health, "TOPRIGHT", 0, 0)
	glow:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", 0, 0)
	glow:SetWidth(Widgets.Snap(f, GLOW_WIDTH))
	glow:SetAlpha(0)
end

local function MaxLoss(f, rect)
	local p = Settings.current.prediction
	local on = p.maxLoss ~= "OFF"
	if on and not f.maxLoss then
		f.maxLoss = Widgets.StatusBar(f.predict, { background = false, reverse = true })
	end
	local bar = f.maxLoss
	if not bar then
		return
	end
	bar:SetShown(on)
	if not on then
		return
	end
	bar:SetOrientation(Settings.current.health.orientation)
	bar:SetBarTexture(Settings.current.health.texture)
	bar.opts.width, bar.opts.height = rect.width, rect.height
	bar:Restyle()
	bar:ClearAllPoints()
	bar:SetPoint("TOPRIGHT", f.health, "TOPRIGHT", 0, 0)
	bar:SetBarRange(0, 1)
	local c = p.maxLossColor
	bar:SetBarColor(c.r, c.g, c.b, c.a or 1)
	Stripes(bar, STRIPES.maxLoss, c, p.maxLoss == "STRIPES", "maxLossBacking")
end

local function Layout(f, parts)
	local cfg = Settings.current
	local p = cfg.prediction
	local vertical = cfg.health.orientation == "VERTICAL"
	Missing(f, vertical)
	Stripes(f.absorbs, STRIPES.absorbs, p.absorbColor, p.absorbStyle == "STRIPES")
	if f.overshield then
		Stripes(f.overshield, STRIPES.absorbs, p.absorbColor, p.absorbStyle == "STRIPES")
	end
	Stripes(f.healAbsorbs, STRIPES.healAbsorbs, p.healAbsorbColor, p.healAbsorbStyle == "STRIPES", "healAbsorbBacking")
	Glow(f, vertical)
	MaxLoss(f, parts.health)
end
Style.appliers[#Style.appliers + 1] = Layout

local function MaxLossValue(f)
	if f.maxLoss and Settings.current.prediction.maxLoss ~= "OFF" then
		if type(GetUnitTotalModifiedMaxHealthPercent) == "function" then
			f.maxLoss:SetBarValue(GetUnitTotalModifiedMaxHealthPercent(f.unit))
		else
			Style.LogOnce("noMaxLoss", "GetUnitTotalModifiedMaxHealthPercent is missing; lost maximum health stays empty")
			f.maxLoss:SetBarValue(0)
		end
	end
end

local function GlowValue(f)
	local glow, calc = f.shieldGlow, f.glowCalc
	if not (glow and glow:IsShown()) then
		return
	end
	if calc == nil then
		local modes = Enum and Enum.UnitDamageAbsorbClampMode
		calc = modes and modes.MissingHealthWithoutIncomingHeals and type(CreateUnitHealPredictionCalculator) == "function" and CreateUnitHealPredictionCalculator()
		if calc and calc.SetDamageAbsorbClampMode then calc:SetDamageAbsorbClampMode(modes.MissingHealthWithoutIncomingHeals) else calc = false end
		f.glowCalc = calc
	end
	if not calc or type(UnitGetDetailedHealPrediction) ~= "function" then
		Style.LogOnce("glowCalculator", "the heal prediction calculator is missing; the shield glow stays off")
		glow:SetAlpha(0)
		return
	end
	UnitGetDetailedHealPrediction(f.unit, "player", calc)
	local _, clamped = calc:GetDamageAbsorbs()
	if glow.SetAlphaFromBoolean then
		glow:SetAlphaFromBoolean(clamped, 1, 0)
	elseif not Unit.IsSecret(clamped) then
		glow:SetAlpha(clamped and 1 or 0)
	end
end

local function PaintSample(f, sample)
	if f.maxLoss then
		f.maxLoss:SetBarValue(sample.maxLoss or 0)
	end
	if f.shieldGlow then
		f.shieldGlow:SetAlpha(sample.overshield and 1 or 0)
	end
end
Style.painters[#Style.painters + 1] = PaintSample

Unit.extra[#Unit.extra + 1] = MaxLossValue
Unit.extra[#Unit.extra + 1] = GlowValue
Unit.Chain("UNIT_MAX_HEALTH_MODIFIERS_CHANGED", MaxLossValue)
for _, event in ipairs({ "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEALTH", "UNIT_MAXHEALTH" }) do
	Unit.Chain(event, GlowValue)
end
