-- Medallions.lua: the Medallions HUD style on the plates: a painted badge over a friendly player's name, steel target brackets with a soft glow at each corner, and a steel level diamond; the bar keeps Blizzard's size and anchor.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Plate, Plates, Logic = ns.Plate, ns.Plates, ns.Logic
local IsSecret = Logic.IsSecret

local Medallions = {}
ns.Medallions = Medallions

local STYLE = "medallions"
local OWNER = "Nameplates.Medallions"
local STEEL = { 0.725, 0.757, 0.8 }
local STEEL_LIT = { 0.902, 0.925, 0.953 }
local RIM_ALPHA = 0.8
local BADGE = 22
local BADGE_GAP = 2
local GLOW = 16
local GLOW_ALPHA = 0.55
local SKULL_LEVEL = -1
local CORNERS = {
	left = { { "TOPLEFT", 0, 1, 0, 1 }, { "BOTTOMLEFT", 0, 1, 1, 0 } },
	right = { { "TOPRIGHT", 1, 0, 0, 1 }, { "BOTTOMRIGHT", 1, 0, 1, 0 } },
}
Medallions.BADGE = BADGE

function Medallions.Active()
	local hud = K.HudStyle
	return hud ~= nil and type(hud.Current) == "function" and hud.Current() == STYLE
end

local function Texture(name, fallback)
	local ok, path = pcall(Tokens.Texture, name)
	if ok then
		return path
	end
	ns.LogOnce("texture:" .. name, "the " .. name .. " texture is missing; Medallions plates use " .. fallback)
	return (Tokens.Texture(fallback))
end

local function Mask(badge, masked)
	if badge.masked == masked then
		return
	end
	badge.masked = masked
	if masked then
		badge.portrait:AddMaskTexture(badge.mask)
	else
		badge.portrait:RemoveMaskTexture(badge.mask)
	end
end

local Component = {}

function Component.Build(plate)
	local badge = CreateFrame("Frame", nil, plate)
	badge:SetFrameLevel(plate.level:GetFrameLevel())
	badge.portrait = badge:CreateTexture(nil, "ARTWORK")
	badge.mask = badge:CreateMaskTexture()
	badge.mask:SetTexture((Tokens.Texture("dot")))
	badge.mask:SetAllPoints(badge.portrait)
	badge.masked = false
	Mask(badge, true)
	badge.ring = badge:CreateTexture(nil, "OVERLAY")
	badge:Hide()
	plate.medBadge = badge
	for _, frame in ipairs(plate.brackets.sides) do
		frame.glow = {}
		for i = 1, #CORNERS[frame.side] do
			local glow = frame:CreateTexture(nil, "ARTWORK")
			glow:SetBlendMode("ADD")
			glow:Hide()
			frame.glow[i] = glow
		end
	end
end

function Component.Restyle(plate)
	local on = Medallions.Active()
	local badge = plate.medBadge
	local size = Widgets.Snap(plate, BADGE)
	Widgets.Size(badge, size, size)
	badge:ClearAllPoints()
	Plate.Place(badge, "BOTTOM", plate.name, "TOP", 0, BADGE_GAP, size, size, 0, 0)
	badge.portrait:SetAllPoints(badge)
	local outset = Widgets.Snap(plate, size * Widgets.RING_INSET / (1 - 2 * Widgets.RING_INSET))
	badge.ring:ClearAllPoints()
	badge.ring:SetPoint("TOPLEFT", badge, "TOPLEFT", -outset, outset)
	badge.ring:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", outset, -outset)
	if not on then
		badge:Hide()
		return
	end
	badge.ring:SetTexture(Texture("medRing", "ringBevel"))
	local glowPath, glowSize = Texture("medBracketGlow", "glow"), Widgets.Snap(plate, GLOW)
	for _, frame in ipairs(plate.brackets.sides) do
		for i, corner in ipairs(CORNERS[frame.side]) do
			local glow = frame.glow[i]
			glow:SetTexture(glowPath)
			glow:SetTexCoord(corner[2], corner[3], corner[4], corner[5])
			glow:SetSize(glowSize, glowSize)
			glow:ClearAllPoints()
			glow:SetPoint("CENTER", frame, corner[1])
		end
	end
	plate:PaintBrackets()
end

local function Portrait(plate)
	local badge = plate.medBadge
	local sample = plate.sample
	if sample then
		if not sample.badge then
			return false
		end
		badge.portrait:SetTexture(sample.badge)
		Mask(badge, false)
		return true
	end
	local api = K.Medallions
	if api and type(api.Portrait) == "function" then
		Mask(badge, not api.Portrait(badge.portrait, plate.unit, "badge"))
		return true
	end
	if type(SetPortraitTexture) ~= "function" then
		return false
	end
	SetPortraitTexture(badge.portrait, plate.unit)
	Mask(badge, true)
	return true
end

function Component.Refresh(plate)
	local badge = plate.medBadge
	local isPlayer = plate:Is("isPlayer", UnitIsPlayer, plate.unit)
	local shown = Medallions.Active() and plate.kind == "friendly" and not IsSecret(isPlayer) and isPlayer == true
		and plate.name:IsShown() and Portrait(plate)
	badge:SetShown(shown and true or false)
end

function Component.Clear(plate)
	plate.medBadge:Hide()
end

ns.Components[#ns.Components + 1] = Component

local paintBrackets = Plate.PaintBrackets
function Plate:PaintBrackets()
	paintBrackets(self)
	local on = Medallions.Active()
	for _, frame in ipairs(self.brackets.sides) do
		if on then
			frame.stroke:SetVertexColor(STEEL_LIT[1], STEEL_LIT[2], STEEL_LIT[3], 1)
			frame.top:SetVertexColor(STEEL_LIT[1], STEEL_LIT[2], STEEL_LIT[3], 1)
			frame.bottom:SetVertexColor(STEEL_LIT[1], STEEL_LIT[2], STEEL_LIT[3], 1)
		end
		for _, glow in ipairs(frame.glow or {}) do
			glow:SetVertexColor(STEEL_LIT[1], STEEL_LIT[2], STEEL_LIT[3], GLOW_ALPHA)
			glow:SetShown(on)
		end
	end
end

local updateLevel = Plate.UpdateLevel
function Plate:UpdateLevel()
	updateLevel(self)
	if not Medallions.Active() or not self.level:IsShown() then
		return
	end
	if self.rimWeight == 1 then
		self.level.rim:SetVertexColor(STEEL[1], STEEL[2], STEEL[3], RIM_ALPHA)
	end
	local level = self:Is("level", UnitEffectiveLevel or UnitLevel, self.unit)
	if IsSecret(level) or level ~= SKULL_LEVEL then
		self.levelText:SetTextColor(STEEL_LIT[1], STEEL_LIT[2], STEEL_LIT[3])
	end
end
Plate.UpdateMarker = Plate.UpdateLevel

local start, stop = Plates.Start, Plates.Stop
function Plates.Start(...)
	K.Callbacks.Register("HudStyleChanged", OWNER, Plates.RestyleAll)
	return start(...)
end

function Plates.Stop(...)
	K.Callbacks.Unregister("HudStyleChanged", OWNER)
	return stop(...)
end
