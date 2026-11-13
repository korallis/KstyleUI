-- Plate.lua: one KstyleUI plate built from the widget kit: a clean health bar, the name, the level diamond with its rank, target brackets, markers and the threat glow.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme, Scale, Motion = K.Widgets, K.Tokens, K.Theme, K.Scale, K.Motion
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

Plate.DEFAULT_WIDTH, Plate.DEFAULT_HEIGHT = 156.75, 11.875
Plate.NAME_OVERHANG = 44
Plate.FRAME_GAP = 2.375

local HALO_ALPHA = 0.45
local NAME_GAP = 8
Plate.NAME_GAP = NAME_GAP
local BADGE_GAP = Tokens.Size("gapSmall")
local TEXT_INSET = Tokens.Size("gapSmall")
local BRACKET_HEIGHT, BRACKET_ARM, BRACKET_GAP, BRACKET_STROKE = 21.375, 5.9375, 7.125, 2.375
Plate.BRACKET_HEIGHT = BRACKET_HEIGHT
local BRACKET_TRAVEL, BRACKET_TIME = 4.75, 0.12
Plate.BRACKET_REACH = BRACKET_GAP + BRACKET_ARM
local DIAMOND_SIDE = 21.375
local DIAMOND_FILL = { 0.110, 0.114, 0.110 }
local PLAIN_RIM_ALPHA = 0.8
function Plate.MarkerReach()
	return Settings.Get("target.highlight") and Plate.BRACKET_REACH or BADGE_GAP
end
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

local function Pixel(frame, n)
	return Scale.Pixel(n or 1) / Widgets.ScaleFactor(frame)
end

Plate.Pixel = Pixel

local SHARES = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local function OnPixel(raw, relShare, relSize, ownShare, ownSize)
	local target = relShare * relSize - ownShare * ownSize
	return math.floor(raw + target + 0.5) - target
end

function Plate.Place(region, point, relative, relativePoint, x, y, ownW, ownH, relW, relH)
	local px = Pixel(region)
	local own, rel = SHARES[point], SHARES[relativePoint]
	local dx = OnPixel((x or 0) / px, rel[1], (relW or 0) / px, own[1], (ownW or 0) / px)
	local dy = -OnPixel(-(y or 0) / px, 1 - rel[2], (relH or 0) / px, 1 - own[2], (ownH or 0) / px)
	region:SetPoint(point, relative, relativePoint, dx * px, dy * px)
end
local Place = Plate.Place

function ns.FlatBar(parent, opts)
	opts.border = false
	local bar = Widgets.StatusBar(parent, opts)
	local restyle = bar.Restyle
	bar.rim = { Tokens.Color("black") }
	bar.halo = Widgets.Crisp(bar:CreateTexture(nil, "BACKGROUND", nil, -2))
	function bar:PlaceRim()
		local px = Widgets.Border(self)
		if self.rimPixel == px then
			return
		end
		self.rimPixel, self.rimOutset = px, px * 2
		self.keyline:ClearAllPoints()
		self.keyline:SetPoint("TOPLEFT", self, "TOPLEFT", -px, px)
		self.keyline:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", px, -px)
		self.halo:SetColorTexture(Widgets.Rgba("black", HALO_ALPHA))
		self.halo:ClearAllPoints()
		self.halo:SetPoint("TOPLEFT", self, "TOPLEFT", -px * 2, px * 2)
		self.halo:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", px * 2, -px * 2)
	end
	function bar:SetRimColor(r, g, b, a)
		local c = self.rim
		c[1], c[2], c[3], c[4] = r, g, b, a or 1
		self.keyline:SetVertexColor(c[1], c[2], c[3], c[4])
	end
	function bar:Restyle()
		restyle(self)
		self.shade:Hide()
		self.rimPixel = nil
		self:PlaceRim()
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

	local health = Widgets.UnitBar(plate, { width = Plate.DEFAULT_WIDTH, height = Plate.DEFAULT_HEIGHT, color = "plateHostile" })
	plate.healthOpts = health.opts
	plate.health = health
	plate.healthText = NewText(health, "RIGHT")

	plate.name = NewText(plate, "CENTER")

	local diamond = CreateFrame("Frame", nil, plate)
	diamond:SetFrameLevel(health:GetFrameLevel() + 2)
	diamond.layers = {}
	for i, layer in ipairs({ "outer", "rim", "inner", "fill" }) do
		local texture = diamond:CreateTexture(nil, "ARTWORK", nil, i)
		texture:SetTexture((Tokens.Texture("diamond")))
		diamond.layers[i] = texture
		diamond[layer] = texture
	end
	diamond.outer:SetVertexColor(Tokens.Color("black"))
	diamond.inner:SetVertexColor(Tokens.Color("black"))
	plate.level = diamond
	plate.levelText = NewText(diamond, "CENTER")


	local brackets = CreateFrame("Frame", nil, plate)
	brackets:SetFrameLevel(diamond:GetFrameLevel() + 1)
	brackets:Hide()
	brackets.sides = {}
	for i, side in ipairs({ "left", "right" }) do
		local frame = CreateFrame("Frame", nil, brackets)
		frame.side = side
		frame.stroke = frame:CreateTexture(nil, "OVERLAY")
		frame.top = frame:CreateTexture(nil, "OVERLAY")
		frame.bottom = frame:CreateTexture(nil, "OVERLAY")
		for _, texture in ipairs({ frame.stroke, frame.top, frame.bottom }) do
			Widgets.Crisp(texture)
			texture:SetColorTexture(Tokens.Color("white"))
		end
		local group = frame:CreateAnimationGroup()
		frame.open = group:CreateAnimation("Translation")
		frame.open:SetDuration(0)
		frame.open:SetOrder(1)
		frame.close = group:CreateAnimation("Translation")
		frame.close:SetDuration(BRACKET_TIME)
		frame.close:SetOrder(2)
		frame.close:SetSmoothing("OUT")
		frame.group = group
		brackets.sides[i] = frame
	end
	plate.brackets = brackets

	local raid = plate:CreateTexture(nil, "OVERLAY")
	raid:SetTexture(RAID_ICONS)
	raid:Hide()
	plate.raid = raid

	plate.colorKey = {}
	Each("Build", plate)
	Widgets.RecordAll(plate, health, plate.name, plate.healthText, diamond, plate.levelText, raid, brackets,
		plate.cast, plate.castBar, plate.castIcon, plate.castName, plate.castTime)
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
		Widgets.Point(self, "CENTER", self:GetParent(), "CENTER")
	else
		self:PlaceOnBase(w, h)
	end

	local health = self.health
	health:ClearAllPoints()
	health:SetPoint("TOPLEFT", self, "TOPLEFT")
	local barW, barH = Widgets.Snap(self, w), Widgets.Snap(self, h)
	self.barW, self.barH = barW, barH
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
	Place(self.healthText, "RIGHT", health, "RIGHT", -TEXT_INSET, 0, nil, nil, barW, barH)

	self:LayoutDiamond()
	self:LayoutBrackets()

	local raidSize = Settings.Get("markers.raidSize")
	Widgets.Size(self.raid, raidSize, raidSize)
	self.raid:ClearAllPoints()
	local raidSide = Widgets.Snap(self, raidSize)
	Place(self.raid, "LEFT", health, "RIGHT", Plate.MarkerReach(), 0, raidSide, raidSide, barW, barH)

	self.glowFrame:SetFrameLevel(math.max(0, health.under:GetFrameLevel() - 1))
	Widgets.LayoutSlice(self.threatGlow, health, GLOW_CORNER, GLOW_OUTSET)

	self.nameOnly = nil
	self.bracketsShown = nil
	Each("Restyle", self)
	self:Refresh(true)
end

local function Diagonal(frame, side)
	return Widgets.Snap(frame, side * math.sqrt(2))
end

function Plate.DiamondSize(plate)
	return Diagonal(plate, DIAMOND_SIDE + Pixel(plate) * 2)
end

function Plate.DiamondReach(plate)
	return Widgets.Snap(plate, Plate.MarkerReach()) + Pixel(plate) + Plate.DiamondSize(plate)
end

function Plate:LayoutDiamond()
	local diamond, health = self.level, self.health
	local px = Pixel(self)
	local outer = Plate.DiamondSize(self)
	Widgets.Size(diamond, outer, outer)
	diamond:ClearAllPoints()
	Place(diamond, "RIGHT", health, "LEFT", outer - Plate.DiamondReach(self), 0, outer, outer, self.barW, self.barH)
	diamond.size = outer
	diamond.outer.side = outer
	diamond.rim.side = Diagonal(self, DIAMOND_SIDE)
	diamond.rimPixel = px
	diamond.fill:SetVertexColor(DIAMOND_FILL[1], DIAMOND_FILL[2], DIAMOND_FILL[3], 1)
	self.rimWeight = nil
	self:SetRimWeight(1)
	self.levelText:ClearAllPoints()
	Place(self.levelText, "CENTER", diamond, "CENTER", 0, 0, nil, nil, outer, outer)
end

function Plate:SetRimWeight(weight)
	if self.rimWeight == weight then
		return
	end
	self.rimWeight = weight
	local diamond = self.level
	local px = diamond.rimPixel
	local inner = DIAMOND_SIDE - px * 2 * weight
	diamond.inner.side = Diagonal(self, inner)
	diamond.fill.side = Diagonal(self, inner - px * 2)
	for _, layer in ipairs(diamond.layers) do
		local side = layer.side
		layer:SetSize(side, side)
		layer:ClearAllPoints()
		Place(layer, "CENTER", diamond, "CENTER", 0, 0, side, side, diamond.size, diamond.size)
	end
end

function Plate:LayoutBrackets()
	local brackets, health = self.brackets, self.health
	local px = Pixel(self)
	local stroke = math.max(px, Widgets.Snap(self, BRACKET_STROKE))
	local arm = Widgets.Snap(self, BRACKET_ARM)
	local height = Widgets.Snap(self, BRACKET_HEIGHT)
	local reach = Widgets.Snap(self, Plate.BRACKET_REACH)
	local travel = Widgets.Snap(self, BRACKET_TRAVEL)
	brackets:ClearAllPoints()
	brackets:SetAllPoints(health)
	for _, frame in ipairs(brackets.sides) do
		local left = frame.side == "left"
		local edge = left and "LEFT" or "RIGHT"
		local sign = left and -1 or 1
		frame:SetSize(arm, height)
		frame:ClearAllPoints()
		Place(frame, left and "RIGHT" or "LEFT", health, edge, sign * (reach - arm), 0, arm, height, self.barW, self.barH)
		frame.stroke:ClearAllPoints()
		frame.stroke:SetPoint("TOP" .. edge, frame, "TOP" .. edge)
		frame.stroke:SetPoint("BOTTOM" .. edge, frame, "BOTTOM" .. edge)
		frame.stroke:SetWidth(stroke)
		frame.top:ClearAllPoints()
		frame.top:SetPoint("TOPLEFT", frame, "TOPLEFT")
		frame.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
		frame.top:SetHeight(stroke)
		frame.bottom:ClearAllPoints()
		frame.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
		frame.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
		frame.bottom:SetHeight(stroke)
		frame.open:SetOffset(sign * travel, 0)
		frame.close:SetOffset(-sign * travel, 0)
	end
	self:PaintBrackets()
end

function Plate:PaintBrackets()
	local r, g, b = TargetColor()
	for _, frame in ipairs(self.brackets.sides) do
		frame.stroke:SetVertexColor(r, g, b, 1)
		frame.top:SetVertexColor(r, g, b, 1)
		frame.bottom:SetVertexColor(r, g, b, 1)
	end
end

function Plate:ShowBrackets(shown)
	if self.bracketsShown == shown then
		return
	end
	local first = self.bracketsShown == nil
	self.bracketsShown = shown
	local brackets = self.brackets
	brackets:SetShown(shown)
	for _, frame in ipairs(brackets.sides) do
		frame.group:Stop()
		if shown and not first and not self.sample and Motion.Level() == "full" then
			frame.group:Play()
		end
	end
end

local function Plain(value)
	return not IsSecret(value) and type(value) == "number" and value > 0 and value or nil
end

function Plate:PlaceOnBase(w, h)
	local base = self:GetParent()
	self:ClearAllPoints()
	local x, y = 0, Widgets.Snap(self, Settings.Get("offsetY") + BottomRoom(self))
	local bw, bh = ns.Stacking.Size()
	local k = Plain(base:GetEffectiveScale()) and Plain(self:GetEffectiveScale()) and base:GetEffectiveScale() / self:GetEffectiveScale()
	if bw and bh and k then
		local px = Pixel(self)
		local across = (bw * k - Widgets.Snap(self, w)) / px / 2
		x = (math.floor(across + 0.5) - across) * px
		local down = (bh * k - y - Widgets.Snap(self, h)) / px
		y = y + (down - math.floor(down + 0.5)) * px
	end
	self:SetPoint("BOTTOM", base, "BOTTOM", x, y)
end

function Plate:LayoutName()
	local name, health = self.name, self.health
	name:ClearAllPoints()
	name:SetWidth(0)
	if self.nameOnly then
		name:SetJustifyH("CENTER")
		Place(name, "CENTER", self, "CENTER", 0, 0, nil, nil, self.barW, self.barH)
	else
		name:SetJustifyH("CENTER")
		Place(name, "BOTTOM", health, "TOP", 0, NAME_GAP, nil, nil, self.barW, self.barH)
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
		health:SetHealth(sample.health, true)
	else
		local unit = self.unit
		health:SetBarRange(0, UnitHealthMax(unit))
		health:SetHealth(UnitHealth(unit), immediate)
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
	self:UpdateNameColor(true)
end

function Plate:UpdateNameColor(force)
	if not force then
		return
	end
	local name = self.name
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
	local diamond = self.level
	local level = self:Is("level", UnitEffectiveLevel or UnitLevel, self.unit)
	local text = Settings.Get("level.show") and Logic.LevelText(level)
	local mark = Settings.Get("markers.classification") and Logic.MarkerColor(self:Is("classification", UnitClassification, self.unit))
	local show = not self.nameOnly and (text or mark) and true or false
	diamond:SetShown(show)
	if not show then
		return
	end
	self.levelText:SetText(text or "")
	if not IsSecret(level) and level == SKULL_LEVEL then
		self.levelText:SetTextColor(Tokens.Color("hostile"))
	else
		self.levelText:SetTextColor(Tokens.Color("giltLit"))
	end
	if mark then
		diamond.rim:SetVertexColor(Tokens.Color(mark))
		self:SetRimWeight(2)
	else
		diamond.rim:SetVertexColor(Widgets.Rgba("gilt", PLAIN_RIM_ALPHA))
		self:SetRimWeight(1)
	end
end

Plate.UpdateMarker = Plate.UpdateLevel

function Plate:UpdateRaid()
	local raid = self.raid
	local index
	if Settings.Get("markers.raid") then
		index = self:Is("raid", GetRaidTargetIndex, self.unit)
	end
	if type(index) == "nil" then
		raid:Hide()
	else
		raid:SetSpriteSheetCell(index, RAID_ROWS, RAID_COLUMNS)
		raid:Show()
	end
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
	local framed = isTarget and Settings.Get("target.highlight") and not self.nameOnly or false
	self:ShowBrackets(framed)
	local health = self.health
	if isFocus and Settings.Get("focus.highlight") and not framed then
		local r, g, b = Rgb(Settings.Get("focus.color"))
		health.under.edgeHard:SetColorTexture(r, g, b, 1)
	else
		health.under.edgeHard:SetColorTexture(Tokens.Color("black"))
	end
	local alpha = 1
	if not self.sample and state.hasTarget and not isTarget then
		alpha = Settings.Get("target.dimOthers")
	end
	self:SetAlpha(alpha)
end
