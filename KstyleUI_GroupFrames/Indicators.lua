-- Indicators.lua: role, leader, raid marker and ready-check icons and the threat glow on each group frame, secret-safe.
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
local THREAT_SPREAD = { party = "gapMedium", raid = "gapSmall" }
local ROLE_OPTIONS = { displayRoleIcon = true, displayRaidRoleIcon = true }

local issecretvalue = issecretvalue or function()
	return false
end

local function Plain(v)
	return not issecretvalue(v) and type(v) == "number"
end

local readyActive = false
local readyFinished = false
local readyToken = 0

local function Build(f)
	local layer = f.text
	f.role = layer:CreateTexture(nil, "OVERLAY")
	f.leader = layer:CreateTexture(nil, "OVERLAY")
	if not f.leader:SetAtlas(LEADER_ATLAS) then
		f.leader:SetTexture(ASSIST_TEXTURE)
		Style.LogOnce("leaderAtlas", "the leader atlas is missing; the leader icon uses the assistant texture")
	end
	f.assist = layer:CreateTexture(nil, "OVERLAY")
	f.assist:SetTexture(ASSIST_TEXTURE)
	f.marker = layer:CreateTexture(nil, "OVERLAY")
	f.marker:SetTexture(MARKER_TEXTURE)
	f.marker:Hide()
	f.ready = layer:CreateTexture(nil, "OVERLAY")
	f.ready:Hide()
	f.threat = CreateFrame("Frame", nil, f)
	f.threat:SetAllPoints(f)
	f.threat:SetFrameLevel(f:GetFrameLevel())
	f.threatGlow = Widgets.Glow(f.threat, { kind = "selection", spread = Tokens.Size(THREAT_SPREAD[f.kind] or "gapSmall") })
	f.threatGlow:SetIntensity(1)
	f.threat:Hide()
	f.roleElements = { roleIcon = f.role, unit = nil, optionTable = ROLE_OPTIONS }
end
Button.built[#Button.built + 1] = Build

local function Layout(f, parts, k)
	local size = Widgets.Snap(f, k.iconSize)
	local gap = Widgets.Snap(f, Tokens.Size("gapTiny"))
	local half = Widgets.Snap(f, k.iconSize / 2)
	for _, icon in ipairs({ f.role, f.leader, f.assist, f.marker }) do
		icon:ClearAllPoints()
		icon:SetSize(size, size)
	end
	local health = parts.health
	f.role:SetPoint("TOPRIGHT", f, "TOPRIGHT", -gap, -gap)
	local leftEdge = parts.portrait and 0 or gap
	f.leader:SetPoint("CENTER", f, "TOPLEFT", leftEdge + half, -half + gap)
	f.assist:SetPoint("CENTER", f.leader, "CENTER", 0, 0)
	f.marker:SetPoint("CENTER", f, "TOP", 0, 0)
	local ready = Widgets.Snap(f, math.min(health.height, k.iconSize * READY_SHARE))
	f.ready:ClearAllPoints()
	f.ready:SetSize(ready, ready)
	f.ready:SetPoint("CENTER", f, "TOPLEFT", Widgets.Snap(f, health.left + health.width / 2), -Widgets.Snap(f, health.top + health.height / 2))
end
Style.appliers[#Style.appliers + 1] = Layout

local function UnitRole(f)
	local role = UnitGroupRolesAssigned(f.unit)
	if issecretvalue(role) or type(role) ~= "string" or role == "NONE" or not GetMicroIconForRole then
		f.role:Hide()
		return
	end
	f.role:SetAtlas(GetMicroIconForRole(role))
	f.role:Show()
end

local function Role(f)
	if not Settings.current.icons.role then
		f.role:Hide()
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
	local on = Settings.current.icons.leader
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
		return
	end
	local index = GetRaidTargetIndex(f.unit)
	if type(index) ~= "number" then
		f.marker:Hide()
		return
	end
	f.marker:SetSpriteSheetCell(index, MARKER_ROWS, MARKER_COLUMNS)
	f.marker:Show()
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

local function Ready(f)
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

local function Threat(f)
	if not Settings.current.threat.enabled or not UnitThreatSituation then
		f.threat:Hide()
		return
	end
	local status = UnitThreatSituation(f.unit)
	if issecretvalue(status) or type(status) ~= "number" or status < 1 then
		f.threat:Hide()
		return
	end
	local r, g, b = K.Theme.ThreatColor(status)
	if not Plain(r) or not Plain(g) or not Plain(b) then
		f.threat:Hide()
		return
	end
	f.threatGlow:SetColorRGB(r, g, b)
	f.threat:Show()
end

local function Refresh(f)
	Role(f)
	Leader(f)
	Marker(f)
	Ready(f)
	Threat(f)
end
Unit.extra[#Unit.extra + 1] = Refresh
Unit.Chain("UNIT_THREAT_SITUATION_UPDATE", Threat)

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
	local atlas = icons.role and sample.role and GetMicroIconForRole and GetMicroIconForRole(sample.role)
	if type(atlas) == "string" then
		f.role:SetAtlas(atlas)
		f.role:Show()
	else
		f.role:Hide()
	end
	f.leader:SetShown(icons.leader)
	f.leader:SetAlpha(sample.leader and 1 or 0)
	f.assist:SetAlpha(0)
	if icons.marker and sample.marker then
		f.marker:SetSpriteSheetCell(sample.marker, MARKER_ROWS, MARKER_COLUMNS)
		f.marker:Show()
	else
		f.marker:Hide()
	end
	f.ready:Hide()
	local threat = Settings.current.threat.enabled and sample.threat
	local r, g, b
	if threat then
		r, g, b = K.Theme.ThreatColor(threat)
	end
	if r then
		f.threatGlow:SetColorRGB(r, g, b)
		f.threat:Show()
	else
		f.threat:Hide()
	end
end
Style.painters[#Style.painters + 1] = PaintSample

local events = Frames.events
events[#events + 1] = { event = "RAID_TARGET_UPDATE", fn = Each(Marker) }
events[#events + 1] = { event = "PARTY_LEADER_CHANGED", fn = Each(Leader) }
events[#events + 1] = { event = "PLAYER_ROLES_ASSIGNED", fn = Each(Role) }
events[#events + 1] = { event = "READY_CHECK", fn = ReadyStart }
events[#events + 1] = { event = "READY_CHECK_CONFIRM", fn = EachReady }
events[#events + 1] = { event = "READY_CHECK_FINISHED", fn = ReadyFinished }
