-- Indicators.lua: role, leader, raid marker and ready-check icons and the threat glow round each group frame's edge, secret-safe.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Style, Unit, Button, Frames = ns.Settings, ns.Style, ns.Unit, ns.Button, ns.Frames

local Indicators = {}
ns.Indicators = Indicators

local LEADER_ATLAS = "UI-HUD-UnitFrame-Player-Group-LeaderIcon"
local ASSIST_TEXTURE = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
local MARKER_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local MARKER_ROWS, MARKER_COLUMNS = 4, 4
local READY_HOLD = 6
local READY_SHARE = 1.6
local READY_LEVEL = 10
local THREAT_SPREAD = { party = "gapSmall", raid = "gapSmall" }
local CENTRE_PIECE = 5
local ROLE_OPTIONS = { displayRoleIcon = true, displayRaidRoleIcon = true }
local PIP_COLORS = { TANK = "rare", HEALER = "friendly", DAMAGER = "hostile" }

local issecretvalue = issecretvalue or function()
	return false
end

local BADGE_SUBLEVEL = 2
local BEHIND_SUBLEVEL = 5

local function Plain(v)
	return not issecretvalue(v) and type(v) == "number"
end

local readyActive = false
local readyFinished = false
local readyToken = 0

local function HasAtlas(name)
	local api = C_Texture and C_Texture.GetAtlasInfo
	if type(api) ~= "function" then
		return false
	end
	local ok, info = pcall(api, name)
	return ok and info ~= nil
end

local function Build(f)
	local layer = f.text
	f.role = layer:CreateTexture(nil, "OVERLAY")
	f.pipEdge = layer:CreateTexture(nil, "OVERLAY")
	f.pipFill = layer:CreateTexture(nil, "OVERLAY", nil, 1)
	for _, pip in ipairs({ f.pipEdge, f.pipFill }) do
		pip:SetTexture((Tokens.Texture("diamond")))
		pip:Hide()
	end
	f.pipEdge:SetVertexColor(Tokens.Color("black"))
	f.leader = layer:CreateTexture(nil, "OVERLAY", nil, BADGE_SUBLEVEL)
	if HasAtlas(LEADER_ATLAS) then
		f.leader:SetAtlas(LEADER_ATLAS)
	else
		f.leader:SetTexture(ASSIST_TEXTURE)
		Style.LogOnce("leaderAtlas", "the leader atlas is missing; the leader icon uses the assistant texture")
	end
	f.assist = layer:CreateTexture(nil, "OVERLAY")
	f.assist:SetTexture(ASSIST_TEXTURE)
	f.marker = layer:CreateTexture(nil, "OVERLAY")
	f.marker:SetTexture(MARKER_TEXTURE)
	f.marker:Hide()
	f.readyLayer = CreateFrame("Frame", nil, f)
	f.readyLayer:SetAllPoints(f)
	f.readyLayer:SetFrameLevel(f:GetFrameLevel() + READY_LEVEL)
	f.ready = f.readyLayer:CreateTexture(nil, "OVERLAY")
	f.ready:Hide()
	f.statusIcons = {}
	for _, name in ipairs({ "afk", "summon", "resurrection" }) do
		local icon = f.readyLayer:CreateTexture(nil, "ARTWORK")
		icon:SetAlpha(0)
		f.statusIcons[name] = icon
	end
	f.statusIcons.afk:SetTexture("Interface\\FriendsFrame\\StatusIcon-Away")
	f.statusIcons.summon:SetAtlas("RaidFrame-Icon-SummonPending")
	f.statusIcons.resurrection:SetAtlas("RaidFrame-Icon-Rez")
	f.threat = CreateFrame("Frame", nil, f)
	f.threat:SetAllPoints(f)
	f.threat:SetFrameLevel(f:GetFrameLevel())
	f.threatGlow = Widgets.Glow(f.threat, { kind = "selection", spread = Tokens.Size(THREAT_SPREAD[f.kind] or "gapSmall") })
	f.threatGlow.slice[CENTRE_PIECE]:Hide()
	f.threatGlow:SetIntensity(1)
	f.threat:Hide()
	f.threatShape = layer:CreateTexture(nil, "OVERLAY")
	Widgets.Point(f.threatShape, "BOTTOMLEFT", f, "BOTTOMLEFT", 2, 2)
	f.threatShape:Hide()
	f.roleElements = { roleIcon = f.role, unit = nil, optionTable = ROLE_OPTIONS }
end
Button.built[#Button.built + 1] = Build

local Pin = Style.Pin

local function PlaceIcon(f, icon, rect, size, x, y)
	icon:ClearAllPoints()
	icon:SetSize(size, size)
	icon:SetPoint("TOPLEFT", f, "TOPLEFT", Widgets.Snap(f, rect.left + (x or 0)), -Widgets.Snap(f, rect.top - (y or 0)))
end

local function Layout(f, parts, k)
	local icons = parts.icons
	local size = Widgets.Snap(f, icons.size)
	local health, cfg = parts.health, Settings.current.icons
	local roleRect = cfg.rolePlace == "AUTO" and icons.role or nil
	f.roleInRing = icons.roleInRing == true and roleRect ~= nil
	if f.roleInRing then
		f.role:Hide()
	end
	f.pipped = icons.pip == true
	local roleSize = f.pipped and Widgets.Snap(f, icons.role.width) or size
	if roleRect then
		PlaceIcon(f, f.role, roleRect, roleSize, cfg.roleX, cfg.roleY)
		PlaceIcon(f, f.pipEdge, roleRect, roleSize, cfg.roleX, cfg.roleY)
	else
		roleSize = Widgets.Snap(f, math.min(roleSize, health.height))
		Pin(f, f.role, cfg.rolePlace, roleSize, cfg.roleX, cfg.roleY)
		Pin(f, f.pipEdge, cfg.rolePlace, roleSize, cfg.roleX, cfg.roleY)
	end
	local edge = Widgets.Border(f)
	f.pipFill:ClearAllPoints()
	f.pipFill:SetPoint("TOPLEFT", f.pipEdge, "TOPLEFT", edge, -edge)
	f.pipFill:SetPoint("BOTTOMRIGHT", f.pipEdge, "BOTTOMRIGHT", -edge, edge)
	if not f.pipped then
		f.pipEdge:Hide()
		f.pipFill:Hide()
	end
	PlaceIcon(f, f.leader, icons.leader, icons.badge and Widgets.Snap(f, icons.leader.width) or size, cfg.leaderX, cfg.leaderY)
	local markerSize = f.pipped and Widgets.Snap(f, icons.marker.width) or size
	PlaceIcon(f, f.marker, icons.marker, markerSize)
	f.assist:ClearAllPoints()
	f.assist:SetSize(size, size)
	f.assist:SetPoint("CENTER", f.leader, "CENTER", 0, 0)
	local own = cfg.readySize > 0 and Widgets.Snap(f, math.min(cfg.readySize, health.height)) or nil
	local ready, status = own or Widgets.Snap(f, math.min(health.height, k.iconSize * READY_SHARE)), own or 14
	f.ready:ClearAllPoints()
	f.ready:SetSize(ready, ready)
	f.ready:SetPoint("CENTER", f, "TOPLEFT", Widgets.Snap(f, health.left + health.width / 2), -Widgets.Snap(f, health.top + health.height / 2))
	local statusLeft, statusTop = health.left + health.width / 2 - status / 2, health.top + health.height / 2 - status / 2
	if parts.tidyLanes then
		local laneSize = f.kind == "party" and 14 or 10
		local portrait = parts.portrait
		local left = portrait and portrait.left or health.left
		local top = portrait and portrait.top + portrait.height - laneSize or health.top + health.height - laneSize
		local heal, tile, block = not portrait and parts.healRow and not parts.healRow.outside and parts.healRow, parts.tile, parts.block
		if tile and tile.stacked then
			local px = K.Scale.Pixel(1) / Widgets.ScaleFactor(f)
			top = math.max(top, math.ceil((Widgets.Snap(f, health.top + tile.inset) + 1.2 * Widgets.FontSize(f.name, f.nameFit.size)) / px) * px)
		end
		if heal and heal.top < top + laneSize then
			local _, count, healSize, spacing = ns.Auras.HealIcons(f, k)
			left = heal.left + ns.Geometry.Line(count, healSize, spacing) + 4
		end
		local stop = portrait and portrait.left + portrait.width or block and block.top < top + laneSize and block.left - 4 or health.left + health.width
		if not portrait and top < health.top or stop - left < 2 * laneSize + 4 then
			local bottom = portrait and portrait.top + portrait.height or f.height
			local crown = portrait and icons.leader.top + size or Widgets.Snap(f, math.min(laneSize, bottom / 2))
			markerSize = Widgets.Snap(f, math.min(laneSize, bottom - crown))
			PlaceIcon(f, f.marker, { left = 0, top = bottom - markerSize }, markerSize)
			if not portrait then
				PlaceIcon(f, f.leader, { left = 0, top = 0 }, crown, cfg.leaderX, cfg.leaderY)
			end
		else
			if portrait or left + 3 * laneSize + 8 <= stop then
				local lane = own or laneSize
				local rect = { left = left, top = top + laneSize - lane }
				statusLeft, statusTop = left + (lane - status) / 2, rect.top + (lane - status) / 2
				PlaceIcon(f, f.ready, rect, Widgets.Snap(f, lane))
				left = left + laneSize + 4
			end
			local rect = { left = left, top = top }
			markerSize = Widgets.Snap(f, laneSize)
			PlaceIcon(f, f.marker, rect, markerSize)
			if not portrait then
				rect.left = left + laneSize + 4
				PlaceIcon(f, f.leader, rect, markerSize, cfg.leaderX, cfg.leaderY)
			end
		end
	end
	for _, icon in pairs(f.statusIcons) do
		Widgets.Size(icon, status, status)
		icon:ClearAllPoints()
		Widgets.Point(icon, "TOPLEFT", f, "TOPLEFT", statusLeft, -statusTop)
		if cfg.readyPlace ~= "AUTO" then Pin(f, icon, cfg.readyPlace, nil, cfg.readyX, cfg.readyY) end
	end
	if cfg.readyPlace ~= "AUTO" then
		Pin(f, f.ready, cfg.readyPlace, nil, cfg.readyX, cfg.readyY)
	end
	if cfg.markerPlace ~= "AUTO" then
		Pin(f, f.marker, cfg.markerPlace, markerSize, cfg.markerX, cfg.markerY)
	end
	if cfg.roleText and not f.roleLetter then
		f.roleLetter = Widgets.FontString(f.text, "OVERLAY")
		f.roleLetter:SetJustifyH("CENTER")
		f.roleLetter.behind = false
	end
	if (f.roleBehind or false) ~= cfg.roleBehind or f.roleLetter and f.roleLetter.behind ~= cfg.roleBehind then
		local behind = cfg.roleBehind
		f.roleBehind = behind
		local layer, base = behind and "ARTWORK" or "OVERLAY", behind and BEHIND_SUBLEVEL or 0
		f.role:SetDrawLayer(layer, base)
		f.pipEdge:SetDrawLayer(layer, base)
		f.pipFill:SetDrawLayer(layer, base + 1)
		if f.roleLetter then
			f.roleLetter:SetDrawLayer(layer, behind and base + 1 or 0)
			f.roleLetter.behind = behind
		end
	end
	if f.roleLetter then
		f.roleLetter:ClearAllPoints()
		if roleRect then
			f.roleLetter:SetPoint("CENTER", f, "TOPLEFT", Widgets.Snap(f, roleRect.left + roleRect.width / 2 + cfg.roleX), -Widgets.Snap(f, roleRect.top + roleRect.height / 2 - cfg.roleY))
		else
			f.roleLetter:SetPoint("CENTER", f.role, "CENTER", 0, 0)
		end
		Style.SetFont(f.roleLetter, Settings.current.text.healthFont, math.max(6, roleRect and roleRect.height or roleSize), "OUTLINE")
	end
	if f.combatIcon or cfg.combat then
		f.combatIcon = f.combatIcon or f.text:CreateTexture(nil, "OVERLAY")
		Pin(f, f.combatIcon, cfg.combatPlace, Widgets.Snap(f, math.min(cfg.combatSize, health.height)), cfg.combatX, cfg.combatY)
	end
end
Style.appliers[#Style.appliers + 1] = Layout

local function UnitRole(f)
	local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(f.unit)
	if issecretvalue(role) or type(role) ~= "string" or role == "NONE" or not GetMicroIconForRole then
		f.role:Hide()
		return
	end
	f.role:SetAtlas(GetMicroIconForRole(role))
	f.role:Show()
end

local function ShowPip(f, role)
	if not Settings.current.icons.roleShapes then
		f.role:SetVertexColor(Tokens.Color("white"))
		local token = PIP_COLORS[role]
		f.pipEdge:SetShown(token ~= nil)
		f.pipFill:SetShown(token ~= nil)
		if token then
			if f.parts and f.parts.tidyLanes then token = "steelLit" end
			f.pipFill:SetVertexColor(Tokens.Color(token))
		end
		return
	end
	f.pipEdge:Hide()
	f.pipFill:Hide()
	local atlas = PIP_COLORS[role] and GetMicroIconForRole and GetMicroIconForRole(role)
	f.role:SetShown(atlas ~= nil)
	if atlas then f.role:SetAtlas(atlas); f.role:SetVertexColor(Tokens.Color("steelLit")) end
end

local function Fighting()
	local fighting = UnitAffectingCombat and UnitAffectingCombat("player")
	return not issecretvalue(fighting) and fighting == true
end

local ROLE_KEYS = { TANK = "roleTank", HEALER = "roleHealer", DAMAGER = "roleDamager" }
local function RoleHidden(f)
	local icons = Settings.current.icons
	if not icons.roleInCombat and not f.sample and Fighting() then
		return true
	elseif icons.roleTank and icons.roleHealer and icons.roleDamager then
		return false
	end
	local role = f.sample and f.sample.role
	if not f.sample and UnitGroupRolesAssigned then role = UnitGroupRolesAssigned(f.unit) end
	return not issecretvalue(role) and ROLE_KEYS[role] ~= nil and not icons[ROLE_KEYS[role]]
end

local function Lettered(f, role)
	local letter = f.roleLetter
	if not (letter and Settings.current.icons.roleText) or issecretvalue(role) or not PIP_COLORS[role] then
		return false
	end
	f.role:Hide()
	letter:SetText(Style.ROLE_LETTERS[role])
	letter:SetTextColor(Tokens.Color(PIP_COLORS[role]))
	letter:Show()
	return true
end

local function Role(f)
	ShowPip(f, nil)
	if f.roleLetter then f.roleLetter:Hide() end
	local icons = Settings.current.icons
	if not icons.role or f.showRoleRing or RoleHidden(f) then
		f.role:Hide()
		return
	end
	local role = (f.pipped or icons.roleText) and UnitGroupRolesAssigned and UnitGroupRolesAssigned(f.unit)
	if Lettered(f, role) or f.roleInRing then
		return
	end
	if f.pipped and not issecretvalue(role) then
		f.role:Hide()
		ShowPip(f, role)
		return
	end
	local util = UnitFrameUtil
	if util and type(util.UpdateUnitFrameRoleIcon) == "function" then
		f.roleElements.unit = f.unit
		local ok = pcall(util.UpdateUnitFrameRoleIcon, f.roleElements)
		if ok then
			return
		end
		Style.LogOnce("roleUtil", "UnitFrameUtil.UpdateUnitFrameRoleIcon failed; role icons read UnitGroupRolesAssigned")
	end
	UnitRole(f)
end
Indicators.Role = Role

local function FromBoolean(region, value)
	if region.SetAlphaFromBoolean then
		region:SetAlphaFromBoolean(value, 1, 0)
	elseif not issecretvalue(value) then
		region:SetAlpha(value and 1 or 0)
	else
		region:SetAlpha(0)
	end
end

local function Leader(f)
	local icons = Settings.current.icons
	local on = icons.leader and (icons.leaderInCombat or f.sample ~= nil or not Fighting())
	f.leader:SetShown(on)
	f.assist:SetShown(on)
	if not on then
		return
	end
	FromBoolean(f.leader, UnitIsGroupLeader(f.unit))
	if UnitIsGroupAssistant then
		FromBoolean(f.assist, UnitIsGroupAssistant(f.unit))
	else
		f.assist:SetAlpha(0)
	end
end

local function Marker(f)
	if not Settings.current.icons.marker or not GetRaidTargetIndex then
		f.marker:Hide()
		Style.SetMarked(f, false)
		return
	end
	local index = GetRaidTargetIndex(f.unit)
	if type(index) ~= "number" then
		f.marker:Hide()
		Style.SetMarked(f, false)
		return
	end
	f.marker:SetSpriteSheetCell(index, MARKER_ROWS, MARKER_COLUMNS)
	f.marker:Show()
	Style.SetMarked(f, true)
end

local READY_ATLAS = {
	ready = function()
		return READY_CHECK_READY_TEXTURE
	end,
	notready = function()
		return READY_CHECK_NOT_READY_TEXTURE
	end,
	waiting = function()
		return READY_CHECK_WAITING_TEXTURE
	end,
}

local function ReadStatus(fn, unit)
	if type(fn) == "function" then return fn(unit) end
	return false
end

local function Status(f)
	local icons, unit = f.statusIcons, f.unit
	if not icons then return end
	if readyActive or not Settings.current.icons.statuses then
		for _, icon in pairs(icons) do icon:SetAlpha(0) end
		return
	end
	local api = C_IncomingSummon
	local settings = Settings.current.icons
	local afk, resurrection, summon = false, false, false
	if settings.afk then afk = ReadStatus(UnitIsAFK, unit) end
	if settings.resurrection then resurrection = ReadStatus(UnitHasIncomingResurrection, unit) end
	if settings.summon then summon = ReadStatus(api and api.HasIncomingSummon, unit) end
	FromBoolean(icons.afk, afk)
	FromBoolean(icons.resurrection, resurrection)
	FromBoolean(icons.summon, summon)
	if icons.afk.SetAlphaFromBoolean then
		icons.afk:SetAlphaFromBoolean(summon, 0, icons.afk:GetAlpha())
		icons.afk:SetAlphaFromBoolean(resurrection, 0, icons.afk:GetAlpha())
		icons.summon:SetAlphaFromBoolean(resurrection, 0, icons.summon:GetAlpha())
	end
end
Indicators.Status = Status

local function Ready(f)
	Status(f)
	if not readyActive or not Settings.current.icons.readyCheck or not GetReadyCheckStatus then
		f.ready:Hide()
		return
	end
	local status = GetReadyCheckStatus(f.unit)
	if readyFinished and status == "waiting" then
		status = "notready"
	end
	local atlas = not issecretvalue(status) and type(status) == "string" and READY_ATLAS[status] and READY_ATLAS[status]()
	if type(atlas) ~= "string" then
		f.ready:Hide()
		return
	end
	f.ready:SetAtlas(atlas)
	f.ready:Show()
end

local function Edge(f, r, g, b)
	if not (r or f.threatEdge) then
		return
	end
	if r then
		f.edgeRGB = f.edgeRGB or {}
		f.edgeRGB[1], f.edgeRGB[2], f.edgeRGB[3] = r, g, b
	end
	f.threatEdge = r and f.edgeRGB or nil
	Style.PaintEdge(f)
end

local function ThreatOn(f, r, g, b)
	local edge = Settings.current.threat.edge and not f.tileless
	f.threatGlow:SetColorRGB(r, g, b)
	f.threat:SetShown(not edge)
	Edge(f, edge and r, g, b)
end

local function NoThreat(f)
	f.threat:Hide()
	Edge(f)
end

local function Threat(f)
	f.threatShape:Hide()
	if not Settings.current.threat.enabled or not UnitThreatSituation then
		return NoThreat(f)
	end
	local status = UnitThreatSituation(f.unit)
	if issecretvalue(status) or type(status) ~= "number" or status < 1 then
		return NoThreat(f)
	end
	local r, g, b = K.Theme.ThreatColor(status)
	if not Plain(r) or not Plain(g) or not Plain(b) then
		return NoThreat(f)
	end
	if Settings.current.threat.shapes then
		if status == 2 then
			f.threatShape:SetTexture((Tokens.Texture("diamond")))
			f.threatShape:SetTexCoord(0, 1, 0, 0.5)
		else
			f.threatShape:SetColorTexture(Tokens.Color("white"))
			f.threatShape:SetTexCoord(0, 1, 0, 1)
		end
		Widgets.Size(f.threatShape, status == 1 and 2 or 8, 8)
		f.threatShape:SetVertexColor(r, g, b)
		f.threatShape:Show()
	end
	ThreatOn(f, r, g, b)
end

local COMBAT_ATLAS = "UI-HUD-UnitFrame-Player-CombatIcon"

local function Combat(f)
	local icon = f.combatIcon
	if not icon or not Settings.current.icons.combat then
		return
	end
	if f.sample then
		icon:SetAlpha(f.sample.combat and 1 or 0)
	elseif UnitAffectingCombat then
		FromBoolean(icon, UnitAffectingCombat(f.unit))
	else
		icon:SetAlpha(0)
	end
end

local function DressCombat(f)
	local icon = f.combatIcon
	if not icon then
		return
	end
	if icon.atlas == nil then
		icon.atlas = HasAtlas(COMBAT_ATLAS)
		if icon.atlas then
			icon:SetAtlas(COMBAT_ATLAS)
		else
			Style.LogOnce("combatAtlas", "the combat icon atlas is missing; the combat icon stays hidden")
		end
	end
	local cfg = Settings.current.icons
	icon:SetShown(cfg.combat and icon.atlas)
	if not cfg.combat then
		return
	end
	if cfg.combatClass then
		local class = f.sample and f.sample.class
		if not f.sample then class = select(2, UnitClass(f.unit)) end
		icon:SetVertexColor(Unit.ClassColor(class))
	else
		icon:SetVertexColor(Tokens.Color("white"))
	end
	Combat(f)
end

local function Refresh(f)
	Role(f)
	DressCombat(f)
	Leader(f)
	Marker(f)
	Ready(f)
	Threat(f)
end
Unit.extra[#Unit.extra + 1] = Refresh
Unit.Chain("UNIT_THREAT_SITUATION_UPDATE", Threat)
Unit.Chain("UNIT_FLAGS", Combat)

local function Each(fn)
	local function Visit(f)
		if f.unit then
			fn(f)
		end
	end
	return function()
		Unit.ForEach(Visit)
	end
end

local EachReady = Each(Ready)

local function ReadyStart()
	readyActive = true
	readyFinished = false
	readyToken = readyToken + 1
	EachReady()
end

local function ReadyFinished()
	readyFinished = true
	EachReady()
	readyToken = readyToken + 1
	local token = readyToken
	C_Timer.After(READY_HOLD, function()
		if token == readyToken then
			readyActive = false
			readyFinished = false
			EachReady()
		end
	end)
end

local function PaintSample(f, sample)
	local icons = Settings.current.icons
	local role = icons.role and not RoleHidden(f) and sample.role or nil
	local atlas = not f.roleInRing and role and GetMicroIconForRole and GetMicroIconForRole(role)
	ShowPip(f, nil)
	if f.roleLetter then f.roleLetter:Hide() end
	local lettered = not f.showRoleRing and Lettered(f, role)
	if f.pipped and not lettered then
		f.role:Hide()
		ShowPip(f, role)
	elseif not lettered then
		if type(atlas) == "string" then f.role:SetAtlas(atlas) end
		f.role:SetShown(type(atlas) == "string")
	end
	f.leader:SetShown(icons.leader)
	f.leader:SetAlpha(sample.leader and 1 or 0)
	f.assist:SetAlpha(0)
	if icons.marker and sample.marker then
		f.marker:SetSpriteSheetCell(sample.marker, MARKER_ROWS, MARKER_COLUMNS)
		f.marker:Show()
		Style.SetMarked(f, true)
	else
		f.marker:Hide()
		Style.SetMarked(f, false)
	end
	local ready = icons.readyCheck and (icons.readyPlace ~= "AUTO" or icons.readySize > 0) and READY_ATLAS.ready()
	if type(ready) == "string" then f.ready:SetAtlas(ready) end
	f.ready:SetShown(type(ready) == "string")
	DressCombat(f)
	local threat = Settings.current.threat.enabled and sample.threat
	local r, g, b
	if threat then
		r, g, b = K.Theme.ThreatColor(threat)
	end
	if r then
		ThreatOn(f, r, g, b)
	else
		NoThreat(f)
	end
end
Style.painters[#Style.painters + 1] = PaintSample

local events = Frames.events
local EachRole, EachLeader = Each(Role), Each(Leader)
events[#events + 1] = { event = "RAID_TARGET_UPDATE", fn = Each(Marker) }
events[#events + 1] = { event = "PARTY_LEADER_CHANGED", fn = EachLeader }
events[#events + 1] = { event = "PLAYER_ROLES_ASSIGNED", fn = EachRole }
events[#events + 1] = { event = "READY_CHECK", fn = ReadyStart }
events[#events + 1] = { event = "READY_CHECK_CONFIRM", fn = EachReady }
events[#events + 1] = { event = "READY_CHECK_FINISHED", fn = ReadyFinished }
for _, event in ipairs({ "INCOMING_RESURRECT_CHANGED", "INCOMING_SUMMON_CHANGED", "PLAYER_FLAGS_CHANGED" }) do
	events[#events + 1] = { event = event, fn = Each(Status) }
end
local EachCombat = Each(Combat)
local function CombatChanged()
	local icons = Settings.current.icons
	if not icons.roleInCombat then EachRole() end
	if not icons.leaderInCombat then EachLeader() end
	if icons.combat then EachCombat() end
end
events[#events + 1] = { event = "PLAYER_REGEN_DISABLED", fn = CombatChanged }
events[#events + 1] = { event = "PLAYER_REGEN_ENABLED", fn = CombatChanged }
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "ENCOUNTER_START" }) do
	events[#events + 1] = { event = event, fn = Button.Starting }
end
