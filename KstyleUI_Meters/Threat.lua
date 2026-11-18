-- Threat.lua: the threat meter: the group's threat on the player's target from UnitDetailedThreatSituation, with warnings on readable values.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Logic = ns.Logic

local KEY = "meters.threat"
local UPDATE_DELAY = 0.2
local MAX_RAID = 40
local MAX_PARTY = 4
local PERCENT_MAX = 100
local LIMITS = { minWidth = 120, maxWidth = 600, minHeight = 40, maxHeight = 800 }
local EVENTS = {
	"PLAYER_TARGET_CHANGED", "UNIT_TARGET", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
	"GROUP_ROSTER_UPDATE", "UNIT_PET", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
}

local RAID, RAID_PET, PARTY, PARTY_PET = {}, {}, {}, {}
for i = 1, MAX_RAID do
	RAID[i], RAID_PET[i] = "raid" .. i, "raidpet" .. i
end
for i = 1, MAX_PARTY do
	PARTY[i], PARTY_PET[i] = "party" .. i, "partypet" .. i
end

local Threat = { section = "threat", key = KEY, roster = {}, size = 0, rows = {}, order = {}, count = 0 }
ns.Threat = Threat

local function IsSecret(v)
	return Logic.IsSecret(v)
end

local function Exists(unit)
	local exists = UnitExists(unit)
	return not IsSecret(exists) and exists == true
end

local function Same(a, b)
	if type(UnitIsUnit) ~= "function" then
		return false
	end
	local same = UnitIsUnit(a, b)
	return not IsSecret(same) and same == true
end

local function Add(unit)
	local size = Threat.size + 1
	Threat.roster[size] = unit
	Threat.size = size
end

local function BuildRoster()
	Threat.size = 0
	local pets = ns.Get("threat.pets")
	Add("player")
	if pets then
		Add("pet")
	end
	if IsInRaid() then
		local members = Logic.Plain(GetNumGroupMembers()) or 0
		for i = 1, math.min(members, MAX_RAID) do
			if not Same(RAID[i], "player") then
				Add(RAID[i])
			end
			if pets and not Same(RAID_PET[i], "pet") then
				Add(RAID_PET[i])
			end
		end
	elseif IsInGroup() then
		for i = 1, MAX_PARTY do
			Add(PARTY[i])
			if pets then
				Add(PARTY_PET[i])
			end
		end
	end
end

local function Hostile(unit)
	if not Exists(unit) then
		return false
	end
	local can = UnitCanAttack("player", unit)
	return not IsSecret(can) and can == true
end

local function Mob()
	if Hostile("target") then
		return "target"
	elseif Hostile("targettarget") then
		return "targettarget"
	end
	return nil
end

local function Row(i)
	local row = Threat.rows[i]
	if not row then
		row = {}
		Threat.rows[i] = row
	end
	return row
end

local function Collect(mob)
	local count = 0
	local query = UnitDetailedThreatSituation
	for i = 1, Threat.size do
		local unit = Threat.roster[i]
		if Exists(unit) then
			local tanking, status, scaled, raw, threat = query(unit, mob)
			if IsSecret(tanking) or tanking ~= nil then
				count = count + 1
				local row = Row(count)
				row.unit, row.isPlayer = unit, unit == "player"
				row.name = UnitName(unit)
				row.class = select(2, UnitClass(unit))
				row.tanking, row.status, row.scaled, row.raw, row.threat = tanking, status, scaled, raw, threat
				Threat.order[count] = count
			end
		end
	end
	return count
end

local function ValueText(row)
	return Logic.Abbreviate(Logic.ThreatAmount(row.threat) or row.threat)
end

local function PercentText(row)
	local scaled = row.scaled
	if IsSecret(scaled) then
		return Logic.Abbreviate(scaled) .. "%"
	end
	scaled = Logic.Plain(scaled)
	if not scaled then
		return ""
	end
	return Logic.FormatPercent(math.floor(scaled + 0.5))
end

local function Columns()
	local value = ns.Get("threat.value")
	return { value = value ~= "percent", percent = value ~= "threat" }
end

local function Count(list, text)
	if not IsSecret(text) and text == Threat.countText then
		return
	end
	Threat.countText = not IsSecret(text) and text or nil
	list:SetColumn(text)
end

local function Visible()
	if not ns.Get("threat.shown") then
		return false
	end
	if ns.Get("threat.group") then
		return IsInGroup() == true
	end
	return true
end

function Threat.AlarmWanted(rows, count, tankRole)
	local tank
	for i = 1, count do if rows[i].isPlayer then tank = rows[i]; break end end
	if not tank then return false end
	local tanking = not IsSecret(tank.tanking) and tank.tanking == true
	if not tanking and not tankRole then return false end
	local amount = Logic.Plain(tank.threat)
	if not amount or amount <= 0 then return false end
	for i = 1, count do
		local row = rows[i]
		local other = Logic.Plain(row.threat)
		if not row.isPlayer and not row.unit:find("pet", 1, true) and other and other > amount * 0.9 then return true end
	end
	return false
end

local function Alarm(on)
	local list = Threat.list
	if not list then return end
	local entering = on and not Threat.alarm
	Threat.alarm = on
	list.panel.chrome:SetEdge(on and "hostile" or "edgeInner", 1)
	K.Widgets.TextColor(list.title, on and "hostile" or "capsGold")
	if entering and list.alarmFlash then list.alarmFlash:Play() end
end

local function Update()
	Threat.pending = false
	local list = Threat.list
	if not list or not ns.IsRunning() then
		return
	end
	local visible = Visible()
	list.panel:SetShown(visible)
	if not visible then
		Alarm(false)
		list:SetWarning(Logic.NO_WARNING)
		return
	end
	if type(UnitDetailedThreatSituation) ~= "function" then
		ns.LogOnce("noThreat", "UnitDetailedThreatSituation is missing; the threat meter stays empty")
		list:Finish(0, L["No threat data"])
		return
	end
	local mob = Mob()
	if not mob then
		Alarm(false)
		Threat.count = 0
		Count(list, "")
		list:SetWarning(Logic.NO_WARNING)
		list:Finish(0, L["No target"])
		return
	end
	local count = Collect(mob)
	Threat.count = count
	local sorted = Logic.SortRows(Threat.rows, Threat.order, count, "scaled")
	if not sorted then
		ns.LogOnce("threatSecret", "threat values are secret; the meter keeps the group's order")
	end
	local shown = math.min(count, list.capacity or 0)
	for i = 1, shown do
		local row = Threat.rows[Threat.order[i]]
		list:SetRow(i, row.name, row.class, "friendly", row.scaled, PERCENT_MAX, ValueText(row), PercentText(row))
	end
	list:Finish(shown, count == 0 and L["No threat"] or nil)
	local watched = Logic.ThreatWatch(Threat.rows, count)
	local text = ""
	if watched then
		text = PercentText(watched)
	end
	Count(list, text)
	local level = Logic.NO_WARNING
	if ns.Get("threat.warnings") then
		level = Logic.ThreatWarning(Threat.rows, count, ns.Get("threat.warnAt"), ns.Get("threat.dangerAt"))
	end
	list:SetWarning(level)
	local role
	if type(UnitGroupRolesAssigned) == "function" then role = UnitGroupRolesAssigned("player") end
	local tankRole = not IsSecret(role) and role == "TANK" or K.Store.Module("Layout").preset == "Tank"
	Alarm(ns.Get("threat.warnings") and Threat.AlarmWanted(Threat.rows, count, tankRole))
end

local function Schedule()
	if Threat.pending then
		return
	end
	Threat.pending = true
	C_Timer.After(UPDATE_DELAY, Update)
end

local function DockGuide()
	local holder = Threat.holder
	local side = K.Safe.Side(K.Scale.Root())
	local guide = side.storyGuide
	local element = K.Layout.Element(KEY)
	local layout, default = element and element.settings, element and element.default
	if not holder or not layout or InCombatLockdown() then
		return
	end
	local on = ns.Get("threat.followGuide") and guide and guide:IsVisible() and layout.anchor == default.anchor and layout.x == default.x and layout.y == default.y and not K.Layout.IsActive()
	if on then
		local foot = side.storyGuideBottom or guide
		local top, bottom = Logic.Plain(guide:GetBottom()), Logic.Plain(foot:GetBottom())
		local gap = top and bottom and math.max(0, top * K.Widgets.ScaleFactor(guide) - bottom * K.Widgets.ScaleFactor(foot)) or 0
		holder:ClearAllPoints()
		K.Widgets.Point(holder, "TOPRIGHT", guide, "BOTTOMRIGHT", 0, -(16 + gap) / K.Widgets.ScaleFactor(holder))
		Threat.docked = true
	elseif Threat.docked then
		holder:ClearAllPoints()
		holder:SetPoint(layout.anchor, K.Scale.Root(), layout.anchor, layout.x, layout.y)
		Threat.docked = false
	end
end

function Threat:OnEvent(event, unit)
	if event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD" then
		BuildRoster()
	elseif event == "UNIT_TARGET" and unit ~= "target" then
		return
	end
	Schedule()
end

local function Build()
	local width, height = ns.Footprint(KEY)
	Threat.list = ns.BarList.New(K.Scale.Root(), "threat", {
		key = KEY, width = width or 260, height = height or 130, columns = Columns,
	})
	Threat.list:SetTitle(L["Threat"])
	Threat.list:SetColumn("")
	Threat.countText = ""
	local flash = Threat.list.panel:CreateTexture(nil, "OVERLAY")
	flash:SetAllPoints(Threat.list.panel)
	flash:SetColorTexture(K.Widgets.Rgba("hostile", 0.2))
	flash:SetAlpha(0)
	local group = flash:CreateAnimationGroup()
	local alpha = group:CreateAnimation("Alpha")
	alpha:SetFromAlpha(1)
	alpha:SetToAlpha(0)
	alpha:SetDuration(0.2)
	Threat.list.alarmFlash = group
	Threat.holder = Threat.list.holder
	ns.Place(Threat.holder, KEY, LIMITS)
	K.Safe.Side(K.Scale.Root()).dockThreat = DockGuide
end

function Threat:Resized()
	if self.list then
		self.list:Restyle()
		Schedule()
	end
end

function Threat:Start()
	if not self.holder then
		Build()
	end
	self:Apply()
end

function Threat:Apply()
	if not self.holder or not ns.IsRunning() then
		return
	end
	ns.SetLive(KEY, ns.Get("threat.shown"))
	if not ns.Get("threat.shown") then
		self:Stop()
		return
	end
	self.holder:Show()
	DockGuide()
	for _, event in ipairs(EVENTS) do
		ns.Watch(self, event)
	end
	self.list:Restyle()
	BuildRoster()
	Update()
end

function Threat:Stop()
	if not self.holder then
		return
	end
	ns.UnwatchAll(self)
	Alarm(false)
	self.list:SetWarning(Logic.NO_WARNING)
	self.list.panel:Hide()
	self.holder:Hide()
end
