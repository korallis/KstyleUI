-- Damage.lua: the damage meter: KstyleUI's own window over C_DamageMeter in place of Blizzard's, or Blizzard's window restyled when the data cannot be read.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Logic = ns.Logic

local KEY = "meters.damage"
local UPDATE_DELAY = 0.3
local LIMITS = { minWidth = 120, maxWidth = 600, minHeight = 40, maxHeight = 800 }
local SECONDS_PER_MINUTE = 60
local EVENTS = {
	"DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET",
	"GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
}
local SESSION_COLUMNS = { Current = L["Current"], Overall = L["Overall"] }

local Damage = { section = "damage", key = KEY, fallback = false, unreadable = false, combat = false }
ns.Damage = Damage

local IsSecret = Logic.IsSecret

local function HideBlizzard()
	local meter = _G.DamageMeter
	if meter == nil then
		ns.LogOnce("noDamageMeterFrame", "Blizzard's DamageMeter is missing on this client; there is nothing to hide")
		return
	end
	K.Safe.HideBlizzard(meter)
end

local function RestoreBlizzard()
	local meter = _G.DamageMeter
	if meter ~= nil then
		K.Safe.RestoreBlizzard(meter)
	end
end

local function Api()
	local meter = C_DamageMeter
	return meter ~= nil and type(meter.GetCombatSessionFromType) == "function"
end

function Damage.Mode()
	local mode = ns.Get("damage.mode")
	if mode == "window" and (Damage.fallback or not Api()) then
		return "skin"
	end
	return mode
end

local function Info()
	local meter = ns.Get("damage.meter")
	for i, info in ipairs(ns.METER_TYPES) do
		if info.value == meter then
			return info, i
		end
	end
	return ns.METER_TYPES[1], 1
end

local function Readable(t)
	if IsSecret(t) or type(t) ~= "table" then
		return false
	end
	if type(canaccesstable) == "function" then
		local ok, can = pcall(canaccesstable, t)
		if not ok or IsSecret(can) or can ~= true then
			return false
		end
	end
	return true
end

local function Visible()
	if not ns.Get("damage.shown") or Damage.Mode() ~= "window" then
		return false
	end
	if ns.Get("damage.group") then
		return IsInGroup() == true
	end
	return true
end

local function DeathText(source)
	local seconds = Logic.Plain(source.deathTimeSeconds)
	if not seconds or seconds < 0 then
		return ""
	end
	return string.format("%d:%02d", math.floor(seconds / SECONDS_PER_MINUTE), math.floor(seconds % SECONDS_PER_MINUTE))
end

local function Present(value)
	return IsSecret(value) or value ~= nil
end

local function Hidden(list)
	if Damage.combat then
		Damage.unreadable = true
	end
	ns.LogOnce("damageHidden", "C_DamageMeter data is hidden from addons right now; the window waits for it")
	list:Finish(0, L["Hidden in combat"])
end

local function Fill(list, info, session)
	local sources = session.combatSources
	if not Readable(sources) then
		Hidden(list)
		return
	end
	local maxAmount, total = session.maxAmount, session.totalAmount
	if not Present(maxAmount) then
		maxAmount = 1
	end
	local percent = ns.Get("damage.percent") and not info.deaths
	local displays = Enum and Enum.DamageMeterSourceDisplayType
	local enemy = displays and displays.Enemy
	local count = 0
	for i = 1, list.capacity or 0 do
		local source = sources[i]
		if not Readable(source) then
			break
		end
		count = i
		local display = source.sourceDisplayType
		local reaction = (enemy ~= nil and not IsSecret(display) and display == enemy) and "hostile" or "friendly"
		local amount = source.totalAmount
		if not Present(amount) then
			amount = 0
		end
		if info.deaths then
			list:SetRow(i, source.name, source.classFilename, reaction, 1, 1, DeathText(source), "")
		else
			local shown = source.totalAmount
			if info.perSecond then
				shown = source.amountPerSecond
			end
			local valueText = Logic.Abbreviate(shown)
			local percentText = percent and Logic.FormatPercent(Logic.Percent(source.totalAmount, total)) or ""
			list:SetRow(i, source.name, source.classFilename, reaction, amount, maxAmount, valueText, percentText)
		end
	end
	list:Finish(count, count == 0 and L["No data yet"] or nil)
end

local function Refresh()
	Damage.pending = false
	local list = Damage.list
	if not list or not ns.IsRunning() then
		return
	end
	local visible = Visible()
	list.panel:SetShown(visible)
	if not visible then
		return
	end
	local info = Info()
	local enum = Enum or {}
	local meterTypes, sessionTypes = enum.DamageMeterType, enum.DamageMeterSessionType
	local meterType = meterTypes and meterTypes[info.value]
	local sessionType = sessionTypes and sessionTypes[ns.Get("damage.session")]
	if meterType == nil or sessionType == nil then
		ns.LogOnce("damageEnum", "the Damage Meter enums are missing; the window stays empty")
		list:Finish(0, L["No data yet"])
		return
	end
	local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, meterType)
	if not ok then
		ns.LogOnce("damageError", "C_DamageMeter.GetCombatSessionFromType failed: " .. tostring(session))
		list:Finish(0, L["No data yet"])
		return
	end
	if not Readable(session) then
		Hidden(list)
		return
	end
	Fill(list, info, session)
end

local function Schedule()
	if Damage.pending then
		return
	end
	Damage.pending = true
	C_Timer.After(UPDATE_DELAY, Refresh)
end

local function FallBack()
	Damage.fallback = true
	ns.Log("C_DamageMeter data stayed hidden in combat; the meter restyles Blizzard's window for this session")
	K.Print(L["The game hides Damage Meter numbers from addons in combat, so KstyleUI restyles Blizzard's meter instead until you reload."])
	Damage:Apply()
end

function Damage:OnEvent(event, ...)
	if event == "PLAYER_REGEN_DISABLED" then
		self.combat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		self.combat = false
		if self.unreadable and not self.fallback then
			FallBack()
			return
		end
	end
	Schedule()
end

local function OnClick(_, button)
	if button == "RightButton" then
		local session = ns.Get("damage.session") == "Current" and "Overall" or "Current"
		K.Options.Write(ns.MODULE, "damage.session", session)
		return
	end
	local _, index = Info()
	local nextType = ns.METER_TYPES[index % #ns.METER_TYPES + 1]
	K.Options.Write(ns.MODULE, "damage.meter", nextType.value)
end

local function Columns()
	return { value = true, percent = ns.Get("damage.percent") }
end

local function Build()
	local width, height = ns.Footprint(KEY)
	Damage.list = ns.BarList.New(K.Scale.Root(), "damage", {
		width = width or 260, height = height or 174, columns = Columns, onClick = OnClick,
		tooltip = L["Click to change what the meter shows. Right-click for the current fight or overall."],
	})
	Damage.holder = Damage.list.holder
	ns.Place(Damage.holder, KEY, LIMITS)
end

function Damage:Resized()
	if self.list then
		self.list:Restyle()
		Schedule()
	end
end

function Damage:Start()
	if not self.holder then
		Build()
	end
	self:Apply()
end

local function Window(self)
	ns.DamageSkin.Deactivate()
	self.holder:Show()
	for _, event in ipairs(EVENTS) do
		ns.Watch(self, event)
	end
	HideBlizzard()
	local info = Info()
	self.list:SetTitle(info.label)
	self.list:SetColumn(SESSION_COLUMNS[ns.Get("damage.session")] or "")
	self.list:Restyle()
	self.combat = InCombatLockdown() == true
	Refresh()
end

function Damage:Apply()
	if not self.holder or not ns.IsRunning() then
		return
	end
	if not ns.Get("damage.shown") then
		self:Stop()
		return
	end
	if Damage.Mode() == "window" then
		Window(self)
		return
	end
	if ns.Get("damage.mode") == "window" then
		ns.LogOnce("damageSkinPath", self.fallback and "the damage meter restyles Blizzard's window after hidden data in combat"
			or "C_DamageMeter is missing; the damage meter restyles Blizzard's window")
	end
	ns.UnwatchAll(self)
	self.list.panel:Hide()
	self.holder:Hide()
	RestoreBlizzard()
	ns.DamageSkin.Activate()
end

function Damage:Stop()
	if not self.holder then
		return
	end
	ns.UnwatchAll(self)
	self.list.panel:Hide()
	self.holder:Hide()
	RestoreBlizzard()
	ns.DamageSkin.Deactivate()
end
