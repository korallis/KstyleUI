-- Plate.lua: one KstyleUI plate built from the widget kit: health bar, texts, level badge, markers, threat glow and highlights.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme, Scale = K.Widgets, K.Tokens, K.Theme, K.Scale
local Logic, Settings = ns.Logic, ns.Settings
local IsSecret = Logic.IsSecret

local Plate = {}
ns.Plate = Plate

local Components = {}
ns.Components = Components

local function Each(method, plate, ...)
	for i = 1, #Components do
		local fn = Components[i][method]
		if fn then
			fn(plate, ...)
		end
	end
end

local function BottomRoom(plate)
	local room = 0
	for i = 1, #Components do
		local fn = Components[i].Room
		if fn then
			room = room + fn(plate)
		end
	end
	return room
end

Plate.DEFAULT_WIDTH, Plate.DEFAULT_HEIGHT = 120, 10

local GAP = Tokens.Size("gapTiny")
local BADGE_GAP = Tokens.Size("gapSmall")
local TEXT_INSET = Tokens.Size("gapSmall")
local BADGE_PAD = Tokens.Size("gapSmall")
local MARKER_SIZE = 8
local MARKER_ROTATION = math.pi / 4
local GLOW_CORNER, GLOW_OUTSET = 8, 6
local THREAT_GLOW_ALPHA, TARGET_GLOW_ALPHA = 0.9, 0.7
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local RAID_ROWS, RAID_COLUMNS = 4, 4
local OUTLINE_FLAGS = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }
local SKULL_LEVEL = -1
local THREAT_KEYS = { safe = "threat.safe", warning = "threat.warning", danger = "threat.danger" }
local SOURCE_KEYS = { enemy = "enemy.colorSource", friendly = "friendly.colorSource" }
local COLOR_KEYS = { enemy = "enemy.color", friendly = "friendly.color" }

local fallbackLogged = {}

local function Log(message)
	K.DevTest.Log(Settings.MODULE, message)
end

local function LogOnce(key, message)
	if not fallbackLogged[key] then
		fallbackLogged[key] = true
		Log(message)
	end
end
ns.LogOnce = LogOnce

local function Plain(value)
	return not IsSecret(value) and value
end

local function StyleFont(text, size, outline)
	local flags = OUTLINE_FLAGS[outline] or "OUTLINE"
	local path = Settings.Get("font")
	if text:SetFont(path, size, flags) == false then
		local worldPath = Tokens.Font("world")
		text:SetFont(worldPath, size, flags)
		LogOnce("font:" .. path, "the font " .. path .. " did not load; plates use the world font")
	end
	if flags == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
end

local function NewText(parent, justify)
	local text = Widgets.FontString(parent, "OVERLAY")
	text:SetJustifyH(justify)
	text:SetWordWrap(false)
	return text
end

local function UnitValue(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	return fn(...)
end

local function IsTrue(value)
	return not IsSecret(value) and value == true
end

local function Rgb(color)
	return color.r, color.g, color.b
end

local scaleCurve
local function PercentCurve()
	if scaleCurve == nil then
		scaleCurve = CurveConstants and CurveConstants.ScaleTo100 or false
		if not scaleCurve and C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType then
			scaleCurve = C_CurveUtil.CreateCurve()
			scaleCurve:SetType(Enum.LuaCurveType.Linear)
			scaleCurve:AddPoint(0, 0)
			scaleCurve:AddPoint(1, 100)
			LogOnce("curve", "CurveConstants.ScaleTo100 is missing; plates built their own percent curve")
		elseif not scaleCurve then
			LogOnce("curve", "no curve API; health text shows values instead of percents")
		end
	end
	return scaleCurve or nil
end

function ns.NewPlate(parent, sample)
	local plate = CreateFrame("Frame", nil, parent)
	for name, fn in pairs(Plate) do
		if type(fn) == "function" then
			plate[name] = fn
		end
	end
	plate.sample = sample
	plate.base = not sample and parent or nil

	local glowFrame = CreateFrame("Frame", nil, plate)
	plate.glowFrame = glowFrame
	plate.targetGlow = Widgets.NineSlice(glowFrame, "shadow", "BACKGROUND", -2)
	plate.threatGlow = Widgets.NineSlice(glowFrame, "shadow", "BACKGROUND", -1)
	for _, slice in ipairs({ plate.targetGlow, plate.threatGlow }) do
		for _, piece in ipairs(slice) do
			piece:SetBlendMode("ADD")
		end
		Widgets.ShowSlice(slice, false)
	end

	plate.healthOpts = { width = Plate.DEFAULT_WIDTH, height = Plate.DEFAULT_HEIGHT, smooth = true, border = true, color = "hostile" }
	local health = Widgets.StatusBar(plate, plate.healthOpts)
	plate.health = health
	plate.healthText = NewText(health, "RIGHT")

	plate.name = NewText(plate, "LEFT")

	local badge = CreateFrame("Frame", nil, plate)
	badge.chrome = Widgets.Chrome(badge, { shape = "tile", fill = "raised", shadow = false })
	plate.level = badge
	plate.levelText = NewText(badge, "CENTER")

	local marker = plate:CreateTexture(nil, "OVERLAY")
	marker:SetTexture((Tokens.Texture("iconMask")))
	marker:SetRotation(MARKER_ROTATION)
	marker:Hide()
	plate.marker = marker

	local raid = plate:CreateTexture(nil, "OVERLAY")
	raid:SetTexture(RAID_ICONS)
	raid:Hide()
	plate.raid = raid

	plate.colorKey = {}
	Each("Build", plate)
	Widgets.Track(plate)
	plate:Restyle()
	return plate
end

function Plate:ApplyScale()
	if self.sample then
		self:SetScale(1)
		return
	end
	local parent = self:GetParent()
	local reference = parent:GetParent() or parent
	self:SetScale(Logic.PlateScale(Scale.Root():GetEffectiveScale(), reference:GetEffectiveScale()))
end

function Plate:Restyle()
	self:ApplyScale()
	local state = ns.state
	local w, h = state.width, state.height
	local opts = self.healthOpts
	opts.width, opts.height = w, h
	Widgets.Size(self, w, h)
	self:ClearAllPoints()
	if self.sample then
		self:SetPoint("CENTER", self:GetParent(), "CENTER")
	else
		self:SetPoint("BOTTOM", self:GetParent(), "BOTTOM", 0, Widgets.Snap(self, Settings.Get("offsetY") + BottomRoom(self)))
	end

	local health = self.health
	health:ClearAllPoints()
	health:SetPoint("CENTER", self, "CENTER")
	local orientation = Settings.Get("health.orientation")
	health:SetOrientation(orientation)
	health.vertical = orientation == "VERTICAL"
	health:SetReverseFill(Settings.Get("health.reverse"))
	health:SetBarTexture(Settings.Get("health.texture"))
	health:Restyle()

	StyleFont(self.name, Settings.Get("name.size"), Settings.Get("name.outline"))
	StyleFont(self.levelText, Settings.Get("level.size"), Settings.Get("level.outline"))
	StyleFont(self.healthText, Settings.Get("healthText.size"), Settings.Get("healthText.outline"))

	self.healthText:ClearAllPoints()
	self.healthText:SetPoint("RIGHT", health, "RIGHT", -Widgets.Snap(self, TEXT_INSET), 0)

	local badge = self.level
	local side = math.max(h, Settings.Get("level.size") + BADGE_PAD)
	Widgets.Size(badge, side, side)
	badge:ClearAllPoints()
	badge:SetPoint("RIGHT", health, "LEFT", -Widgets.Snap(self, BADGE_GAP), 0)
	badge.chrome:Restyle()
	self.levelText:ClearAllPoints()
	self.levelText:SetPoint("CENTER", badge, "CENTER")

	Widgets.Size(self.marker, MARKER_SIZE, MARKER_SIZE)
	self.marker:ClearAllPoints()
	self.marker:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 0, Widgets.Snap(self, GAP))

	local raidSize = Settings.Get("markers.raidSize")
	Widgets.Size(self.raid, raidSize, raidSize)
	self.raid:ClearAllPoints()
	self.raid:SetPoint("LEFT", health, "RIGHT", Widgets.Snap(self, BADGE_GAP), 0)

	self.glowFrame:SetFrameLevel(math.max(0, health:GetFrameLevel() - 2))
	Widgets.LayoutSlice(self.targetGlow, health, GLOW_CORNER, GLOW_OUTSET)
	Widgets.LayoutSlice(self.threatGlow, health, GLOW_CORNER, GLOW_OUTSET)

	self.nameOnly = nil
	Each("Restyle", self)
	self:Refresh(true)
end

function Plate:LayoutName()
	local name, health = self.name, self.health
	name:ClearAllPoints()
	if self.nameOnly then
		name:SetJustifyH("CENTER")
		name:SetPoint("CENTER", self, "CENTER")
		name:SetWidth(ns.state.width)
	else
		name:SetJustifyH("LEFT")
		name:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 0, Widgets.Snap(self, GAP))
		name:SetWidth(math.max(1, ns.state.width - MARKER_SIZE - GAP))
	end
end

function Plate:SetUnit(unit)
	self.unit = unit
	self.colorKey.r = nil
	self:Show()
	self:Refresh(true)
end

function Plate:ClearUnit()
	self.unit = nil
	self.threatState = nil
	Each("Clear", self)
	self:Hide()
end

function Plate:Refresh(immediate)
	if not self.unit and not self.sample then
		return
	end
	self:UpdateStyle()
	self:UpdateHealth(immediate)
	self:UpdateName()
	self:UpdateLevel()
	self:UpdateMarker()
	self:UpdateRaid()
	self:UpdateThreat()
	self:UpdateHighlight()
	Each("Refresh", self, immediate)
end

function Plate:RefreshFlags()
	if not self.unit and not self.sample then
		return
	end
	local kind, nameOnly = self.kind, self.nameOnly
	self:UpdateStyle()
	if self.kind ~= kind or self.nameOnly ~= nameOnly then
		self:Refresh()
		return
	end
	self:UpdateThreat()
end

function Plate:Is(field, fn, ...)
	local sample = self.sample
	if sample then
		return sample[field]
	end
	return UnitValue(fn, ...)
end

function Plate:UpdateStyle()
	local canAttack = self:Is("enemy", UnitCanAttack, "player", self.unit)
	self.kind = (IsSecret(canAttack) or canAttack) and "enemy" or "friendly"
	local nameOnly = self.kind == "friendly" and Settings.Get("friendly.nameOnly")
	if nameOnly ~= self.nameOnly then
		self.nameOnly = nameOnly
		self:LayoutName()
	end
	self.health:SetShown(not nameOnly)
	self:UpdateColor()
end

function Plate:UpdateColor()
	local r, g, b
	local state = self.threatState
	if state and Settings.Get("threat.display") == "health" then
		r, g, b = Rgb(Settings.Get(THREAT_KEYS[state]))
	else
		local kind = self.kind
		local tapped = kind == "enemy" and IsTrue(self:Is("tapped", UnitIsTapDenied, self.unit))
		local isPlayer = IsTrue(self:Is("isPlayer", UnitIsPlayer, self.unit))
		local source = Logic.ColorKind(Settings.Get(SOURCE_KEYS[kind]), isPlayer, tapped)
		if source == "tapped" then
			r, g, b = Tokens.Color("textDisabled")
		elseif source == "custom" then
			r, g, b = Rgb(Settings.Get(COLOR_KEYS[kind]))
		elseif source == "class" then
			local class = self.sample and self.sample.class or select(2, UnitValue(UnitClass, self.unit))
			r, g, b = Theme.ClassColorForWidget(class)
		else
			local reaction = self.sample and self.sample.reaction or UnitValue(UnitReaction, self.unit, "player")
			r, g, b = Theme.ReactionColor(reaction)
		end
	end
	local last = self.colorKey
	if IsSecret(r) or IsSecret(g) or IsSecret(b) then
		last.r, last.g, last.b = nil, nil, nil
		self.health:SetBarColor(r, g, b)
	elseif last.r ~= r or last.g ~= g or last.b ~= b then
		last.r, last.g, last.b = r, g, b
		self.health:SetBarColor(r, g, b)
	end
end

function Plate:UpdateHealth(immediate)
	local health = self.health
	local sample = self.sample
	if sample then
		health:SetBarRange(0, 1)
		health:SetValue(sample.health)
	else
		local unit = self.unit
		health:SetBarRange(0, UnitHealthMax(unit))
		if immediate then
			health:SetValue(UnitHealth(unit))
		else
			health:SetBarValue(UnitHealth(unit))
		end
	end
	self:UpdateHealthText()
end

function Plate:UpdateHealthText()
	local text = self.healthText
	local show = Settings.Get("healthText.show") and not self.nameOnly
	text:SetShown(show)
	if not show then
		return
	end
	local sample = self.sample
	if sample then
		text:SetFormattedText("%.0f%%", sample.health * 100)
		return
	end
	local unit = self.unit
	local format = Settings.Get("healthText.format")
	local curve = PercentCurve()
	if format == "value" or not curve then
		text:SetText(AbbreviateNumbers(UnitHealth(unit)))
	elseif format == "both" then
		text:SetFormattedText("%s  %.0f%%", AbbreviateNumbers(UnitHealth(unit)), UnitHealthPercent(unit, true, curve))
	else
		text:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, curve))
	end
end

function Plate:UpdateName()
	local name = self.name
	local show = Settings.Get("name.show")
	name:SetShown(show)
	if not show then
		return
	end
	local value = self:Is("name", UnitName, self.unit)
	if IsSecret(value) then
		name:SetText(value)
	elseif type(value) == "string" then
		name:SetText(Settings.Get("name.upper") and value:upper() or value)
	else
		name:SetText("")
	end
	local isPlayer = IsTrue(self:Is("isPlayer", UnitIsPlayer, self.unit))
	if isPlayer and Settings.Get("name.classColor") then
		local class = self.sample and self.sample.class or select(2, UnitValue(UnitClass, self.unit))
		name:SetTextColor(Theme.ClassColorForWidget(class))
	else
		name:SetTextColor(Tokens.Color("textEmphasis"))
	end
end

function Plate:UpdateLevel()
	local badge = self.level
	local level = self:Is("level", UnitEffectiveLevel or UnitLevel, self.unit)
	local text = Logic.LevelText(level)
	local show = Settings.Get("level.show") and not self.nameOnly and text ~= nil
	badge:SetShown(show and true or false)
	if not show then
		return
	end
	self.levelText:SetText(text)
	local color = level ~= SKULL_LEVEL and self.kind == "enemy" and UnitValue(GetQuestDifficultyColor, level)
	if level == SKULL_LEVEL then
		self.levelText:SetTextColor(Tokens.Color("hostile"))
	elseif type(color) == "table" and Plain(color.r) and Plain(color.g) and Plain(color.b) then
		self.levelText:SetTextColor(color.r, color.g, color.b)
	else
		self.levelText:SetTextColor(Tokens.Color("textEmphasis"))
	end
end

function Plate:UpdateMarker()
	local marker = self.marker
	local name = Settings.Get("markers.classification") and not self.nameOnly
		and Logic.MarkerColor(self:Is("classification", UnitClassification, self.unit))
	if not name then
		marker:Hide()
		return
	end
	marker:SetVertexColor(Tokens.Color(name))
	marker:Show()
end

function Plate:UpdateRaid()
	local raid = self.raid
	if not Settings.Get("markers.raid") then
		raid:Hide()
		return
	end
	local index = self:Is("raid", GetRaidTargetIndex, self.unit)
	if type(index) == "nil" then
		raid:Hide()
		return
	end
	raid:SetSpriteSheetCell(index, RAID_ROWS, RAID_COLUMNS)
	raid:Show()
end

function Plate:UpdateThreat()
	local display = Settings.Get("threat.display")
	local state
	if display ~= "off" and self.kind == "enemy" and not self.nameOnly then
		if self.sample then
			state = self.sample.threat
		elseif ns.state.inGroup or not Settings.Get("threat.groupOnly") then
			state = Logic.ThreatState(UnitValue(UnitThreatSituation, "player", self.unit), ns.state.isTank)
		end
	end
	local changed = state ~= self.threatState
	self.threatState = state
	local glow = self.threatGlow
	if state and display == "glow" then
		local r, g, b = Rgb(Settings.Get(THREAT_KEYS[state]))
		Widgets.ColorSlice(glow, r, g, b, THREAT_GLOW_ALPHA)
		Widgets.ShowSlice(glow, true)
	else
		Widgets.ShowSlice(glow, false)
	end
	if changed then
		self:UpdateColor()
	end
end

local function TargetColor()
	if Settings.Get("target.colorSource") == "custom" then
		return Rgb(Settings.Get("target.color"))
	end
	return Theme.Accent()
end

function Plate:UpdateHighlight()
	local state = ns.state
	local isTarget, isFocus
	if self.sample then
		isTarget, isFocus = self.sample.target, self.sample.focus
	else
		isTarget = ns.Plates.IsUnit(self, "target")
		isFocus = ns.Plates.IsUnit(self, "focus")
	end
	local bar = not self.nameOnly
	local glow = self.targetGlow
	local chrome = self.health.chrome
	if isTarget and Settings.Get("target.highlight") and bar then
		local r, g, b = TargetColor()
		Widgets.ColorSlice(glow, r, g, b, TARGET_GLOW_ALPHA)
		Widgets.ShowSlice(glow, true)
		chrome:SetEdgeRGBA(r, g, b, 1)
	else
		Widgets.ShowSlice(glow, false)
		if isFocus and Settings.Get("focus.highlight") then
			local r, g, b = Rgb(Settings.Get("focus.color"))
			chrome:SetEdgeRGBA(r, g, b, 1)
		else
			chrome:SetEdge("edgeInner")
		end
	end
	local alpha = 1
	if not self.sample and state.hasTarget and not isTarget then
		alpha = Settings.Get("target.dimOthers")
	end
	self:SetAlpha(alpha)
end
