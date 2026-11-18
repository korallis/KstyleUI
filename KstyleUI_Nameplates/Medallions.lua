-- Medallions.lua: the Medallions HUD style on the plates: a 120 by 9 bar under an 11-unit Inter caps name, the level in Barlow at the bar's left in its difficulty colour, 22-unit debuffs, two gunmetal ticks on the target, and a painted badge over a friendly player's name; a setting the player changed keeps the player's value.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Plate, Plates, Logic, Settings = ns.Plate, ns.Plates, ns.Logic, ns.Settings
local IsSecret = Logic.IsSecret

local Medallions = {}
ns.Medallions = Medallions

local STYLE = "medallions"
local OWNER = "Nameplates.Medallions"
local WIDTH, HEIGHT = 120, 9
local LOOK = {
	["name.size"] = 11,
	["name.outline"] = "OUTLINE",
	["level.size"] = 12,
	["level.outline"] = "OUTLINE",
	["debuffs.size"] = 22,
	["debuffs.textSize"] = 11,
}
local OUTLINE_FLAGS = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }
local NAME_FACE = "InterSemiBold"
local TICK_WIDTH, TICK_GAP, TICK_OVERHANG = 2, 3, 2
local LEVEL_GAP = TICK_GAP + TICK_WIDTH + 2
local GUNMETAL = { Tokens.Color("medGunLit") }
local BADGE = 22
local BADGE_GAP = 2
local SKULL_LEVEL = -1
Medallions.BADGE = BADGE
Medallions.WIDTH, Medallions.HEIGHT = WIDTH, HEIGHT
Medallions.LOOK = LOOK
Medallions.GUNMETAL = GUNMETAL

function Medallions.Active()
	local hud = K.HudStyle
	return hud ~= nil and type(hud.Current) == "function" and hud.Current() == STYLE
end

local function Default(key)
	local node = Settings.defaults
	for part in key:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

local get = Settings.Get
function Settings.Get(key, role)
	local value = get(key, role)
	local look = LOOK[key]
	if look ~= nil and value == Default(key) and Medallions.Active() then
		return look
	end
	return value
end

local readSize = Plates.ReadSize
function Plates.ReadSize()
	readSize()
	local state = ns.state
	if Medallions.Active() and state.width == Plate.DEFAULT_WIDTH and state.height == Plate.DEFAULT_HEIGHT then
		state.width, state.height = WIDTH, HEIGHT
	end
end

local function FollowsKit()
	return Settings.Get("font") == (Tokens.Font("body"))
end

local function Mask(badge, masked)
	if badge.masked == masked then
		return
	end
	badge.masked = masked
	if masked then
		badge:AddMaskTexture(badge.mask)
	else
		badge:RemoveMaskTexture(badge.mask)
	end
end

local function ShowBadge(badge, shown)
	badge:SetShown(shown)
	badge.ring:SetShown(shown)
end

local Component = { events = {} }

local function Build(plate)
	local badge = plate:CreateTexture(nil, "ARTWORK")
	badge.mask = plate:CreateMaskTexture()
	badge.mask:SetTexture((Tokens.Texture("dot")))
	badge.mask:SetAllPoints(badge)
	badge.masked = false
	Mask(badge, true)
	badge.ring = plate:CreateTexture(nil, "OVERLAY")
	ShowBadge(badge, false)
	plate.medBadge = badge
end

local function StyleType(plate)
	if not FollowsKit() then
		return
	end
	Widgets.ApplyFont(plate.name, Tokens.FontPath(NAME_FACE), Settings.Get("name.size"), OUTLINE_FLAGS[Settings.Get("name.outline")])
	local number = (Tokens.Font("number"))
	Widgets.ApplyFont(plate.levelText, number, Settings.Get("level.size"), OUTLINE_FLAGS[Settings.Get("level.outline")])
	Widgets.ApplyFont(plate.healthText, number, Settings.Get("healthText.size"), OUTLINE_FLAGS[Settings.Get("healthText.outline")])
end

function Component.Restyle(plate)
	local on = Medallions.Active()
	if not on and not plate.medBadge then
		return
	end
	if not plate.medBadge then
		Build(plate)
	end
	local badge = plate.medBadge
	local size = Widgets.Snap(plate, BADGE)
	Widgets.Size(badge, size, size)
	badge:ClearAllPoints()
	Plate.Place(badge, "BOTTOM", plate.name, "TOP", 0, BADGE_GAP, size, size, 0, 0)
	local outset = Widgets.Snap(plate, size * Widgets.RING_INSET / (1 - 2 * Widgets.RING_INSET))
	badge.ring:ClearAllPoints()
	badge.ring:SetPoint("TOPLEFT", badge, "TOPLEFT", -outset, outset)
	badge.ring:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", outset, -outset)
	if not on then
		ShowBadge(badge, false)
		return
	end
	badge.ring:SetTexture((Tokens.Texture("medRing")))
	StyleType(plate)
end

local function Portrait(plate)
	local badge = plate.medBadge
	local sample = plate.sample
	if sample then
		if not sample.badge then
			return false
		end
		badge:SetTexture(sample.badge)
		Mask(badge, false)
		return true
	end
	local api = K.Medallions
	if api and type(api.Portrait) == "function" then
		Mask(badge, not api.Portrait(badge, plate.unit, "badge"))
		return true
	end
	if type(SetPortraitTexture) ~= "function" then
		return false
	end
	SetPortraitTexture(badge, plate.unit)
	Mask(badge, true)
	return true
end

function Component.Refresh(plate)
	local badge = plate.medBadge
	if not badge then
		return
	end
	local isPlayer = plate:Is("isPlayer", UnitIsPlayer, plate.unit)
	local shown = Medallions.Active() and plate.kind == "friendly" and not IsSecret(isPlayer) and isPlayer == true
		and plate.name:IsShown() and Portrait(plate)
	ShowBadge(badge, shown and true or false)
end

Component.events.UNIT_PORTRAIT_UPDATE = Component.Refresh

function Component.Clear(plate)
	if plate.medBadge then
		ShowBadge(plate.medBadge, false)
	end
end

ns.Components[#ns.Components + 1] = Component

local layoutDiamond = Plate.LayoutDiamond
function Plate:LayoutDiamond()
	layoutDiamond(self)
	local on = Medallions.Active()
	for _, layer in ipairs(self.level.layers) do
		layer:SetShown(not on)
	end
	if not on then
		return
	end
	self.levelText:ClearAllPoints()
	Plate.Place(self.levelText, "RIGHT", self.health, "LEFT", -Widgets.Snap(self, LEVEL_GAP), 0, nil, nil, self.barW, self.barH)
end

local layoutBrackets = Plate.LayoutBrackets
function Plate:LayoutBrackets()
	layoutBrackets(self)
	local on = Medallions.Active()
	for _, frame in ipairs(self.brackets.sides) do
		frame.top:SetShown(not on)
		frame.bottom:SetShown(not on)
	end
	if not on then
		return
	end
	local width = math.max(Plate.Pixel(self), Widgets.Snap(self, TICK_WIDTH))
	local height = self.barH + Widgets.Snap(self, TICK_OVERHANG) * 2
	local gap = Widgets.Snap(self, TICK_GAP)
	for _, frame in ipairs(self.brackets.sides) do
		local left = frame.side == "left"
		frame:SetSize(width, height)
		frame:ClearAllPoints()
		Plate.Place(frame, left and "RIGHT" or "LEFT", self.health, left and "LEFT" or "RIGHT", (left and -1 or 1) * gap, 0, width, height, self.barW, self.barH)
		frame.stroke:SetWidth(width)
		frame.open:SetOffset(0, 0)
		frame.close:SetOffset(0, 0)
	end
end

local paintBrackets = Plate.PaintBrackets
function Plate:PaintBrackets()
	paintBrackets(self)
	if not Medallions.Active() then
		return
	end
	for _, frame in ipairs(self.brackets.sides) do
		frame.stroke:SetVertexColor(GUNMETAL[1], GUNMETAL[2], GUNMETAL[3], 1)
	end
end

local function LevelColor(plate, level)
	local mark = Settings.Get("markers.classification") and Logic.MarkerColor(plate:Is("classification", UnitClassification, plate.unit))
	if mark then
		return Tokens.Color(mark)
	end
	if IsSecret(level) or type(level) ~= "number" then
		return Tokens.Color("medText")
	end
	if level == SKULL_LEVEL then
		return Tokens.Color("hostile")
	end
	if plate.kind == "enemy" and level > 0 and type(GetCreatureDifficultyColor) == "function" then
		local c = GetCreatureDifficultyColor(level)
		if type(c) == "table" and not (IsSecret(c.r) or IsSecret(c.g) or IsSecret(c.b))
			and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
			return K.Theme.Brighten(c.r, c.g, c.b)
		end
	end
	return Tokens.Color("medText")
end

local updateLevel = Plate.UpdateLevel
function Plate:UpdateLevel()
	updateLevel(self)
	if not Medallions.Active() or not self.level:IsShown() then
		return
	end
	self.levelText:SetTextColor(LevelColor(self, self:Is("level", UnitEffectiveLevel or UnitLevel, self.unit)))
end
Plate.UpdateMarker = Plate.UpdateLevel

local function OnHudStyle()
	Plates.ReadSize()
	Plates.RestyleAll()
	ns.Stacking.Schedule()
end

local start, stop = Plates.Start, Plates.Stop
function Plates.Start(...)
	K.Callbacks.Register("HudStyleChanged", OWNER, OnHudStyle)
	return start(...)
end

function Plates.Stop(...)
	K.Callbacks.Unregister("HudStyleChanged", OWNER)
	return stop(...)
end
