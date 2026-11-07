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

local function Visible()
	if not ns.Get("threat.shown") then
		return false
	end
	if ns.Get("threat.group") then
		return IsInGroup() == true
	end
	return true
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
		Threat.count = 0
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
	local level = Logic.NO_WARNING
	if ns.Get("threat.warnings") then
		level = Logic.ThreatWarning(Threat.rows, count, ns.Get("threat.warnAt"), ns.Get("threat.dangerAt"))
	end
	list:SetWarning(level)
end

local function Schedule()
	if Threat.pending then
		return
	end
	Threat.pending = true
	C_Timer.After(UPDATE_DELAY, Update)
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
		width = width or 260, height = height or 130, columns = Columns,
	})
	Threat.list:SetTitle(L["Threat"])
	Threat.holder = Threat.list.holder
	ns.Place(Threat.holder, KEY, LIMITS)
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
	for _, event in ipairs(EVENTS) do
		ns.Watch(self, event)
	end
	self.list:SetColumn(ns.Get("threat.value") == "threat" and "" or "%")
	self.list:Restyle()
	BuildRoster()
	Update()
end

function Threat:Stop()
	if not self.holder then
		return
	end
	ns.UnwatchAll(self)
	self.list:SetWarning(Logic.NO_WARNING)
	self.list.panel:Hide()
	self.holder:Hide()
end
