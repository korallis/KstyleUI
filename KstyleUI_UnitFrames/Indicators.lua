-- Indicators.lua: a unit frame's raid marker, leader, role, PvP, combat and resting icons and its threat glow.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Settings, Geometry = ns.Settings, ns.Geometry

local Indicators = {}
ns.Indicators = Indicators

local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local RAID_ROWS, RAID_COLUMNS = 4, 4
local ICON_GAP = 2
local ICON_INSET = 6
local GLOW_SPREAD = 6
local GLOW_ALPHA = 0.9

local ATLAS = {
	leader = "UI-HUD-UnitFrame-Player-Group-LeaderIcon",
	combat = "UI-HUD-UnitFrame-Player-CombatIcon",
	TANK = "roleicon-tiny-tank",
	HEALER = "roleicon-tiny-healer",
	DAMAGER = "roleicon-tiny-dps",
	Horde = "UI-HUD-UnitFrame-SmallCircle-Horde",
	Alliance = "UI-HUD-UnitFrame-SmallCircle-Alliance",
	ffa = "UI-HUD-UnitFrame-Player-PVP-FFAIcon",
}

local SLOTS = { "leader", "role", "pvp", "combat", "resting" }
Indicators.SLOTS = SLOTS

local issecretvalue = issecretvalue or function()
	return false
end

local function Shown(region, value)
	if issecretvalue(value) then
		region:Show()
		region:SetAlphaFromBoolean(value, 1, 0)
		return
	end
	region:SetAlpha(1)
	region:SetShown(value == true)
end

function Indicators.New(view)
	local top = view.top
	local icons = {}
	for _, key in ipairs(SLOTS) do
		if key == "resting" then
			local text = Widgets.FontString(top, "OVERLAY")
			text:SetJustifyH("CENTER")
			text:SetJustifyV("MIDDLE")
			text:SetText(L["Zz"])
			icons[key] = text
		else
			icons[key] = top:CreateTexture(nil, "OVERLAY")
		end
		icons[key]:Hide()
	end
	icons.leader:SetAtlas(ATLAS.leader)
	icons.combat:SetAtlas(ATLAS.combat)
	view.icons = icons
	view.marker = top:CreateTexture(nil, "OVERLAY")
	view.marker:SetTexture(RAID_ICONS)
	view.marker:Hide()
	local glow = CreateFrame("Frame", nil, view.parent)
	glow:SetFrameLevel(view.parent:GetFrameLevel())
	glow:SetAllPoints(view.panel)
	view.glowFrame = glow
	view.glow = Widgets.NineSlice(glow, "shadow", "BACKGROUND", 0)
	for _, piece in ipairs(view.glow) do
		piece:SetBlendMode("ADD")
	end
	glow:Hide()
end

local function Snap(view, units)
	return Widgets.Snap(view.parent, units)
end

local function PlaceMarker(view, x)
	local spot = view.geometry.marker
	local marker = view.marker
	marker:ClearAllPoints()
	marker:SetPoint("TOPLEFT", view.parent, "TOPLEFT", Snap(view, x), -Snap(view, spot.y))
end

function Indicators.Fit(view)
	local g = view.geometry
	local lane = g and g.markedName
	if not lane then
		return
	end
	local on = view.marker:IsShown() == true
	if on ~= view.markerCut then
		view.markerCut = on
		ns.Style.PlaceName(view, on and lane or g.name)
		ns.Unit.Refit(view)
	end
	if not (on and g.markerCentred) then
		return
	end
	local spot = g.marker
	local width = Widgets.TextWidth(view.name)
	local x = spot.x
	if width then
		x = math.max(spot.x, lane.x + (lane.w - math.min(width, lane.w)) / 2 - Geometry.MARKER_GAP - spot.w)
	end
	PlaceMarker(view, x)
end

function Indicators.Layout(view, g, s)
	local size = Snap(view, s.iconSize)
	local panel = g.panel
	local fromRight = s.portrait and s.portraitSide ~= "RIGHT" or not s.portrait
	local step = size + Snap(view, ICON_GAP)
	local x = fromRight and (panel.x + panel.w - ICON_INSET - size) or (panel.x + ICON_INSET)
	for i, key in ipairs(SLOTS) do
		local icon = view.icons[key]
		local offset = (i - 1) * step
		local left = fromRight and (x - offset) or (x + offset)
		icon:ClearAllPoints()
		icon:SetPoint("CENTER", view.parent, "TOPLEFT", Snap(view, left + size / 2), -Snap(view, g.glass.y))
		icon:SetSize(size, size)
		if key == "resting" then
			local path = Settings.Font(view.kind, "level")
			icon:SetFont(path, size, "OUTLINE")
		end
	end
	local spot = g.marker
	if spot then
		local marker = view.marker
		marker:SetSize(Snap(view, spot.w), Snap(view, spot.h))
		PlaceMarker(view, spot.x)
	end
	view.markerCut = false
	Indicators.Fit(view)
	view.glowFrame:ClearAllPoints()
	view.glowFrame:SetAllPoints(g.chrome == false and view.health or view.panel)
	local _, _, shadowUnits = Tokens.Texture("shadow")
	Widgets.LayoutSlice(view.glow, view.glowFrame, shadowUnits, GLOW_SPREAD)
end

function Indicators.Marker(view, unit)
	local marker = view.marker
	if not view.s.raidMarker or not GetRaidTargetIndex then
		marker:Hide()
		Indicators.Fit(view)
		return
	end
	local index = GetRaidTargetIndex(unit)
	if type(index) ~= "number" then
		marker:Hide()
	elseif issecretvalue(index) then
		marker:SetSpriteSheetCell(index, RAID_ROWS, RAID_COLUMNS)
		marker:Show()
	elseif index > 0 then
		marker:SetSpriteSheetCell(index, RAID_ROWS, RAID_COLUMNS)
		marker:Show()
	else
		marker:Hide()
	end
	Indicators.Fit(view)
end

function Indicators.Leader(view, unit)
	local icon = view.icons.leader
	if not view.s.leader or not UnitIsGroupLeader then
		icon:Hide()
		return
	end
	Shown(icon, UnitIsGroupLeader(unit))
end

function Indicators.Role(view, unit)
	local icon = view.icons.role
	if not view.s.role or not UnitGroupRolesAssigned then
		icon:Hide()
		return
	end
	local role = UnitGroupRolesAssigned(unit)
	local atlas = not issecretvalue(role) and type(role) == "string" and ATLAS[role]
	if atlas then
		icon:SetAtlas(atlas)
		icon:Show()
	else
		icon:Hide()
	end
end

function Indicators.PvP(view, unit)
	local icon = view.icons.pvp
	if not view.s.pvp then
		icon:Hide()
		return
	end
	local ffa = UnitIsPVPFreeForAll and UnitIsPVPFreeForAll(unit)
	if not issecretvalue(ffa) and ffa == true then
		icon:SetAtlas(ATLAS.ffa)
		icon:Show()
		return
	end
	local flagged = UnitIsPVP and UnitIsPVP(unit)
	local faction = UnitFactionGroup and UnitFactionGroup(unit)
	local atlas = not issecretvalue(faction) and type(faction) == "string" and ATLAS[faction]
	if issecretvalue(flagged) or flagged ~= true or not atlas then
		icon:Hide()
		return
	end
	icon:SetAtlas(atlas)
	icon:Show()
end

function Indicators.Combat(view, unit)
	local icon = view.icons.combat
	if not view.s.combat or not UnitAffectingCombat then
		icon:Hide()
		return
	end
	Shown(icon, UnitAffectingCombat(unit))
end

function Indicators.Resting(view, unit)
	local icon = view.icons.resting
	if not view.s.resting or unit ~= "player" or not IsResting then
		icon:Hide()
		return
	end
	Shown(icon, IsResting())
end

local function ThreatStatus(unit)
	if not UnitThreatSituation then
		return nil
	end
	if unit == "player" or not (UnitCanAttack and UnitCanAttack("player", unit)) then
		return UnitThreatSituation(unit)
	end
	return UnitThreatSituation("player", unit)
end

function Indicators.Threat(view, unit)
	local glow = view.glowFrame
	if not view.s.threat then
		view.threatStatus = nil
		glow:Hide()
		return
	end
	local status = ThreatStatus(unit)
	if issecretvalue(status) or type(status) ~= "number" or status <= 0 then
		view.threatStatus = nil
		glow:Hide()
		return
	end
	if status == view.threatStatus and glow:IsShown() then
		return
	end
	local r, g, b = K.Theme.ThreatColor(status)
	if not r then
		view.threatStatus = nil
		glow:Hide()
		return
	end
	view.threatStatus = status
	Widgets.ColorSlice(view.glow, r, g, b, GLOW_ALPHA)
	glow:Show()
end

function Indicators.Status(view, unit)
	Indicators.Leader(view, unit)
	Indicators.Role(view, unit)
	Indicators.PvP(view, unit)
	Indicators.Combat(view, unit)
	Indicators.Resting(view, unit)
end

function Indicators.Update(view, unit)
	Indicators.Marker(view, unit)
	Indicators.Status(view, unit)
	Indicators.Threat(view, unit)
end
