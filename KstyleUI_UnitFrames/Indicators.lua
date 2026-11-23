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

Indicators.ATLAS = ATLAS
local SLOTS = { "leader", "role", "pvp", "combat", "resting" }
Indicators.SLOTS = SLOTS
local RANK = {
	elite = "nameplates-icon-elite-gold", worldboss = "nameplates-icon-elite-gold",
	rareelite = "nameplates-icon-elite-silver", rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star",
}
local MOOD = { "UI-PetMad", "UI-PetNeutral", "UI-PetHappiness" }

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

local MIRROR = { "Show", "Hide", "SetShown", "SetAlpha", "SetAlphaFromBoolean" }

local function Socket(view, region, rim, size)
	local back = region.socket
	if not back then
		if not rim then return end
		back = view.top:CreateTexture(nil, "ARTWORK", nil, 1)
		back:SetTexture((Tokens.Texture("medLevelPlaque")))
		region.socket = back
		for _, method in ipairs(MIRROR) do
			hooksecurefunc(region, method, function(_, ...)
				if back.on then back[method](back, ...) end
			end)
		end
	end
	if rim then
		back:SetPoint("CENTER", region, "CENTER")
		back:SetSize(size + rim, size + rim)
	end
	back.on = rim ~= nil
	back:SetShown(back.on and region:IsShown())
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
	if not lane or view.spots and view.spots.marker then
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

local EXTRA_SPOT = {
	TOPLEFT = { "BOTTOMLEFT", "TOPLEFT", 0, 1 }, TOPRIGHT = { "BOTTOMRIGHT", "TOPRIGHT", 0, 1 },
	LEFT = { "RIGHT", "LEFT", -1, 0 }, RIGHT = { "LEFT", "RIGHT", 1, 0 },
}

local function PlaceExtra(view)
	local icon = view.extraIcon
	local s = view.s
	local own, x, y = s.eliteSize or 0, s.eliteX or 0, s.eliteY or 0
	icon:ClearAllPoints()
	local spot, corner = EXTRA_SPOT[s.happinessPosition or ""], view.spots and view.spots.elite
	if corner then
		icon:SetSize(corner.size, corner.size)
		icon:SetPoint("CENTER", view.parent, "TOPLEFT", Snap(view, corner.x + x), -Snap(view, corner.y - y))
	elseif spot then
		local size, gap = Snap(view, s.iconSize), Snap(view, ICON_GAP)
		x, y = spot[3] * gap, spot[4] * gap
		local g = view.geometry
		local medal, m, left = g and g.medal, g and g.marker, spot[2]:find("LEFT")
		if medal then
			x = x + Snap(view, left and math.min(0, medal.x) or math.max(0, medal.x + medal.w - g.glass.w))
			y = y + Snap(view, spot[4] > 0 and math.max(0, -medal.y) or 0)
		end
		if m then
			local w = g.glass.w
			local bx = (left and 0 or w) + x - (spot[1]:find("RIGHT") and size or 0)
			local by = spot[4] > 0 and -y - size or (g.glass.h - size) / 2
			if bx < m.x + m.w and m.x < bx + size and by < m.y + m.h and m.y < by + size then
				if spot[4] > 0 then
					y = gap - Snap(view, m.y)
				elseif left then
					x = Snap(view, m.x) - gap
				else
					x = Snap(view, m.x + m.w - w) + gap
				end
			end
		end
		icon:SetSize(size, size)
		icon:SetPoint(spot[1], view.parent, spot[2], x, y)
	elseif view.form == "row" then
		local size = Snap(view, own > 0 and own or s.iconSize)
		icon:SetSize(size, size)
		icon:SetPoint("BOTTOMRIGHT", view.parent, "TOPRIGHT", Snap(view, x), Snap(view, ICON_GAP + y))
	elseif own > 0 or x ~= 0 or y ~= 0 then
		local size = Snap(view, own > 0 and own or s.iconSize)
		icon:SetSize(size, size)
		icon:SetPoint("CENTER", view.icons.resting, "CENTER", Snap(view, x), Snap(view, y))
	else
		icon:SetAllPoints(view.icons.resting)
	end
end

local CORNERS = { { "TOPLEFT", 1, true }, { "TOPRIGHT", -1, true }, { "BOTTOMLEFT", 1, false }, { "BOTTOMRIGHT", -1, false } }
local PLACED = { "leader", "pvp", "combat", "elite", "marker" }
local LANES = { "name", "healthText", "healthSub", "powerText", "levelText", "caption", "cast" }
local BODY = { "health", "power", "name", "healthText", "healthSub", "powerText", "levelText", "caption" }
local TIMER_EM = 2.2

local function Crossed(view, g, r, down, row)
	local edge
	for i = 0, #LANES + 1 do
		local lane = i == 0 and row or i > #LANES and view.barRect or g[LANES[i]]
		if lane and lane.w > 0 and lane.h > 0 and Geometry.Overlaps(r, lane) then edge = down and math.max(edge or lane.y, lane.y + lane.h) or math.min(edge or lane.y, lane.y) end
	end
	return edge
end

local function TimerSize(s)
	local size = s.pvpTimerSize * K.Theme.FontScale()
	return TIMER_EM * size, size
end

local function Put(view, s, g, spots, key, x, dir, size, gap)
	local rim = view.rim or 0
	if rim > 0 and not s[key] and key ~= "marker" and key ~= "resting" then
		spots[key] = { x = x, y = g.glass.y, size = 0 }
		return x
	end
	local own = key == "marker" and g.marker.w or s[key .. "Size"] or 0
	local w, left, right = own > 0 and Snap(view, own) or size, 0, 0
	local place = key == "pvp" and view.kind == "player" and s.pvpTimer and s.pvpTimerPlace
	if place == "LEFT" or place == "RIGHT" then
		local room = Snap(view, TimerSize(s)) + gap
		if place == "LEFT" then left = room else right = room end
	end
	x = x + dir * (dir > 0 and left or right)
	spots[key] = { x = x + dir * (w + rim) / 2, y = g.glass.y - (rim > 0 and (w - rim) / 2 or 0), size = w }
	return x + dir * (w + rim + gap + (dir > 0 and right or left))
end

local function Corners(view, g, s, spots, dir, rowStart, size, gap)
	local panel, glass, m, rim = g.panel, g.glass, g.medal, view.rim or 0
	local lo, hi = panel.x, panel.x + panel.w
	if m and m.x + m.w / 2 < (lo + hi) / 2 then lo = math.max(lo, m.x + m.w) elseif m then hi = math.min(hi, m.x) end
	local high, low, bar, row = glass.y, glass.y, view.barRect, nil
	for _, key in ipairs(BODY) do
		local r = g[key]
		if r and r.w > 0 and r.h > 0 then low = math.max(low, r.y + r.h) end
	end
	if bar then high, low = math.min(high, bar.y), math.max(low, bar.y > glass.y and bar.y + bar.h or low) end
	for i = 1, #CORNERS do
		local name, side, top = unpack(CORNERS[dir < 0 and i < 3 and 3 - i or i])
		local start = side > 0 and lo + ICON_INSET or hi - ICON_INSET
		local x, edge, most, run = start, top and high or low, 0, {}
		for _, key in ipairs(PLACED) do
			if s[key .. "Place"] == name and (key == "marker" and g.marker or s[key] == true) then
				x = Put(view, s, g, spots, key, x, side, size, gap)
				run[#run + 1], most = spots[key], math.max(most, spots[key].size)
			end
		end
		if run[1] then
			local h = most + rim
			local box = { x = math.min(start, x), y = edge - (top and rim > 0 and h - rim or h / 2), w = math.abs(x - start), h = h }
			for _ = 0, #LANES + 1 do
				local hit = Crossed(view, g, box, not top, row)
				if not hit then break end
				box.y = top and hit - gap - h or hit + gap
			end
			for _, p in ipairs(run) do p.y = box.y + h / 2 end
		end
		if i == 1 then
			local from, h = run[1] and x or rowStart, 0
			x = from
			for _, key in ipairs(SLOTS) do
				if (s[key .. "Place"] or "") == "" or s[key] ~= true then
					x = Put(view, s, g, spots, key, x, dir, size, gap)
					h = math.max(h, spots[key].size)
				end
			end
			row = { x = math.min(from, x), y = glass.y - (rim > 0 and h or h / 2), w = math.abs(x - from), h = h + rim }
		end
	end
end

local function TimerSide(view, g, s, spots)
	local place = view.kind == "player" and s.pvpTimer and s.pvpTimerPlace or ""
	local p = spots.pvp
	if (place ~= "TOP" and place ~= "BOTTOM") or not p then return place end
	local w, h = TimerSize(s)
	local function At(up)
		return { x = p.x - w / 2, y = up and p.y - p.size / 2 - ICON_GAP - h or p.y + p.size / 2 + ICON_GAP, w = w, h = h }
	end
	local up = place == "TOP"
	if Crossed(view, g, At(up)) and not Crossed(view, g, At(not up)) then up = not up end
	return up and "TOP" or "BOTTOM"
end

function Indicators.Layout(view, g, s)
	local size = Snap(view, s.iconSize)
	local panel = g.panel
	local fromRight = s.portrait and s.portraitSide ~= "RIGHT" or not s.portrait
	local gap, dir = Snap(view, ICON_GAP), fromRight and -1 or 1
	view.iconsFromRight = fromRight
	local fresh = view.socketS ~= s
	if fresh then
		local layouts = K.Setup.Layouts
		view.socketS, view.rimSnap = s, Snap(view, Geometry.SLAB_FIT.socket)
		view.rowClear = (view.kind == "player" or view.kind == "target") and layouts.MEDALLIONS_UNITS.cast[1] / 2 - layouts.MEDALLIONS_RING / 2 - layouts.MEDALLIONS_UNITS.reach or 0
	end
	view.rim = g.form == "slab" and g.medal and s.fittedSlabs and view.rimSnap or nil
	local inset = ICON_INSET + (view.rim and view.rowClear or 0)
	local spots, x = {}, fromRight and (panel.x + panel.w - inset) or (panel.x + inset)
	if s.leaderPlace ~= "" or s.pvpPlace ~= "" or s.combatPlace ~= "" or s.markerPlace ~= "" or (s.elitePlace or "") ~= "" then Corners(view, g, s, spots, dir, x, size, gap) end
	for _, key in ipairs(SLOTS) do
		if not spots[key] then x = Put(view, s, g, spots, key, x, dir, size, gap) end
		local icon, p = view.icons[key], spots[key]
		icon:ClearAllPoints()
		icon:SetPoint("CENTER", view.parent, "TOPLEFT", Snap(view, p.x + (s[key .. "X"] or 0)), -Snap(view, p.y - (s[key .. "Y"] or 0)))
		local side = (key ~= "resting" or not s.resting) and p.size or 0
		icon:SetSize(side, side)
		if key == "resting" then
			local path = Settings.Font(view.kind, "level")
			Widgets.ApplyFont(icon, path, size, "OUTLINE")
		end
	end
	view.spots, view.timerSide = spots, TimerSide(view, g, s, spots)
	local spot = g.marker
	if spot then
		local marker, p = view.marker, spots.marker
		marker:SetSize(Snap(view, spot.w), Snap(view, spot.h))
		if p then
			marker:ClearAllPoints()
			marker:SetPoint("CENTER", view.parent, "TOPLEFT", Snap(view, p.x), -Snap(view, p.y))
		else
			PlaceMarker(view, spot.x)
		end
	end
	if fresh or view.rim ~= view.socketRim then
		view.socketRim = view.rim
		for _, key in ipairs(SLOTS) do
			Socket(view, view.icons[key], view.rim, spots[key].size)
		end
		Socket(view, view.marker, view.rim, spot and Snap(view, spot.w) or 0)
	end
	view.markerCut = false
	if view.extraIcon then
		PlaceExtra(view)
	end
	if view.threatText then view.threatText.where = nil end
	if view.pvpTimer then view.pvpTimer.where = nil end
	if view.icons.combat.tint then view.icons.combat.tint = true end
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

local GROUP_INSTANCE = { party = true, raid = true }

local function InGroupInstance()
	local kind = IsInInstance and select(2, IsInInstance())
	return not issecretvalue(kind) and GROUP_INSTANCE[kind] == true
end

local function PvPSeconds()
	local on = IsPVPTimerRunning and GetPVPTimer and IsPVPTimerRunning()
	if issecretvalue(on) or on ~= true then return nil end
	local ms = GetPVPTimer()
	return not issecretvalue(ms) and type(ms) == "number" and ms > 0 and math.ceil(ms / 1000) or nil
end

local TIMER_SIDE = { LEFT = { "RIGHT", "LEFT", -1, 0 }, RIGHT = { "LEFT", "RIGHT", 1, 0 }, TOP = { "BOTTOM", "TOP", 0, 1 }, BOTTOM = { "TOP", "BOTTOM", 0, -1 } }

function Indicators.PvPTimer(view, sample)
	local s, text = view.s, view.pvpTimer
	local on = view.kind == "player" and s.pvpTimer == true
	local left = on and sample
	if on and sample == nil and view.button then
		local shown = view.button:IsVisible()
		left = not issecretvalue(shown) and shown and view.icons.pvp:IsShown() and PvPSeconds()
	end
	if not left then
		if text and text:IsShown() then text:Hide() end
		if view.pvpTicker then view.pvpTicker:Cancel(); view.pvpTicker = nil end
		return
	end
	if not text then
		text = Widgets.FontString(view.top, "OVERLAY")
		view.pvpTimer = text
	end
	if not text.where then
		text.where = true
		Widgets.ApplyFont(text, (Settings.Font(view.kind, "level")), s.pvpTimerSize * K.Theme.FontScale(), "OUTLINE")
		text:SetTextColor(Tokens.Color("textEmphasis"))
		text:ClearAllPoints()
		local right, side = view.iconsFromRight, TIMER_SIDE[view.timerSide or ""]
		if side then
			text:SetPoint(side[1], view.icons.pvp, side[2], Snap(view, side[3] * ICON_GAP + s.pvpTimerX), Snap(view, side[4] * ICON_GAP + s.pvpTimerY))
		else
			text:SetPoint(right and "RIGHT" or "LEFT", view.icons.resting, "CENTER", Snap(view, (right and -ICON_GAP or ICON_GAP) + s.pvpTimerX) + (right and -0.5 or 0.5) * view.spots.resting.size, Snap(view, s.pvpTimerY))
		end
	end
	text:SetFormattedText("%d:%02d", math.floor(left / 60), left % 60)
	if not text:IsShown() then text:Show() end
	if not sample and not view.pvpTicker and C_Timer and C_Timer.NewTicker then
		view.pvpTicker = C_Timer.NewTicker(1, function() Indicators.PvPTimer(view) end)
	end
end

local function Badge(view, unit)
	local icon = view.icons.pvp
	if not view.s.pvp then
		icon:Hide()
		return
	end
	if view.s.pvpPlayersOnly then
		local player = UnitIsPlayer and UnitIsPlayer(unit)
		if issecretvalue(player) or player ~= true then
			icon:Hide()
			return
		end
	end
	local faction = UnitFactionGroup and UnitFactionGroup(unit)
	if view.s.pvpEnemyOnly then
		local own = UnitFactionGroup and UnitFactionGroup("player")
		if issecretvalue(faction) or issecretvalue(own) or faction == own then
			icon:Hide()
			return
		end
	end
	local ffa = UnitIsPVPFreeForAll and UnitIsPVPFreeForAll(unit)
	if not issecretvalue(ffa) and ffa == true then
		icon:SetAtlas(ATLAS.ffa)
		icon:Show()
		return
	end
	local flagged = UnitIsPVP and UnitIsPVP(unit)
	local atlas = not issecretvalue(faction) and type(faction) == "string" and ATLAS[faction]
	if issecretvalue(flagged) or flagged ~= true or not atlas then
		icon:Hide()
		return
	end
	icon:SetAtlas(atlas)
	icon:Show()
end

function Indicators.PvP(view, unit)
	Badge(view, unit)
	if view.kind == "player" then Indicators.PvPTimer(view) end
end

function Indicators.Tint(icon, file)
	local key = not issecretvalue(file) and type(file) == "string" and file or false
	if (icon.tint or false) == key then return end
	icon.tint = key
	icon:SetDesaturated(key ~= false)
	if key then icon:SetVertexColor(K.Theme.ClassColorForWidget(key)) else icon:SetVertexColor(Tokens.Color("white")) end
end

function Indicators.Combat(view, unit)
	local icon = view.icons.combat
	if not view.s.combat or not UnitAffectingCombat then
		icon:Hide()
		return
	end
	Shown(icon, UnitAffectingCombat(unit))
	Indicators.Tint(icon, view.s.combatClassColor and UnitClass and select(2, UnitClass(unit)))
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

local THREAT_PLACE = { RIGHT = { "RIGHT", "RIGHT", -1 }, LEFT = { "LEFT", "LEFT", 1 }, CENTER = { "CENTER", "CENTER", 0 }, OUTRIGHT = { "LEFT", "RIGHT", 1 }, OUTLEFT = { "RIGHT", "LEFT", -1 } }

local function NonTank()
	local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
	return not issecretvalue(role) and (role == "DAMAGER" or role == "HEALER")
end

function Indicators.ThreatText(view, unit, sample)
	local s, text = view.s, view.threatText
	local percent, status = sample, sample and 3
	if s.threatPercent and sample == nil and UnitDetailedThreatSituation and UnitExists(unit) then
		local _, state, scaled = UnitDetailedThreatSituation("player", unit)
		if not issecretvalue(scaled) and type(scaled) == "number" and scaled > 0 then
			percent, status = scaled, not issecretvalue(state) and state or nil
		end
	end
	if not (s.threatPercent and percent) then
		if text and text:IsShown() then text:Hide() end
		return
	end
	if not text then
		text = Widgets.FontString(view.top, "OVERLAY")
		view.threatText = text
	end
	local where = s.threatPercentPosition
	if text.where ~= where then
		text.where, text.tone = where, nil
		local path, size, flags = Settings.Font(view.kind, "level")
		Widgets.ApplyFont(text, path, size, flags)
		local place = THREAT_PLACE[where] or THREAT_PLACE.OUTLEFT
		text:ClearAllPoints()
		text:SetPoint(place[1], view.health, place[2], Snap(view, place[3] * ICON_INSET), 0)
	end
	local tone = s.threatPercentColor and status or false
	if text.tone ~= tone then
		text.tone = tone
		local r, g, b
		if tone then r, g, b = K.Theme.ThreatColor(tone) end
		if not r then r, g, b = Tokens.Color("textEmphasis") end
		text:SetTextColor(r, g, b)
	end
	if text.percent ~= percent then
		text.percent = percent
		text:SetFormattedText("%.0f%%", percent)
	end
	if not text:IsShown() then text:Show() end
end

function Indicators.Threat(view, unit)
	local glow = view.glowFrame
	if view.kind == "target" or view.kind == "focus" then Indicators.ThreatText(view, unit) end
	if not view.s.threat or view.kind == "player" and view.s.threatNonTank and not (NonTank() and InGroupInstance()) then
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

local function ExtraAtlas(view, unit, sample)
	local s = view.s
	if view.kind == "pet" then
		local info = C_PetInfo
		if not s.happiness or not (sample or info and info.GetPetHappiness) then
			return nil
		end
		local hunter = HasPetUI and select(2, HasPetUI())
		local mood = sample or not issecretvalue(hunter) and hunter and info.GetPetHappiness()
		return not issecretvalue(mood) and MOOD[mood] or nil
	end
	if not s.elite or view.kind == "player" or not s.eliteInstances and InGroupInstance() then
		return nil
	end
	local rank = sample or UnitClassification and UnitClassification(unit)
	return not issecretvalue(rank) and RANK[rank] or nil
end

function Indicators.Extra(view, unit, sample)
	local atlas, icon = ExtraAtlas(view, unit, sample), view.extraIcon
	if not atlas then
		if icon and icon:IsShown() then
			icon:Hide()
		end
		return
	end
	if not icon then
		icon = view.top:CreateTexture(nil, "OVERLAY")
		view.extraIcon = icon
		PlaceExtra(view)
	end
	if icon.mark ~= atlas then
		icon.mark = atlas
		icon:SetAtlas(atlas)
	end
	if not icon:IsShown() then icon:Show() end
end

function Indicators.Status(view, unit)
	Indicators.Leader(view, unit)
	Indicators.Role(view, unit)
	Indicators.PvP(view, unit)
	Indicators.Combat(view, unit)
	Indicators.Resting(view, unit)
	Indicators.Extra(view, unit)
end

function Indicators.Update(view, unit)
	Indicators.Marker(view, unit)
	Indicators.Status(view, unit)
	Indicators.Threat(view, unit)
end
