-- Medallions.lua: the Medallions HUD style on the plates: a 120 by 9 bar under an 11-unit Inter caps name, the level in Barlow at the bar's left in its difficulty colour, 22-unit debuffs, two gunmetal ticks on the target, and a painted badge over a friendly player's name.
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
Medallions.GUNMETAL = GUNMETAL

function Medallions.Active()
	local hud = K.HudStyle
	return hud ~= nil and type(hud.Current) == "function" and hud.Current() == STYLE
end

local readSize = Plates.ReadSize
function Plates.ReadSize()
	readSize()
	local state = ns.state
	if Medallions.Active() and state.width == Plate.DEFAULT_WIDTH then
		state.width = WIDTH
		if state.height == Plate.DEFAULT_HEIGHT and Settings.Get("preset") == "lumen" then state.height = HEIGHT end
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
	if K.Theme.FollowsKit(Settings.Get("name.font")) then
		Widgets.ApplyFont(plate.name, Tokens.FontPath(NAME_FACE), Settings.Get("name.size"), OUTLINE_FLAGS[Settings.Get("name.outline")])
	end
	local number = (Tokens.Font("number"))
	if K.Theme.FollowsKit(Settings.Get("level.font")) then
		Widgets.ApplyFont(plate.levelText, number, Settings.Get("level.size"), OUTLINE_FLAGS[Settings.Get("level.outline")])
	end
	if K.Theme.FollowsKit(Settings.Get("healthText.font")) then
		Widgets.ApplyFont(plate.healthText, number, Settings.Get("healthText.size"), OUTLINE_FLAGS[Settings.Get("healthText.outline")])
	end
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
	Plate.Place(self.levelText, "RIGHT", self.health, "LEFT", -Widgets.Snap(self, LEVEL_GAP + (Settings.Get("target.readableTicks") and 2 or 0)) + Settings.Get("level.x"),
		Settings.Get("level.y"), nil, nil, self.barW, self.barH)
end

local layoutBrackets = Plate.LayoutBrackets
function Plate:LayoutBrackets()
	layoutBrackets(self)
	local on = Medallions.Active()
	for _, frame in ipairs(self.brackets.sides) do
		if frame.keyline then frame.keyline:SetShown(on and Settings.Get("target.readableTicks")) end
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
		local readable = Settings.Get("target.readableTicks")
		local travel = readable and Widgets.Snap(self, 3) or 0
		frame.open:SetOffset((left and -1 or 1) * travel, 0)
		frame.close:SetOffset((left and 1 or -1) * travel, 0)
		if not frame.keyline then
			frame.keyline = Widgets.Crisp(frame:CreateTexture(nil, "BACKGROUND"))
			frame.keyline:SetColorTexture(Tokens.Color("black"))
			frame.reveal = frame.group:CreateAnimation("Alpha")
			frame.reveal:SetOrder(2)
			frame.reveal:SetFromAlpha(0)
			frame.reveal:SetToAlpha(1)
			frame.reveal:SetSmoothing("OUT")
		end
		frame.reveal:SetDuration(readable and 0.12 or 0)
		local px = Plate.Pixel(self)
		frame.keyline:ClearAllPoints()
		frame.keyline:SetPoint("TOPLEFT", frame, "TOPLEFT", -px, px)
		frame.keyline:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", px, -px)
		frame.keyline:SetShown(readable)
	end
end

local paintBrackets = Plate.PaintBrackets
function Plate:PaintBrackets()
	paintBrackets(self)
	if not Medallions.Active() then
		return
	end
	for _, frame in ipairs(self.brackets.sides) do
		if Settings.Get("target.readableTicks") then
			frame.stroke:SetVertexColor(Tokens.Color("medText"))
		else
			frame.stroke:SetVertexColor(GUNMETAL[1], GUNMETAL[2], GUNMETAL[3], 1)
		end
	end
end

local function LevelColor(plate, level)
	if Settings.Get("target.readableTicks") and not IsSecret(level) and level == SKULL_LEVEL then return Tokens.Color("nameHostile") end
	local mark = Settings.Get("markers.classification") and not Plate.MarkersHidden() and Logic.MarkerColor(plate:Is("classification", UnitClassification, plate.unit))
	if mark then
		return Tokens.Color(mark)
	end
	if IsSecret(level) or type(level) ~= "number" then
		return Tokens.Color("medText")
	end
	if level == SKULL_LEVEL then
		return Tokens.Color("hostile")
	end
	if plate.kind == "enemy" then
		local r, g, b = Plate.DifficultyColor(level)
		if r then
			return r, g, b
		end
	end
	return Tokens.Color("medText")
end

local updateLevel = Plate.UpdateLevel
function Plate:UpdateLevel()
	updateLevel(self)
	if not Medallions.Active() or not self.level:IsShown() or Settings.Get("level.colorMode") ~= "" then
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
