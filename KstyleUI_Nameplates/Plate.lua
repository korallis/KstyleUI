-- Plate.lua: one KstyleUI plate built from the widget kit: a clean health bar, the name, the level diamond with its rank, target brackets, markers and the threat glow.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme, Scale, Motion, L = K.Widgets, K.Tokens, K.Theme, K.Scale, K.Motion, K.L
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
			room = room + fn(plate, true)
		end
	end
	return room
end

Plate.DEFAULT_WIDTH, Plate.DEFAULT_HEIGHT = 156.75, Tokens.Size("barHeight")
Plate.NAME_OVERHANG = 44
Plate.FRAME_GAP = 2.375

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
local TYPES = { "quest", "boss", "rare", "miniBoss", "elite", "caster", "neutral", "minor", "normal" }
local TYPE_KEYS, TYPE_COLOR_KEYS = {}, {}
local TYPE_VISION = { boss = 2, normal = 2, neutral = 3 }
for _, name in ipairs(TYPES) do
	TYPE_KEYS[name], TYPE_COLOR_KEYS[name] = "types." .. name, "types." .. name .. "Color"
end
local PVP_ATLAS = { Horde = "UI-HUD-UnitFrame-SmallCircle-Horde", Alliance = "UI-HUD-UnitFrame-SmallCircle-Alliance" }
local QUEST_ICONS, QUEST_ICON = { monster = "crosshair_attack_48", item = "crosshair_lootall_48" }, "crosshair_quest_48"
local objectives
local INSIDE_X = { LEFT = 1, CENTER = 0, RIGHT = -1 }
local typeEnabled, typeInfo = {}, {}
local TEXT_ELEMENTS = { "name", "healthText", "extra1", "extra2" }
local TAG_EVENTS = { UNIT_LEVEL = "Level", UNIT_POWER_UPDATE = "Power", UNIT_MAXPOWER = "Power",
	UNIT_ABSORB_AMOUNT_CHANGED = "Prediction", UNIT_TARGET = "Target" }
local WHO_FORMAT = { player = "friendly.playerFormat", npc = "friendly.npcFormat" }
local WHO_COLOR = { player = { "friendly.nameMode", "friendly.nameColor" }, npc = { "friendly.npcNameMode", "friendly.npcColor" } }
local WHO_SIZE = { npc = "friendly.npcSize", pet = "friendly.petSize" }
local SUB_GAP = 1
local SUB_COLOR = { player = { "friendly.guildMatch", "friendly.guildColor" }, pet = { "friendly.ownerMatch", "friendly.ownerColor" },
	npc = { "friendly.npcTitleMatch", "friendly.npcTitleColor" } }
local ABSORB = { after = { "LEFT", true, "RIGHT", false }, back = { "RIGHT", true, "RIGHT", true },
	far = { "RIGHT", false, "RIGHT", true }, near = { "LEFT", false, "LEFT", false } }
local FLIP, UPRIGHT = { LEFT = "RIGHT", RIGHT = "LEFT" }, { LEFT = "BOTTOM", RIGHT = "TOP" }
local EXECUTE_LOW = 0.35
local executeCurves = {}

local function OnTagEvent(plate, event)
	if event == "UNIT_ABSORB_AMOUNT_CHANGED" and plate.absorb then plate:UpdateAbsorb() end
	plate:UpdateTags(TAG_EVENTS[event])
end

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

local function StyleFont(text, size, outline, role, ownFont)
	local flags = OUTLINE_FLAGS[outline] or "OUTLINE"
	local path = ownFont or Settings.Get("font", role)
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

local function ThreatColor(state)
	return K.ColorVision.Color(state == "danger" and 2 or state == "warning" and 3 or 1, Rgb(Settings.Get(THREAT_KEYS[state])))
end

local BAR_THREAT = { health = true, healthEdge = true }
local KEEPS = { boss = { "threat.overBoss", "threat.tankOverBoss" }, miniBoss = { "threat.overMiniBoss", "threat.tankOverOthers" },
	caster = { "threat.overCaster", "threat.tankOverOthers" } }

local function ThreatEdge()
	local display = Settings.Get("threat.display")
	return display == "healthEdge" or display == "glow" and Settings.Get("threat.keyline")
end

local function ThreatName()
	return Settings.Get("threat.name") or Settings.Get("threat.display") == "name"
end

local function Keeps(tank)
	local slot = tank and 2 or 1
	for _, keys in pairs(KEEPS) do
		if not Settings.Get(keys[slot]) then return slot end
	end
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
	if not sample then
		plate.stackBounds = CreateFrame("Frame", nil, parent)
	end

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
	plate.threatShape = plate:CreateTexture(nil, "OVERLAY")
	plate.threatShape:Hide()
	function health:SetRimColor(r, g, b, a)
		local edge = self.under.edgeHard
		if r then edge:SetColorTexture(r, g, b, a or 1) else edge:SetColorTexture(Tokens.Color("black")) end
		if plate.healthBare then edge:SetShown(r ~= nil) end
	end
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
	local boost = self.boost or 1
	if self.sample then
		self:SetScale(self == ns.Preview.samplePlate and 1 or boost)
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
		self:SetScale(Logic.PlateScale(root, reference) * boost)
		LogOnce("shrink", "plates follow their base plate's scale, the game's distance and target scaling")
	elseif canIgnore then
		self:SetIgnoreParentScale(true)
		self:SetScale(Logic.PlateScale(root, 1) * boost)
		LogOnce("hold", "plates ignore their base plate's scale and draw in root units")
	else
		self:SetScale(Logic.PlateScale(root, base:GetEffectiveScale()) * boost)
		LogOnce("hold", "SetIgnoreParentScale is missing; plates take their base plate's scale at each restyle")
	end
end

local function Host(plate)
	if not plate.extraHost then
		plate.extraHost = CreateFrame("Frame", nil, plate)
		plate.extraHost:SetAllPoints(plate.health)
	end
	plate.extraHost:SetFrameLevel(plate.health.fillClip:GetFrameLevel() + 1)
	return plate.extraHost
end

local function ExtraTexts(plate)
	for i = 1, 2 do
		local key = "extra" .. i
		local cfg = Settings.Get(key)
		if type(cfg.textFormat) == "string" and cfg.textFormat ~= "" then
			Host(plate)
		end
		plate[key] = Widgets.PlaceText(plate[key], cfg, plate.extraHost, plate.health, plate.barW)
	end
end

local letterCfg = { textFormat = "", font = "", outline = "OUTLINE" }
local distanceCfg = { textFormat = "", font = "", outline = "OUTLINE", position = "CENTER" }
local OVERLAY_KEYS = { hashLine = "target.hashLine", threatText = "threat.percent", nameRaid = "markers.nameRaid", pvpBadge = "markers.pvp" }

local function Overlays(plate)
	local health, barW, barH = plate.health, plate.barW, plate.barH
	local letter = Settings.Get("focus.letter")
	if letter ~= "" or plate.focusLetter then
		letterCfg.textFormat, letterCfg.position = letter ~= "" and "F" or "", letter
		letterCfg.size, letterCfg.x, letterCfg.y = Settings.Get("focus.letterSize"), Settings.Get("focus.letterX"), Settings.Get("focus.letterY")
		plate.focusLetter = Widgets.PlaceText(plate.focusLetter, letterCfg, letter ~= "" and Host(plate) or plate.extraHost, health, barW)
		if letter ~= "" then plate.focusLetter:SetText(L["F"]) end
	end
	local distance = Settings.Get("target.distance")
	if distance or plate.distanceText then
		distanceCfg.textFormat = distance and "-" or ""
		distanceCfg.size, distanceCfg.x, distanceCfg.y = Settings.Get("target.distanceSize"), Settings.Get("target.distanceX"), Settings.Get("target.distanceY")
		plate.distanceText = Widgets.PlaceText(plate.distanceText, distanceCfg, distance and Host(plate) or plate.extraHost, health, barW)
		plate.distanceValue = nil
		if distance and plate.sample then plate.distanceText:SetText("8-20") end
	end
	if Settings.Get("target.hashLine") then
		local line = plate.hashLine or Host(plate):CreateTexture(nil, "OVERLAY")
		plate.hashLine = line
		line:SetColorTexture(Tokens.Color("textEmphasis"))
		local share = Settings.Get("target.hashPercent") / 100
		if Settings.Get("health.reverse") then share = 1 - share end
		line:ClearAllPoints()
		if health.vertical then
			Widgets.Size(line, barW, Pixel(plate))
			line:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT", 0, Widgets.Snap(plate, barH * share))
		else
			Widgets.Size(line, Pixel(plate), barH)
			line:SetPoint("TOPLEFT", health, "TOPLEFT", Widgets.Snap(plate, barW * share), 0)
		end
	end
	if Settings.Get("threat.percent") then
		local text = plate.threatText or NewText(Host(plate), "CENTER")
		plate.threatText, text.tint = text, nil
		StyleFont(text, Settings.Get("healthText.size"), Settings.Get("healthText.outline"), "number",
			K.Theme.FollowsKit(Settings.Get("healthText.font")) and Settings.Get("font", "number") or Settings.Get("healthText.font"))
		local place = Settings.Get("threat.percentPlace")
		text:ClearAllPoints()
		text:SetJustifyH(place)
		if place == "RIGHT" and plate.healthTextEnabled then
			Widgets.Point(text, "RIGHT", plate.healthText, "LEFT", -TEXT_INSET, 0)
		else
			Place(text, place, health, place, INSIDE_X[place] * TEXT_INSET, 0, nil, nil, barW, barH)
		end
	end
	if Settings.Get("markers.nameRaid") then
		local icon = plate.nameRaid or plate:CreateTexture(nil, "OVERLAY")
		plate.nameRaid = icon
		icon:SetTexture(RAID_ICONS)
		local size = Settings.Get("markers.nameRaidSize")
		Widgets.Size(icon, size, size)
		icon:ClearAllPoints()
		Widgets.Point(icon, "RIGHT", plate.name, "LEFT", -BADGE_GAP, 0)
	end
	if Settings.Get("markers.pvp") then
		local badge = plate.pvpBadge or plate:CreateTexture(nil, "OVERLAY")
		plate.pvpBadge, badge.atlas = badge, nil
		local size = Settings.Get("name.size")
		Widgets.Size(badge, size, size)
		badge:ClearAllPoints()
		Widgets.Point(badge, "LEFT", plate.name, "RIGHT", BADGE_GAP, 0)
	end
	if Settings.Get("target.glow") then
		local glow = plate.targetGlow
		if not glow then
			glow = Widgets.NineSlice(plate.glowFrame, "shadow", "BACKGROUND", -2)
			for _, piece in ipairs(glow) do piece:SetBlendMode("ADD") end
			plate.targetGlow = glow
		end
		Widgets.LayoutSlice(glow, health, GLOW_CORNER, GLOW_OUTSET)
		local r, g, b = TargetColor()
		Widgets.ColorSlice(glow, r, g, b, Settings.Get("target.glowAlpha"))
	end
	if plate.targetGlow and not Settings.Get("target.glow") and plate.glowShown ~= false then
		Widgets.ShowSlice(plate.targetGlow, false)
		plate.glowShown = false
	end
	if Settings.Get("target.fill") or Settings.Get("focus.fill") or Settings.Get("target.hover") then
		if not plate.targetFill then
			local fill = Host(plate):CreateTexture(nil, "ARTWORK")
			fill:SetAllPoints(health)
			fill:SetBlendMode("ADD")
			fill:SetColorTexture(Tokens.Color("white"))
			fill:Hide()
			plate.targetFill = fill
		end
		plate.fillWhich = false
	elseif plate.targetFill then
		plate:SetFill(nil)
	end
	for key, setting in pairs(OVERLAY_KEYS) do
		if plate[key] and not Settings.Get(setting) then plate[key]:Hide() end
	end
	if plate.questText then plate:LayoutQuest() end
end

function Plate:SetNameAlpha(alpha)
	self.name:SetAlpha(alpha)
	Widgets.HaloAlpha(self.name, alpha)
	if self.subtitle then self.subtitle:SetAlpha(alpha) end
	if self.nameRaid then self.nameRaid:SetAlpha(alpha) end
	if self.pvpBadge then self.pvpBadge:SetAlpha(alpha) end
	if self.questText then self.questText:SetAlpha(alpha); self.questIcon:SetAlpha(alpha) end
end

function Plate:Restyle()
	if self.textOptions then self.healthText:SetTextColor(Tokens.Color("white")) end
	self.nameFormat, self.healthFormat = Settings.Get("name.textFormat"), Settings.Get("healthText.textFormat")
	self.nameEnabled, self.healthTextEnabled = Settings.Get("name.show"), Settings.Get("healthText.show")
	self.statusTags = Settings.Get("name.afk") or Settings.Get("name.dnd")
	local formats = Settings.Get("friendly.playerFormat") ~= "" or Settings.Get("friendly.npcFormat") ~= ""
	self.textOptions = self.nameFormat ~= "" or self.healthFormat ~= "" or formats
		or Settings.Get("name.colorMode") ~= "" or Settings.Get("healthText.colorMode") ~= ""
	self.subtitled = Settings.Get("friendly.guild") ~= "" or Settings.Get("friendly.owner") or Settings.Get("friendly.npcTitle")
	self.friendlyNames = formats or self.subtitled or Settings.Get("friendly.title") or Settings.Get("friendly.nameMode") ~= ""
		or Settings.Get("friendly.npcNameMode") ~= "" or Settings.Get("friendly.npcSize") ~= 0 or Settings.Get("friendly.petSize") ~= 0
	self.who, self.whoSize = nil, nil
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
	local bare = not Settings.Get("health.border")
	if bare or self.healthBare then
		self.healthBare = bare
		if bare then health.under.edgeSoft:Hide() end
		health.under.edgeHard:SetShown(not bare)
	end

	local nameRole = Settings.Get("name.upper") and "names" or "heading"
	Widgets.StyleText(self.name, nameRole)
	StyleFont(self.name, Settings.Get("name.size"), Settings.Get("name.outline"), nameRole,
		K.Theme.FollowsKit(Settings.Get("name.font")) and (Tokens.Font(nameRole)) or Settings.Get("name.font"))
	Widgets.Halo(self.name, self.nameEnabled)
	StyleFont(self.levelText, Settings.Get("level.size"), Settings.Get("level.outline"), "number",
		K.Theme.FollowsKit(Settings.Get("level.font")) and Settings.Get("font", "number") or Settings.Get("level.font"))
	StyleFont(self.healthText, Settings.Get("healthText.size"), Settings.Get("healthText.outline"), "number",
		K.Theme.FollowsKit(Settings.Get("healthText.font")) and Settings.Get("font", "number") or Settings.Get("healthText.font"))

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

	ExtraTexts(self)
	Overlays(self)
	self:LayoutAbsorb()
	self:LayoutExecute()
	self:RegisterTagEvents()
	self.nameOnly = nil
	self.bracketsShown = nil
	self.resourceStale = true
	Each("Restyle", self)
	self:Refresh(true)
end

local function Diagonal(frame, side)
	return Widgets.Snap(frame, side * math.sqrt(2))
end

local function Side()
	return DIAMOND_SIDE * Settings.Get("level.diamond")
end

function Plate.DiamondSize(plate)
	return Diagonal(plate, Side() + Pixel(plate) * 2)
end

function Plate.DiamondReach(plate)
	return Widgets.Snap(plate, Plate.MarkerReach() + (Widgets.Medallions() and 0 or Tokens.Size("gapTiny"))) + Pixel(plate) + Plate.DiamondSize(plate)
end

function Plate:LayoutDiamond()
	local diamond, health = self.level, self.health
	local px = Pixel(self)
	local outer = Plate.DiamondSize(self)
	Widgets.Size(diamond, outer, outer)
	diamond:ClearAllPoints()
	Place(diamond, "RIGHT", health, "LEFT", outer - Plate.DiamondReach(self) + Settings.Get("level.x"), Settings.Get("level.y"), outer, outer, self.barW, self.barH)
	diamond.size = outer
	diamond.outer.side = outer
	diamond.rim.side = Diagonal(self, Side())
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
	local inner = Side() - px * 2 * weight
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
	local bw, bh = ns.Stacking.Size()
	local k = Plain(base:GetEffectiveScale()) and Plain(self:GetEffectiveScale()) and base:GetEffectiveScale() / self:GetEffectiveScale()
	local room = BottomRoom(self)
	local rise = k and ns.Stacking.BarRise()
	if rise then
		room = math.max(room, rise * k)
	end
	local x, y = 0, Widgets.Snap(self, Settings.Get("offsetY") + room)
	if bw and bh and k then
		local px = Pixel(self)
		local across = (bw * k - Widgets.Snap(self, w)) / px / 2
		x = (math.floor(across + 0.5) - across) * px
		local down = (bh * k - y - Widgets.Snap(self, h)) / px
		y = y + (down - math.floor(down + 0.5)) * px
	end
	self:SetPoint("BOTTOM", base, "BOTTOM", x, y)
	self.rise = y
	ns.Stacking.Bound(self, y)
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
		Place(name, "BOTTOM", health, "TOP", 0, NAME_GAP + (self.subtitleRoom or 0), nil, nil, self.barW, self.barH)
	end
	local sub = self.subtitle
	if sub then
		sub:ClearAllPoints()
		if self.nameOnly then
			Place(sub, "TOP", name, "BOTTOM", 0, -SUB_GAP)
		else
			Place(sub, "BOTTOM", health, "TOP", 0, NAME_GAP, nil, nil, self.barW, self.barH)
		end
	end
end

function Plate:SetUnit(unit)
	self.unit = unit
	self:RegisterTagEvents()
	self.colorKey.r = nil
	self.caster = nil
	self:Show()
	self:Refresh(true)
end

function Plate:ClearUnit()
	self.unit = nil
	self:UnregisterAllEvents()
	self.threatState = nil
	if self.alphaTween then Motion.Stop(self.alphaTween); self.alphaTween = nil end
	self.alphaGoal, self.hovered, self.outOfRange, self.fillWhich = nil, nil, nil, false
	if self.executePulse then self.executePulse:Stop(); self.executeShown = nil end
	if self.questText then self.questText.count, self.questIcon.atlas = nil, nil; self.questText:Hide() end
	self:SetAlpha(1)
	Each("Clear", self)
	self:Hide()
end

function Plate:Refresh(immediate)
	if not self.unit and not self.sample then
		return
	end
	self:UpdateType()
	self:UpdateStyle()
	self:UpdateHealth(immediate, true)
	self:UpdateName(true)
	self:UpdateLevel()
	self:UpdateRaid()
	self:UpdatePvp()
	self:UpdateQuest()
	self:UpdateThreat()
	self:UpdateHighlight()
	Each("Refresh", self, immediate)
	self:UpdateTags()
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
	self:UpdatePvp()
	self:UpdateThreat()
	self:UpdateTags()
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
	local nameOnly = IsTrue(self:Is("gameObject", UnitIsGameObject, self.unit)) or (self.kind == "friendly" and Settings.Get("friendly.nameOnly"))
	if nameOnly ~= self.nameOnly then
		self.nameOnly = nameOnly
		self:LayoutName()
		if self.rise then
			ns.Stacking.Bound(self, self.rise)
		end
	end
	self.health:SetShown(not nameOnly)
	local who
	if self.kind == "friendly" and self.friendlyNames then
		who = IsTrue(self:Is("isPlayer", UnitIsPlayer, self.unit)) and "player" or IsTrue(self:Is("pet", UnitPlayerControlled, self.unit)) and "pet" or "npc"
	end
	if who ~= self.who then
		self.who = who
		local key = WHO_SIZE[who]
		local size = key and Settings.Get(key) or 0
		size = size ~= 0 and size or nil
		if size ~= self.whoSize then
			self.whoSize = size
			local path, _, flags = self.name:GetFont()
			Widgets.ApplyFont(self.name, path, size or Settings.Get("name.size"), flags)
			self:Reflow()
		end
		self:RegisterTagEvents()
	end
	self:UpdateColor()
end

function Plate:NameFormat()
	local key = self.who and WHO_FORMAT[self.who]
	if not key then return self.nameFormat end
	local own = Settings.Get(key)
	local format = own ~= "" and own or self.nameFormat
	return self:Titled() and format:gsub("%[name%]", "[title]") or format
end

function Plate:Titled()
	return self.who == "player" and Settings.Get("friendly.title") and (self.sample ~= nil or type(UnitPVPName) == "function")
end

function Plate:WhoColor()
	local keys = self.who and WHO_COLOR[self.who]
	local mode = keys and Settings.Get(keys[1])
	if mode and mode ~= "" then return mode, keys[2] end
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
	typeInfo.quest, typeInfo.caster = self.quest and not Plate.MarkersHidden(), self.caster
	typeInfo.classification = self:Is("classification", UnitClassification, self.unit)
	if IsSecret(typeInfo.classification) then
		typeInfo.classification = nil
	end
	if typeEnabled.boss or typeEnabled.miniBoss then
		typeInfo.level = self:Is("level", UnitEffectiveLevel or UnitLevel, self.unit)
		typeInfo.playerLevel = typeEnabled.miniBoss and UnitValue(UnitEffectiveLevel or UnitLevel, "player")
	end
	if typeEnabled.neutral then
		typeInfo.reaction = self:Is("reaction", UnitReaction, self.unit, "player")
	end
	local found = Logic.UnitType(typeEnabled, typeInfo)
	self.unitType = found
	return found and TYPE_COLOR_KEYS[found] or nil
end

function Plate:UpdateColor()
	local r, g, b
	local state = self.threatState
	local kind = self.kind
	local threat = state and BAR_THREAT[Settings.Get("threat.display")]
	local wins = threat and Settings.Get("threat.overTypes")
	local keeps = wins and kind == "enemy" and Keeps(ns.state.isTank)
	local casting, source, typeKey
	if not wins or keeps then
		casting = not wins and kind == "enemy" and Settings.Get("types.casting") and (self.sample and self.sample.cast or self.unit and (type((UnitCastingInfo(self.unit))) ~= "nil" or type((UnitChannelInfo(self.unit))) ~= "nil"))
		if not casting then
			local tapped = kind == "enemy" and IsTrue(self:Is("tapped", UnitIsTapDenied, self.unit))
			local isPlayer = IsTrue(self:Is("isPlayer", UnitIsPlayer, self.unit))
			source = Logic.ColorKind(Settings.Get(SOURCE_KEYS[kind]), isPlayer and not (kind == "enemy" and Settings.Get("enemy.playersUseEnemy")), tapped)
			typeKey = source ~= "tapped" and source ~= "class" and self:TypeColor(isPlayer, tapped)
			local kept = keeps and KEEPS[self.unitType]
			if keeps and not (typeKey and kept and not Settings.Get(kept[keeps])) then typeKey = nil end
		end
	end
	if threat and not (casting or typeKey) then
		r, g, b = ThreatColor(state)
	elseif casting then
		r, g, b = Rgb(Settings.Get("types.castingColor"))
	elseif typeKey then
		r, g, b = Rgb(Settings.Get(typeKey))
		if TYPE_VISION[self.unitType] then r, g, b = K.ColorVision.Color(TYPE_VISION[self.unitType], r, g, b) end
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
			r, g, b = K.ColorVision.Color(2, Tokens.Color("plateHostile"))
		else
			r, g, b = K.ColorVision.ReactionColor(reaction)
		end
	end
	local last = self.colorKey
	if IsSecret(r) or IsSecret(g) or IsSecret(b) then
		last.r, last.g, last.b = nil, nil, nil
		self.health:SetBarColor(r, g, b)
	elseif last.r ~= r or last.g ~= g or last.b ~= b then
		last.r, last.g, last.b = r, g, b
		self.health:SetBarColor(r, g, b)
		if self.fillWhich and Settings.Get("target.fillOwn") then self:SetFill(self.fillWhich) end
	end
end

function Plate:UpdateHealth(immediate, refreshing)
	local health = self.health
	local sample = self.sample
	if sample then
		health:SetBarRange(0, 1)
		health:SetHealth(self:SampleHealth(), true)
	else
		local unit = self.unit
		health:SetBarRange(0, UnitHealthMax(unit))
		health:SetHealth(UnitHealth(unit), immediate)
	end
	self:UpdateHealthText()
	if self.absorb and refreshing then self:UpdateAbsorb() end
	if self.executeGate then self:UpdateExecute() end
	if (self.textOptions or self.extra1 or self.extra2) and not refreshing then self:UpdateTags("Health") end
end

function Plate:LayoutAbsorb()
	local on = Settings.Get("health.absorbs")
	if not (on or self.absorb) then return end
	local health = self.health
	if not self.absorb then
		local clip = CreateFrame("Frame", nil, health)
		clip:SetAllPoints(health)
		clip:SetClipsChildren(true)
		self.absorb = Widgets.StatusBar(clip, { background = false, glass = false, color = "white" })
	end
	local bar, place = self.absorb, ABSORB[Settings.Get("health.absorbPlace")]
	bar:GetParent():SetFrameLevel(health:GetFrameLevel() + 1)
	local reverse, point, rel = Settings.Get("health.reverse"), place[1], place[3]
	if reverse then point, rel = FLIP[point], FLIP[rel] end
	if health.vertical then point, rel = UPRIGHT[point], UPRIGHT[rel] end
	bar:SetOrientation(Settings.Get("health.orientation"))
	bar:SetReverseFill(place[4] ~= reverse)
	Widgets.Size(bar, self.barW, self.barH)
	bar:ClearAllPoints()
	bar:SetPoint(point, place[2] and health:GetStatusBarTexture() or health, rel)
	bar:SetBarTexture(Settings.Get("health.texture"))
	bar:SetBarColor(Widgets.Rgba("white", Settings.Get("health.absorbAlpha")))
	bar:SetShown(on)
	if on then self:UpdateAbsorb() end
end

function Plate:UpdateAbsorb()
	local bar = self.absorb
	if not bar:IsShown() then return end
	local sample = self.sample
	if sample then
		bar:SetBarRange(0, 1)
		bar:SetValue(sample.absorb or 0)
	elseif self.unit then
		local value = UnitValue(UnitGetTotalAbsorbs, self.unit)
		bar:SetBarRange(0, UnitHealthMax(self.unit))
		bar:SetValue(type(value) == "nil" and 0 or value)
	end
end

local function ExecuteCurve(share)
	local curve = executeCurves[share]
	if curve == nil then
		local util, kinds = C_CurveUtil, Enum and Enum.LuaCurveType
		curve = false
		if util and type(util.CreateCurve) == "function" and type(UnitHealthPercent) == "function" then
			curve = util.CreateCurve()
			if kinds and kinds.Step and curve.SetType then curve:SetType(kinds.Step) end
			curve:AddPoint(0, 1)
			curve:AddPoint(share, 1)
			curve:AddPoint(share + 0.001, 0)
			curve:AddPoint(1, 0)
		else
			LogOnce("execute-curve", "C_CurveUtil.CreateCurve or UnitHealthPercent is missing; plates show no execute glow")
		end
		executeCurves[share] = curve
	end
	return curve or nil
end

function Plate:SampleHealth()
	local sample = self.sample
	if sample.target and Settings.Get("health.execute") then return math.min(sample.health, (Settings.Get("health.executePercent") - 1) / 100) end
	return sample.health
end

function Plate:LayoutExecute()
	local on = Settings.Get("health.execute")
	if not (on or self.executeGate) then return end
	if not self.executeGate then
		local gate = CreateFrame("Frame", nil, self.glowFrame)
		gate:SetAllPoints(self.glowFrame)
		local pulse = CreateFrame("Frame", nil, gate)
		pulse:SetAllPoints(gate)
		local glow = Widgets.NineSlice(pulse, "shadow", "BACKGROUND", -3)
		for _, piece in ipairs(glow) do piece:SetBlendMode("ADD") end
		self.executeGate, self.executeFrame, self.executeGlow = gate, pulse, glow
		self.executePulse = Widgets.Pulse(pulse, 1, EXECUTE_LOW, Tokens.Duration("glowBreath"))
	end
	local level = self.glowFrame:GetFrameLevel()
	self.executeGate:SetFrameLevel(level)
	self.executeFrame:SetFrameLevel(level)
	Widgets.LayoutSlice(self.executeGlow, self.health, GLOW_CORNER, GLOW_OUTSET)
	local r, g, b = K.ColorVision.Color(2, Tokens.Color("hostile"))
	Widgets.ColorSlice(self.executeGlow, r, g, b, THREAT_GLOW_ALPHA)
	self.executeShown = nil
	self:UpdateExecute()
end

function Plate:UpdateExecute()
	local gate = self.executeGate
	local shown = Settings.Get("health.execute") and self.kind == "enemy" and not self.nameOnly
	if shown and self.sample then
		gate:SetAlpha(self:SampleHealth() * 100 <= Settings.Get("health.executePercent") and 1 or 0)
	elseif shown then
		local curve = ExecuteCurve(Settings.Get("health.executePercent") / 100)
		shown = curve ~= nil and self.unit ~= nil
		if shown then gate:SetAlpha(UnitHealthPercent(self.unit, true, curve)) end
	end
	if shown ~= self.executeShown then
		self.executeShown = shown
		gate:SetShown(shown)
	end
	local play = shown and Motion.Level() ~= "off"
	if play ~= self.executePulse:IsPlaying() then
		if play then self.executePulse:Play() else self.executePulse:Stop() end
	end
end

function Plate:UpdateHealthText()
	local text = self.healthText
	local show = self.healthTextEnabled and not self.nameOnly
	text:SetShown(show)
	if not show then
		return
	end
	if self.healthFormat ~= "" then
		return
	end
	local sample = self.sample
	if sample then
		text:SetFormattedText("%.0f%%", Widgets.WholePercent(self:SampleHealth() * 100))
		return
	end
	local unit = self.unit
	local format = Settings.Get("healthText.format")
	local curve = PercentCurve()
	if format == "value" or not curve then
		text:SetText(Widgets.ShortNumber(UnitHealth(unit)))
	elseif format == "both" then
		text:SetFormattedText("%s  %.0f%%", Widgets.ShortNumber(UnitHealth(unit)), Widgets.WholePercent(UnitHealthPercent(unit, true, curve)))
	else
		text:SetFormattedText("%.0f%%", Widgets.WholePercent(UnitHealthPercent(unit, true, curve)))
	end
end

function Plate:UpdateName(refreshing)
	local name = self.name
	local show = self.nameEnabled
	name:SetShown(show)
	if not show then
		if self.subtitle then self:UpdateSubtitle() end
		return
	end
	local value
	if self.who == "player" and self:Titled() then
		value = self:Is("pvpName", UnitPVPName, self.unit)
	else
		value = self:Is("name", UnitName, self.unit)
	end
	if self:NameFormat() == "" then
		local tag = self.statusTags and self:StatusTag()
		if IsSecret(value) then
			if tag then name:SetFormattedText("%s <%s>", value, tag) else name:SetText(value) end
		elseif type(value) == "string" then
			value = Settings.Get("name.upper") and K.Locale.Upper(value) or value
			Widgets.SetText(name, tag and value .. " <" .. tag .. ">" or value)
		else
			name:SetText("")
		end
	end
	self:UpdateNameColor(true)
	if (self.textOptions or self.extra1 or self.extra2) and not refreshing then self:UpdateTags("Name") end
	if self.subtitled or self.subtitle then self:UpdateSubtitle() end
end

local function TooltipLines(unit, missing)
	local api, kinds = C_TooltipInfo, Enum and Enum.TooltipDataLineType
	if not (api and type(api.GetUnit) == "function" and kinds) then
		LogOnce(missing, "C_TooltipInfo.GetUnit is missing; plates show no " .. missing)
		return nil
	end
	local ok, data = pcall(api.GetUnit, unit)
	local lines = ok and not IsSecret(data) and type(data) == "table" and not IsSecret(data.lines) and data.lines
	return type(lines) == "table" and lines or nil, kinds
end

local function NpcTitle(unit)
	local lines, kinds = TooltipLines(unit, "NPC titles")
	local line, level = lines and lines[2], lines and lines[3]
	if type(line) == "table" and type(level) == "table" and not IsSecret(line.type) and line.type == kinds.None
		and not IsSecret(level.type) and level.type == kinds.UnitLevel then
		return line.leftText
	end
end

function Plate.QuestChanged()
	objectives = nil
end

local function ObjectiveType(text)
	if not objectives then
		objectives = {}
		local log = C_QuestLog
		local count = log and type(log.GetNumQuestLogEntries) == "function" and type(log.GetInfo) == "function"
			and type(log.GetQuestObjectives) == "function" and log.GetNumQuestLogEntries()
		if IsSecret(count) or type(count) ~= "number" then
			LogOnce("quest-log", "the quest log API is missing; objective icons show the quest icon")
			count = 0
		end
		for i = 1, count do
			local info = log.GetInfo(i)
			local id = type(info) == "table" and not IsTrue(info.isHeader) and info.questID
			for _, goal in ipairs(type(id) == "number" and not IsSecret(id) and log.GetQuestObjectives(id) or {}) do
				if not IsSecret(goal.text) and type(goal.text) == "string" then objectives[goal.text] = goal.type end
			end
		end
	end
	return objectives[text] or objectives[(text:gsub("^[%s%-]+", ""))]
end

local function QuestProgress(unit, typed)
	local lines, kinds = TooltipLines(unit, "quest progress")
	local hidden = false
	for _, line in ipairs(lines or {}) do
		local text = type(line) == "table" and not IsSecret(line.type) and line.type == kinds.QuestObjective and not IsTrue(line.completed) and line.leftText
		if IsSecret(text) then
			hidden = true
		elseif type(text) == "string" then
			local count = text:match("%d+/%d+") or text:match("%d+%%")
			if count then return count, typed and ObjectiveType(text) end
		end
	end
	if hidden then return false end
end

function Plate.QuestRise(plate)
	local text = plate.questText
	if not (text and text:IsShown()) then return 0 end
	local size = Settings.Get("markers.questSize")
	local tall = plate.questIcon:IsShown() and size * math.max(1, Settings.Get("markers.questIconScale")) or size
	return math.max(0, tall - (plate.whoSize or Settings.Get("name.size")))
end

function Plate:UpdateQuest()
	local on = Settings.Get("markers.questText") and self.nameEnabled and not Plate.MarkersHidden()
	if not (on or self.questText) then return end
	local typed, count, kind = Settings.Get("markers.questIcon")
	if on and self.sample then
		count, kind = self.sample.questText, self.sample.questType
	elseif on and self.quest and self.unit then
		count, kind = QuestProgress(self.unit, typed)
	end
	local text, rise = self.questText, Plate.QuestRise(self)
	if count == false then count, kind = text and text.count, text and text.kind end
	if count and not text then
		text = NewText(self, "LEFT")
		text:SetTextColor(Tokens.Color("quest"))
		self.questText, self.questIcon = text, self:CreateTexture(nil, "OVERLAY")
		self:SetNameAlpha(self.name:GetAlpha())
	end
	if not text then return end
	text.kind = kind
	if count ~= text.count then
		text.count = count
		if count then text:SetText(count) end
		text:SetShown(count ~= nil)
	end
	local atlas = count and typed and (QUEST_ICONS[kind] or QUEST_ICON) or false
	if atlas ~= self.questIcon.atlas then
		self.questIcon.atlas = atlas
		local api = C_Texture and C_Texture.GetAtlasInfo
		local known = atlas and type(api) == "function" and api(atlas) ~= nil
		if known then self.questIcon:SetAtlas(atlas) elseif atlas then LogOnce("quest-atlas", "the client lacks " .. atlas .. "; quest progress shows no icon") end
		self.questIcon:SetShown(known)
		self:LayoutQuest()
	end
	if Plate.QuestRise(self) ~= rise then self:Reflow() end
end

function Plate:LayoutQuest()
	local text, icon = self.questText, self.questIcon
	local size = Settings.Get("markers.questSize")
	StyleFont(text, size, Settings.Get("name.outline"), "number")
	local side = size * Settings.Get("markers.questIconScale")
	Widgets.Size(icon, side, side)
	local after = self.pvpBadge and self.pvpBadge:IsShown() and self.pvpBadge or self.name
	local typed = icon:IsShown()
	icon:ClearAllPoints()
	text:ClearAllPoints()
	Widgets.Point(icon, "BOTTOMLEFT", after, "BOTTOMRIGHT", BADGE_GAP, 0)
	Widgets.Point(text, "BOTTOMLEFT", typed and icon or after, "BOTTOMRIGHT", typed and SUB_GAP or BADGE_GAP, 0)
end

function Plate:UpdateSubtitle()
	local text, size, brackets
	if self.nameEnabled and self.who == "player" and Settings.Get("friendly.guild") ~= "" then
		text, size, brackets = self:Is("guild", GetGuildInfo, self.unit), Settings.Get("friendly.guildSize"), Settings.Get("friendly.guild") == "brackets"
	elseif self.nameEnabled and self.who == "pet" and Settings.Get("friendly.owner") then
		local guid = self.unit and UnitValue(UnitOwnerGUID, self.unit)
		text = self.sample and self.sample.owner
		if type(guid) ~= "nil" then text = select(6, UnitValue(GetPlayerInfoByGUID, guid)) end
		size = Settings.Get("friendly.ownerOwnSize") and Settings.Get("friendly.ownerSize") or self.whoSize or Settings.Get("name.size")
	elseif self.nameEnabled and self.who == "npc" and Settings.Get("friendly.npcTitle") then
		text, size = self.sample and self.sample.title or self.unit and NpcTitle(self.unit), Settings.Get("friendly.npcTitleSize")
	end
	local has = IsSecret(text) or type(text) == "string" and text ~= ""
	local sub, fresh = self.subtitle, false
	if has then
		if not sub then
			fresh = true
			sub = NewText(self, "CENTER")
			sub:SetAlpha(self.name:GetAlpha())
			self.subtitle = sub
		end
		local path, _, flags = self.name:GetFont()
		Widgets.ApplyFont(sub, path, size, flags)
		sub:SetFormattedText(brackets and "<%s>" or "%s", text)
		self:MatchSubtitle()
		sub:Show()
	elseif sub then
		sub:Hide()
	end
	local room = has and not self.nameOnly and Widgets.Snap(self, size + SUB_GAP) or 0
	if fresh or room ~= (self.subtitleRoom or 0) then
		self.subtitleRoom = room
		self:LayoutName()
		self:Reflow()
	end
end

function Plate:Reflow()
	ns.Auras.Reanchor(self)
	if self.resource and self.resource:IsShown() then self.resourceStale = true; ns.Resource.Place(self, true) end
	if self.rise then ns.Stacking.Bound(self, self.rise) end
end

function Plate:MatchSubtitle()
	local sub = self.subtitle
	if not sub then return end
	local keys = SUB_COLOR[self.who] or SUB_COLOR.player
	if Settings.Get(keys[1]) then
		sub:SetTextColor(self.name:GetTextColor())
	else
		sub:SetTextColor(Rgb(Settings.Get(keys[2])))
	end
end

function Plate:StatusTag()
	if not IsTrue(self:Is("isPlayer", UnitIsPlayer, self.unit)) then
		return nil
	end
	if Settings.Get("name.afk") and IsTrue(self:Is("afk", UnitIsAFK, self.unit)) then
		return L["AFK"]
	elseif Settings.Get("name.dnd") and IsTrue(self:Is("dnd", UnitIsDND, self.unit)) then
		return L["DND"]
	end
end

function Plate:RegisterTagEvents()
	if self.sample then return end
	local absorbs = self.absorb ~= nil and Settings.Get("health.absorbs")
	if not (self.textOptions or self.extra1 or self.extra2 or absorbs) then
		for event in pairs(TAG_EVENTS) do self:UnregisterEvent(event) end
		return
	end
	for event, field in pairs(TAG_EVENTS) do
		local needed = absorbs and event == "UNIT_ABSORB_AMOUNT_CHANGED"
		for _, key in ipairs(TEXT_ELEMENTS) do
			local format = key == "name" and self:NameFormat() or Settings.Get(key .. ".textFormat")
			if self[key] and (key:match("^extra") or Settings.Get(key .. ".show")) and Widgets.ParseText(format).events[field] then needed = true end
		end
		if self.unit and needed then self:RegisterUnitEvent(event, self.unit) else self:UnregisterEvent(event) end
	end
	self:SetScript("OnEvent", OnTagEvent)
end

function Plate:PaintTags(key)
	local sample = self.sample
	if sample then
		sample = { name = sample.name, pvpName = sample.pvpName or sample.name, health = self:SampleHealth() * 100, healthMax = 100, level = sample.level, reaction = sample.reaction, own = sample.isPlayer }
	end
	local format = key == "name" and self:NameFormat() or Settings.Get(key .. ".textFormat")
	local tag = key == "name" and self.statusTags and self:StatusTag()
	Widgets.TagText(self[key], tag and format .. " <" .. tag .. ">" or format, self.unit, sample)
end

function Plate:UpdateTags(event)
	if not (self.textOptions or self.extra1 or self.extra2) then return end
	for _, key in ipairs(TEXT_ELEMENTS) do
		local text = self[key]
		local extra = key:match("^extra")
		local format = text and (key == "name" and self:NameFormat() or Settings.Get(key .. ".textFormat")) or ""
		if format ~= "" and (extra or Settings.Get(key .. ".show")) and (key ~= "healthText" or not self.nameOnly)
			and (not event or Widgets.ParseText(format).events[event]) then
			self:PaintTags(key)
		end
		local mode = text and Settings.Get(key .. ".colorMode") or ""
		if mode ~= "" and not (key == "name" and (self.threatState and ThreatName() or self:WhoColor())) then
			Widgets.TextTint(text, mode, Settings.Get(key .. ".color"), self.unit, self.sample)
			if key == "name" then self:MatchSubtitle() end
		end
	end
end

function Plate:UpdateNameColor(force)
	if not force then
		return
	end
	local name = self.name
	if self.threatState and ThreatName() then
		name:SetTextColor(ThreatColor(self.threatState))
		return
	end
	local mode, colorKey = self:WhoColor()
	if mode then
		Widgets.TextTint(name, mode, Settings.Get(colorKey), self.unit, self.sample)
		return
	end
	if IsTrue(self:Is("isPlayer", UnitIsPlayer, self.unit)) and Settings.Get("name.classColor") and (self.nameOnly
		or Settings.Get(SOURCE_KEYS[self.kind]) ~= "class" or self.kind == "enemy" and Settings.Get("enemy.playersUseEnemy")) then
		local class = self.sample and self.sample.class or select(2, UnitValue(UnitClass, self.unit))
		name:SetTextColor(Theme.ClassTextColorForWidget(class))
	else
		name:SetTextColor(Tokens.Color("textEmphasis"))
	end
end

function Plate:UpdateLevel()
	local diamond = self.level
	local level = self:Is("level", UnitEffectiveLevel or UnitLevel, self.unit)
	local text = Settings.Get("level.show") and Logic.LevelText(level)
	local mark = Settings.Get("markers.classification") and not Plate.MarkersHidden() and Logic.MarkerColor(self:Is("classification", UnitClassification, self.unit))
	local show = not self.nameOnly and (text or mark) and true or false
	diamond:SetShown(show)
	if not show then
		return
	end
	self.levelText:SetText(text or "")
	local mode = Settings.Get("level.colorMode")
	local dr, dg, db
	if mode == "difficulty" then dr, dg, db = Plate.DifficultyColor(level) end
	if not IsSecret(level) and level == SKULL_LEVEL then
		self.levelText:SetTextColor(Tokens.Color("hostile"))
	elseif mode == "custom" then
		self.levelText:SetTextColor(Rgb(Settings.Get("level.color")))
	elseif dr then
		self.levelText:SetTextColor(dr, dg, db)
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

function Plate.MarkersHidden()
	return ns.state.inInstance and not Settings.Get("markers.instances")
end

function Plate.DifficultyColor(level)
	if IsSecret(level) or type(level) ~= "number" or level <= 0 or type(GetCreatureDifficultyColor) ~= "function" then
		return nil
	end
	local c = GetCreatureDifficultyColor(level)
	if type(c) == "table" and not (IsSecret(c.r) or IsSecret(c.g) or IsSecret(c.b))
		and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
		return Theme.Brighten(c.r, c.g, c.b)
	end
end

local function ShowRaid(icon, shown, index)
	if not shown or type(index) == "nil" then
		icon:Hide()
	else
		icon:SetSpriteSheetCell(index, RAID_ROWS, RAID_COLUMNS)
		icon:Show()
	end
end

local function PlaceThreat(plate)
	local raid = plate.raid:IsShown() and plate.raid
	local height = raid and Widgets.Snap(plate, Settings.Get("markers.raidSize")) or plate.barH
	plate.threatShape:ClearAllPoints()
	Widgets.Point(plate.threatShape, "TOPLEFT", raid or plate.health, "TOPRIGHT", (raid and 0 or Plate.MarkerReach()) + Tokens.Size("gapTiny"), -Widgets.Snap(plate, (height - 6) / 2))
end

function Plate:UpdateRaid()
	local index
	local nameRaid = Settings.Get("markers.nameRaid") and self.nameRaid
	if Settings.Get("markers.raid") or nameRaid then
		index = self:Is("raid", GetRaidTargetIndex, self.unit)
	end
	ShowRaid(self.raid, Settings.Get("markers.raid"), index)
	if nameRaid then ShowRaid(nameRaid, self.nameEnabled, index) end
	if self.threatState then PlaceThreat(self) end
end

function Plate:UpdatePvp()
	local badge = Settings.Get("markers.pvp") and self.pvpBadge
	if not badge then return end
	local faction
	if self.nameEnabled and (IsTrue(self:Is("isPlayer", UnitIsPlayer, self.unit)) or not Settings.Get("markers.pvpPlayersOnly"))
		and IsTrue(self:Is("pvp", UnitIsPVP, self.unit)) then
		faction = self.sample and self.sample.faction or UnitValue(UnitFactionGroup, self.unit)
		local mine = Settings.Get("markers.pvpEnemyOnly") and UnitValue(UnitFactionGroup, "player")
		if IsSecret(faction) or IsSecret(mine) or faction == mine then
			faction = nil
		end
	end
	local atlas = faction and PVP_ATLAS[faction] or false
	if badge.atlas == atlas then return end
	badge.atlas = atlas
	if atlas then badge:SetAtlas(atlas) end
	badge:SetShown(atlas and true or false)
	if self.questText then self:LayoutQuest() end
end

function Plate:UpdateThreat()
	local display = Settings.Get("threat.display")
	local state
	if display ~= "off" and self.kind == "enemy" and not self.nameOnly then
		if self.sample then
			state = self.sample.threat
		elseif ns.state.inGroup or not Settings.Get("threat.groupOnly") then
			state = Logic.ThreatState(UnitValue(UnitThreatSituation, "player", self.unit), ns.state.isTank, Settings.Get("threat.calm"))
		end
	end
	local changed = state ~= self.threatState
	self.threatState = state
	self:UpdateThreatText()
	if changed and ThreatName() then
		self:UpdateNameColor(true)
		self:UpdateTags("Threat")
	end
	local shape = self.threatShape
	shape:SetShown(state ~= nil and display ~= "name" and Settings.Get("threat.shapes"))
	if state then
		if state == "warning" then shape:SetTexture((Tokens.Texture("diamond"))) else shape:SetColorTexture(Tokens.Color("white")) end
		shape:SetTexCoord(0, 1, 0, state == "warning" and 0.5 or 1)
		Widgets.Size(shape, state == "safe" and 2 or 6, 6)
		PlaceThreat(self)
		shape:SetVertexColor(ThreatColor(state))
	end
	local glow = self.threatGlow
	local keyline = ThreatEdge()
	if not self.focusRim then
		if keyline and state then
			self.health:SetRimColor(ThreatColor(state))
		else
			self.health:SetRimColor()
		end
	end
	if state and display == "glow" and not keyline then
		local r, g, b = ThreatColor(state)
		Widgets.ColorSlice(glow, r, g, b, THREAT_GLOW_ALPHA)
		Widgets.ShowSlice(glow, true)
		glow.on = true
	elseif glow.on then
		Widgets.ShowSlice(glow, false)
		glow.on = false
	end
	if changed then
		self:UpdateColor()
	end
end

function Plate:UpdateThreatText()
	local text = Settings.Get("threat.percent") and self.threatText
	if not text then return end
	local pct, state
	if self.kind == "enemy" and not self.nameOnly then
		if self.sample then
			pct, state = self.sample.threatPct, self.sample.threat
		else
			pct = select(3, UnitValue(UnitDetailedThreatSituation, "player", self.unit))
			if type(pct) ~= "nil" and Settings.Get("threat.percentColor") then
				state = Logic.ThreatState(UnitValue(UnitThreatSituation, "player", self.unit), ns.state.isTank, Settings.Get("threat.calm"))
			end
		end
	end
	if type(pct) == "nil" then
		if text:IsShown() then text:Hide() end
		return
	end
	text:SetFormattedText("%.0f%%", pct)
	local tint = Settings.Get("threat.percentColor") and state or "white"
	if text.tint ~= tint then
		text.tint = tint
		if tint == "white" then
			text:SetTextColor(Tokens.Color("textEmphasis"))
		else
			text:SetTextColor(ThreatColor(tint))
		end
	end
	text:Show()
end

function Plate:UpdateHighlight(sigilCasts)
	local isTarget, isFocus
	if self.sample then
		isTarget, isFocus = self.sample.target, self.sample.focus
		self.hovered, self.outOfRange = self.sample.hovered, self.sample.outOfRange and Settings.Get("range.fade")
	else
		isTarget = ns.Plates.IsUnit(self, "target")
		isFocus = ns.Plates.IsUnit(self, "focus")
	end
	ns.Cast.Gate(self, isTarget, sigilCasts)
	ns.Cast.Selection(self, isTarget, isFocus)
	local targeted = isTarget and not self.nameOnly and (self.kind ~= "friendly" or Settings.Get("target.friendly")) or false
	local framed = targeted and Settings.Get("target.highlight") or false
	if self.hashLine and Settings.Get("target.hashLine") then self.hashLine:SetShown(isTarget and not self.nameOnly or false) end
	if self.focusLetter and Settings.Get("focus.letter") ~= "" then self.focusLetter:SetShown(isFocus and not self.nameOnly or false) end
	if self.distanceText and Settings.Get("target.distance") then self.distanceText:SetShown((isTarget or self.sample) and not self.nameOnly or false) end
	local glow = Settings.Get("target.glow") and targeted or false
	if self.targetGlow and self.glowShown ~= glow then
		self.glowShown = glow
		Widgets.ShowSlice(self.targetGlow, glow)
	end
	self.targeted, self.focused = targeted, isFocus and not self.nameOnly
	self:UpdateFill()
	local tall = isFocus and Settings.Get("focus.castHeight") ~= 1 or nil
	if tall ~= self.castFocus then
		self.castFocus = tall
		ns.Cast.Resize(self)
	end
	if self.resource or Settings.Get("resource.show") then ns.Resource.Place(self, isTarget) end
	self:ShowBrackets(framed)
	local health = self.health
	self.focusRim = isFocus and Settings.Get("focus.highlight") and not framed
	if self.focusRim then
		local r, g, b = Rgb(Settings.Get("focus.color"))
		health:SetRimColor(r, g, b, 1)
	elseif ThreatEdge() and self.threatState then
		health:SetRimColor(ThreatColor(self.threatState))
	else
		health:SetRimColor()
	end
	local castScale = self.kind == "enemy" and Settings.Get("cast.scale") or 1
	local casting = castScale ~= 1 and (self.casting or not ns.Cast.Shows(self) and ns.Cast.Active(self))
	local boost = (targeted and Settings.Get("target.scale") or 1) * (casting and castScale or 1)
	if boost ~= (self.boost or 1) then
		self.boost = boost
		self:ApplyScale()
		if not self.sample then ns.Stacking.Bound(self, self.rise or 0) end
	end
	self.isTarget, self.isFocus = isTarget, isFocus
	self:UpdateAlpha()
end

function Plate:UpdateAlpha()
	local alpha = 1
	if not self.sample and ns.state.hasTarget and not self.isTarget
		and not (self.isFocus and Settings.Get("focus.fullOpacity")) and not (self.casting and Settings.Get("cast.fullOpacity")) then
		alpha = Settings.Get("target.dimOthers")
	end
	if self.outOfRange then alpha = alpha * Settings.Get("range.alpha") end
	if self.alphaGoal ~= alpha or not Settings.Get("target.smoothOpacity") then
		self.alphaGoal = alpha
		self.alphaTween = Motion.Tween(self, "SetAlpha", self:GetAlpha(), alpha, Settings.Get("target.smoothOpacity") and 0.2 or 0, "outQuad")
	end
end

function Plate:UpdateFill()
	if not self.targetFill then return end
	local which = self.targeted and Settings.Get("target.fill") and "target" or self.focused and Settings.Get("focus.fill") and "focus"
		or self.hovered and Settings.Get("target.hover") and not self.nameOnly and "target" or nil
	if which ~= self.fillWhich then self:SetFill(which) end
end

function Plate:SetFill(which)
	self.fillWhich = which
	local fill = self.targetFill
	fill:SetShown(which ~= nil)
	if not which then return end
	local r, g, b = Rgb(Settings.Get(which .. ".fillColor"))
	local last = self.colorKey
	if Settings.Get("target.fillOwn") and last.r then r, g, b = last.r, last.g, last.b end
	fill:SetVertexColor(r, g, b)
	fill:SetAlpha(Settings.Get(which .. ".fillAlpha"))
end
