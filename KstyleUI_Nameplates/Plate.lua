-- Plate.lua: one KstyleUI plate built from the widget kit: health bar, texts, level disc, markers, threat glow and highlights.
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

Plate.DEFAULT_WIDTH, Plate.DEFAULT_HEIGHT = 151.56, 13.78
Plate.NAME_OVERHANG = 20
Plate.FRAME_GAP = 1.15

local BORDER_PIXELS = 2
local GAP = Tokens.Size("gapTiny")
local BADGE_GAP = Tokens.Size("gapSmall")
local TEXT_INSET = Tokens.Size("gapSmall")
local BADGE_PAD = Tokens.Size("gapSmall")
local DISC_SIZE, DISC_CHAMFER, DISC_OVERLAP = 34, 10.5, 1
Plate.BADGE_SIZE = DISC_SIZE
local MARKER_SIZE = 12
local MARKER_ROTATION = math.pi / 4
local GLOW_CORNER, GLOW_OUTSET = 8, 6
local THREAT_GLOW_ALPHA = 0.9
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local RAID_ROWS, RAID_COLUMNS = 4, 4
local OUTLINE_FLAGS = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }
local SKULL_LEVEL = -1
local THREAT_KEYS = { safe = "threat.safe", warning = "threat.warning", danger = "threat.danger" }
local SOURCE_KEYS = { enemy = "enemy.colorSource", friendly = "friendly.colorSource" }
local COLOR_KEYS = { enemy = "enemy.color", friendly = "friendly.color" }
local TYPES = { "quest", "rare", "elite", "caster" }
local TYPE_KEYS = { quest = "types.quest", rare = "types.rare", elite = "types.elite", caster = "types.caster" }
local TYPE_COLOR_KEYS = { quest = "types.questColor", rare = "types.rareColor", elite = "types.eliteColor", caster = "types.casterColor" }
local typeEnabled, typeInfo = {}, {}

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

local function StyleFont(text, size, outline)
	local flags = OUTLINE_FLAGS[outline] or "OUTLINE"
	local path = Settings.Get("font")
	if not Widgets.ApplyFont(text, path, size, flags) then
		Widgets.ApplyFont(text, (Tokens.Font("world")), size, flags)
		LogOnce("font:" .. path, "the font " .. path .. " did not load; plates use the world font")
	end
end

local function NewText(parent, justify)
	local text = Widgets.FontString(parent, "OVERLAY")
	text:SetJustifyH(justify)
	text:SetWordWrap(false)
	return text
end

local function PixelBorder(bar)
	return Widgets.Snap(bar, Scale.Pixel(BORDER_PIXELS) / Widgets.ScaleFactor(bar))
end

function ns.FlatBar(parent, opts)
	opts.border = false
	local bar = Widgets.StatusBar(parent, opts)
	local restyle = bar.Restyle
	bar.rim = { Tokens.Color("black") }
	bar.rimGapFill = Widgets.Crisp(bar:CreateTexture(nil, "BACKGROUND", nil, -1))
	bar.rimGap = 0
	function bar:SetRimGap(gap)
		gap = Widgets.Snap(self, gap)
		local px = gap > 0 and gap or opts.rimWidth and Widgets.Snap(self, opts.rimWidth) or PixelBorder(self)
		if self.rimGap == gap and self.rimPixel == px then
			return
		end
		self.rimGap, self.rimPixel, self.rimOutset = gap, px, gap + px
		self.rimGapFill:SetShown(gap > 0)
		self.rimGapFill:SetColorTexture(Widgets.MixTokens("black", 1, "gilt", 1, 0.1))
		self.rimGapFill:ClearAllPoints()
		self.rimGapFill:SetPoint("TOPLEFT", self, "TOPLEFT", -gap, gap)
		self.rimGapFill:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", gap, -gap)
		self.keyline:ClearAllPoints()
		self.keyline:SetPoint("TOPLEFT", self, "TOPLEFT", -gap - px, gap + px)
		self.keyline:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", gap + px, -gap - px)
	end
	function bar:SetRimColor(r, g, b, a)
		local c = self.rim
		c[1], c[2], c[3], c[4] = r, g, b, a or 1
		self.keyline:SetVertexColor(c[1], c[2], c[3], c[4])
	end
	local function WriteColor(color, r, g, b, a)
		if type(color.SetRGBA) == "function" then
			color:SetRGBA(r, g, b, a)
		else
			color.r, color.g, color.b, color.a = r, g, b, a
		end
		return color
	end
	function bar:RampColors()
		local colors = self.rampColors
		if colors or type(CreateColor) ~= "function" then
			return colors
		end
		local wr, wg, wb, wa = Tokens.Color("white")
		colors = {
			CreateColor(wr, wg, wb, wa),
			CreateColor(wr, wg, wb, wa),
			CreateColor(wr, wg, wb, wa),
		}
		self.rampColors = colors
		return colors
	end
	function bar:ApplyFillRamp()
		local source = self.fillSource
		if not source then
			return
		end
		local r, g, b = source[1], source[2], source[3]
		local topR, topG, topB, botR, botG, botB = Logic.Ramp(r, g, b)
		local texture = self:GetStatusBarTexture()
		local colors = self:RampColors()
		local canGradient = texture and colors and type(texture.SetGradient) == "function"
		if not topR or not canGradient then
			if canGradient and self.fillRamped then
				texture:SetGradient("VERTICAL", colors[1], colors[1])
			end
			self.fillRamped = false
			if not canGradient and topR then
				LogOnce("ramp", "Texture:SetGradient or CreateColor is missing; plates draw a flat fill")
			end
			self:SetBarColor(r, g, b)
			return
		end
		local wr, wg, wb, wa = Tokens.Color("white")
		self:SetBarColor(wr, wg, wb, wa)
		texture:SetGradient("VERTICAL", WriteColor(colors[2], botR, botG, botB, wa), WriteColor(colors[3], topR, topG, topB, wa))
		self.fillRamped = true
	end
	function bar:SetFillRamp(r, g, b)
		local source = self.fillSource
		if not source then
			source = {}
			self.fillSource = source
		end
		source[1], source[2], source[3] = r, g, b
		self:ApplyFillRamp()
	end
	function bar:Restyle()
		restyle(self)
		self.lit:Hide()
		self.shade:Hide()
		self.rimPixel = nil
		self:SetRimGap(self.rimGap)
		self:SetRimColor(unpack(self.rim))
		self:ApplyFillRamp()
	end
	bar:Restyle()
	return bar
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

local function TargetColor()
	if Settings.Get("target.colorSource") == "custom" then
		return Rgb(Settings.Get("target.color"))
	end
	return Theme.Accent()
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
	plate.threatGlow = Widgets.NineSlice(glowFrame, "shadow", "BACKGROUND", -1)
	for _, piece in ipairs(plate.threatGlow) do
		piece:SetBlendMode("ADD")
	end
	Widgets.ShowSlice(plate.threatGlow, false)

	plate.healthOpts = { width = Plate.DEFAULT_WIDTH, height = Plate.DEFAULT_HEIGHT, smooth = true, color = "plateHostile" }
	local health = ns.FlatBar(plate, plate.healthOpts)
	plate.health = health
	plate.healthText = NewText(health, "RIGHT")

	plate.name = NewText(plate, "CENTER")

	local badge = CreateFrame("Frame", nil, plate)
	badge:SetFrameLevel(health:GetFrameLevel() + 1)
	badge.chrome = Widgets.Chrome(badge, { shape = "panel", fill = "surface", chamfer = DISC_CHAMFER, shadow = false, grain = false })
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
	local root = Scale.Root():GetEffectiveScale()
	local base = self:GetParent()
	local canIgnore = type(self.SetIgnoreParentScale) == "function"
	if Settings.Get("shrinkDistant") then
		if canIgnore then
			self:SetIgnoreParentScale(false)
		end
		local outer = base:GetParent()
		local reference = Logic.ShrinkReference(outer and outer:GetEffectiveScale() or 1, UIParent:GetEffectiveScale())
		self:SetScale(Logic.PlateScale(root, reference))
		LogOnce("shrink", "plates follow their base plate's scale, the game's distance and target scaling")
	elseif canIgnore then
		self:SetIgnoreParentScale(true)
		self:SetScale(Logic.PlateScale(root, 1))
		LogOnce("hold", "plates ignore their base plate's scale and draw in root units")
	else
		self:SetScale(Logic.PlateScale(root, base:GetEffectiveScale()))
		LogOnce("hold", "SetIgnoreParentScale is missing; plates take their base plate's scale at each restyle")
	end
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

	local nameRole = Settings.Get("name.upper") and "names" or "heading"
	Widgets.StyleText(self.name, nameRole)
	Widgets.ApplyFont(self.name, (Tokens.Font(nameRole)), Settings.Get("name.size"), OUTLINE_FLAGS[Settings.Get("name.outline")])
	StyleFont(self.levelText, Settings.Get("level.size"), Settings.Get("level.outline"))
	StyleFont(self.healthText, Settings.Get("healthText.size"), Settings.Get("healthText.outline"))

	self.healthText:ClearAllPoints()
	self.healthText:SetPoint("RIGHT", health, "RIGHT", -Widgets.Snap(self, TEXT_INSET), 0)

	local badge = self.level
	local side = math.max(DISC_SIZE, h, Settings.Get("level.size") + BADGE_PAD)
	Widgets.Size(badge, side, side)
	badge:ClearAllPoints()
	badge:SetPoint("RIGHT", health, "LEFT", Widgets.Snap(self, DISC_OVERLAP), 0)
	badge.chrome:Restyle()
	self.levelText:ClearAllPoints()
	self.levelText:SetPoint("CENTER", badge, "CENTER")

	Widgets.Size(self.marker, MARKER_SIZE, MARKER_SIZE)
	self.marker:ClearAllPoints()
	if Settings.Get("level.show") then
		self.marker:SetPoint("BOTTOM", badge, "TOP", 0, Widgets.Snap(self, GAP))
	else
		self.marker:SetPoint("RIGHT", health, "LEFT", -Widgets.Snap(self, GAP), 0)
	end

	local raidSize = Settings.Get("markers.raidSize")
	Widgets.Size(self.raid, raidSize, raidSize)
	self.raid:ClearAllPoints()
	self.raid:SetPoint("LEFT", health, "RIGHT", Widgets.Snap(self, BADGE_GAP), 0)

	self.glowFrame:SetFrameLevel(math.max(0, health:GetFrameLevel() - 2))
	Widgets.LayoutSlice(self.threatGlow, health, GLOW_CORNER, GLOW_OUTSET)

	self.nameOnly = nil
	Each("Restyle", self)
	self:Refresh(true)
end

function Plate:LayoutName()
	local name, health = self.name, self.health
	name:ClearAllPoints()
	name:SetWidth(Widgets.Snap(name, ns.state.width + Plate.NAME_OVERHANG * 2))
	if self.nameOnly then
		name:SetJustifyH("CENTER")
		name:SetPoint("CENTER", self, "CENTER")
	else
		name:SetJustifyH("CENTER")
		name:SetPoint("BOTTOM", health, "TOP", 0, Widgets.Snap(self, GAP))
	end
end

function Plate:SetUnit(unit)
	self.unit = unit
	self.colorKey.r = nil
	self.caster = nil
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
	self:UpdateType()
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

local function ManaType()
	local types = Enum and Enum.PowerType
	return types and types.Mana or 0
end

local function QuestUnit(unit)
	local api = C_QuestLog
	if api and type(api.UnitIsRelatedToActiveQuest) == "function" then
		return api.UnitIsRelatedToActiveQuest(unit)
	end
	if type(UnitIsQuestBoss) == "function" then
		LogOnce("quest-api", "C_QuestLog.UnitIsRelatedToActiveQuest is missing; quest mobs come from UnitIsQuestBoss")
		return UnitIsQuestBoss(unit)
	end
	LogOnce("quest-api", "no quest unit API; no plate takes the quest colour")
	return false
end

function Plate:UpdateType()
	local sample = self.sample
	if sample then
		self.caster = sample.caster
		self.quest = sample.quest
		return
	end
	local unit = self.unit
	local caster = Logic.IsCaster((UnitValue(UnitPowerType, unit)), (UnitValue(UnitPowerMax, unit)), ManaType())
	if caster ~= nil then
		self.caster = caster
	end
	self.quest = IsTrue(QuestUnit(unit))
end

function Plate:RefreshType()
	if not self.unit and not self.sample then
		return
	end
	self:UpdateType()
	self:UpdateColor()
end

function Plate:TypeColor(isPlayer, tapped)
	if self.kind ~= "enemy" then
		return nil
	end
	for i = 1, #TYPES do
		local name = TYPES[i]
		typeEnabled[name] = Settings.Get(TYPE_KEYS[name])
	end
	typeInfo.isPlayer, typeInfo.tapped = isPlayer, tapped
	typeInfo.quest, typeInfo.caster = self.quest, self.caster
	typeInfo.classification = self:Is("classification", UnitClassification, self.unit)
	if IsSecret(typeInfo.classification) then
		typeInfo.classification = nil
	end
	local found = Logic.UnitType(typeEnabled, typeInfo)
	self.unitType = found
	return found and TYPE_COLOR_KEYS[found] or nil
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
		local typeKey = source ~= "tapped" and source ~= "class" and self:TypeColor(isPlayer, tapped)
		if typeKey then
			r, g, b = Rgb(Settings.Get(typeKey))
		elseif source == "tapped" then
			r, g, b = Tokens.Color("textDisabled")
		elseif source == "custom" then
			r, g, b = Rgb(Settings.Get(COLOR_KEYS[kind]))
		elseif source == "class" then
			local class = self.sample and self.sample.class or select(2, UnitValue(UnitClass, self.unit))
			r, g, b = Theme.ClassColorForWidget(class)
		else
			local reaction = self.sample and self.sample.reaction or UnitValue(UnitReaction, self.unit, "player")
			if self.kind == "enemy" and not IsSecret(reaction) and type(reaction) == "number" and reaction < 4 then
				r, g, b = Tokens.Color("plateHostile")
			else
				r, g, b = Theme.ReactionColor(reaction)
			end
		end
	end
	local last = self.colorKey
	if IsSecret(r) or IsSecret(g) or IsSecret(b) then
		last.r, last.g, last.b = nil, nil, nil
		self.health:SetFillRamp(r, g, b)
		self.level.chrome:SetEdgeRGBA(r, g, b, 1)
	elseif last.r ~= r or last.g ~= g or last.b ~= b then
		last.r, last.g, last.b = r, g, b
		self.health:SetFillRamp(r, g, b)
		self.level.chrome:SetEdgeRGBA(r, g, b, 1)
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
		Widgets.SetText(name, Settings.Get("name.upper") and K.Locale.Upper(value) or value)
	else
		name:SetText("")
	end
	self:UpdateNameColor(nil, true)
end

function Plate:UpdateNameColor(isTarget, force)
	if isTarget == nil then
		if self.sample then
			isTarget = self.sample.target
		else
			isTarget = ns.Plates.IsUnit(self, "target")
		end
	end
	isTarget = isTarget and Settings.Get("target.highlight") or false
	if not force and self.nameTarget == isTarget then
		return
	end
	self.nameTarget = isTarget
	local name = self.name
	if isTarget then
		name:SetTextColor(TargetColor())
		return
	end
	local isPlayer = IsTrue(self:Is("isPlayer", UnitIsPlayer, self.unit))
	local barHasClass = not self.nameOnly and Settings.Get(SOURCE_KEYS[self.kind]) == "class"
	if isPlayer and Settings.Get("name.classColor") and not barHasClass then
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
	if level == SKULL_LEVEL then
		self.levelText:SetTextColor(Tokens.Color("hostile"))
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

function Plate:UpdateHighlight()
	local state = ns.state
	local isTarget, isFocus
	if self.sample then
		isTarget, isFocus = self.sample.target, self.sample.focus
	else
		isTarget = ns.Plates.IsUnit(self, "target")
		isFocus = ns.Plates.IsUnit(self, "focus")
	end
	ns.Cast.Gate(self, isTarget)
	local bar = not self.nameOnly
	local health = self.health
	local framed = isTarget and Settings.Get("target.highlight") and bar or false
	if self.targetFramed ~= framed then
		self.targetFramed = framed
		health:SetRimGap(framed and Plate.FRAME_GAP or 0)
		ns.Cast.Place(self)
	end
	if framed then
		local r, g, b = TargetColor()
		health:SetRimColor(r, g, b, 1)
	else
		if isFocus and Settings.Get("focus.highlight") then
			local r, g, b = Rgb(Settings.Get("focus.color"))
			health:SetRimColor(r, g, b, 1)
		else
			health:SetRimColor(Tokens.Color("black"))
		end
	end
	self:UpdateNameColor(isTarget)
	local alpha = 1
	if not self.sample and state.hasTarget and not isTarget then
		alpha = Settings.Get("target.dimOthers")
	end
	self:SetAlpha(alpha)
end
