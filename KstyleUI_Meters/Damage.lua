-- Damage.lua: the damage meter: KstyleUI's own window over C_DamageMeter, with fight segments and a per-source spell list, in place of Blizzard's, or Blizzard's window restyled when the data cannot be read in combat.
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
local SKIN_EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }
local SESSION_ORDER = { "Current", "Previous", "Overall" }
local SESSION_WORDS = { Current = L["Now"], Previous = L["Last"], Overall = L["All"] }

local Damage = { section = "damage", key = KEY, combat = false, view = 1, filled = 0 }
ns.Damage = Damage

local IsSecret = Logic.IsSecret
local drill = { active = false }
local TOOLTIP_SPELLS = 3
local SWITCH_GAP = "  "
local slots = {}
local autoMode

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

local function SourceApi()
	local meter = C_DamageMeter
	return meter ~= nil and type(meter.GetCombatSessionSourceFromType) == "function" and type(meter.GetCombatSessionSourceFromID) == "function"
end

function Damage.Restricted()
	local secrets = C_Secrets
	if type(secrets) ~= "table" or type(secrets.HasSecretRestrictions) ~= "function" then
		return false
	end
	local ok, restricted = pcall(secrets.HasSecretRestrictions)
	return ok and not IsSecret(restricted) and restricted == true
end

function Damage.AutoMode()
	if autoMode == nil then
		autoMode = Damage.Restricted() and "skin" or "window"
	end
	return autoMode
end

function ns.ResolveMode(mode)
	if not Api() then
		return "skin"
	end
	if mode == "auto" or mode == nil then
		return Damage.AutoMode()
	end
	return mode
end

function Damage.Mode()
	return ns.ResolveMode(ns.Get("damage.mode"))
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

local function PlainString(value)
	if IsSecret(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

local function Alone()
	return ns.Get("damage.group") and IsInGroup() ~= true
end

local function Visible()
	return ns.Get("damage.shown") and Damage.Mode() == "window" and not Alone()
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
	ns.LogOnce("damageHidden", "C_DamageMeter data is hidden from addons right now; the window waits for it")
	if Damage.filled == Damage.view and (list.count or 0) > 0 then
		list:SetColumn(L["Paused"])
		return
	end
	list:Finish(0, L["Hidden in combat"])
end

local function SessionID(session)
	if not Readable(session) then
		return nil
	end
	return Logic.Plain(session.sessionID)
end

local function PreviousFight()
	local meter = C_DamageMeter
	if type(meter.GetAvailableCombatSessions) ~= "function" or type(meter.GetCombatSessionFromID) ~= "function" then
		ns.LogOnce("noSessionList", "C_DamageMeter cannot list past fights on this client; the previous fight stays empty")
		return nil
	end
	local ok, sessions = pcall(meter.GetAvailableCombatSessions)
	if not ok or not Readable(sessions) then
		return nil
	end
	local current = Damage.currentID
	if current == nil then
		for i = 1, #sessions do
			local id = SessionID(sessions[i])
			if id and (current == nil or id > current) then
				current = id
			end
		end
	end
	local best, name
	for i = 1, #sessions do
		local id = SessionID(sessions[i])
		if id and current and id < current and (best == nil or id > best) then
			best, name = id, sessions[i].name
		end
	end
	return best, PlainString(name)
end

local function Fight()
	local session = ns.Get("damage.session")
	if session == "Previous" then
		local id, name = PreviousFight()
		return nil, id, name
	end
	local types = Enum and Enum.DamageMeterSessionType
	return types and types[session], nil, nil
end

local function Switch(list, name)
	local session = ns.Get("damage.session")
	local words, short, selected = {}, {}, 1
	for i, key in ipairs(SESSION_ORDER) do
		words[i] = SESSION_WORDS[key]
		if key == session then
			selected = i
		end
	end
	if name and session == "Previous" then
		short[selected] = words[selected]
		words[selected] = name
	end
	list:SetSwitch(words, selected, short)
end

local function Back()
	if not drill.active then
		return
	end
	drill.active = false
	Damage.view = Damage.view + 1
	if Damage.list then
		Damage.list:SetIcons(false)
	end
end

local function Slot(i)
	local slot = slots[i]
	if not slot then
		slot = {}
		slots[i] = slot
	end
	return slot
end

local function Remember(i, source, reaction, deaths)
	local slot = Slot(i)
	local guid = source.sourceGUID
	slot.guid = PlainString(guid)
	slot.creature = Logic.Plain(source.sourceCreatureID)
	slot.name = PlainString(source.name)
	slot.class = source.classFilename
	slot.reaction = reaction
	slot.ok = not deaths and slot.name ~= nil and (slot.guid ~= nil or slot.creature ~= nil)
end

local function FillSources(list, info, session)
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
		Remember(i, source, reaction, info.deaths)
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
	Damage.filled = Damage.view
	list:Finish(count, count == 0 and L["No data yet"] or nil)
end

local function SpellCall(api, spellID)
	local spells = C_Spell
	if type(spells) ~= "table" or type(spells[api]) ~= "function" then
		return nil
	end
	local ok, value = pcall(spells[api], spellID)
	if ok then
		return value
	end
	return nil
end

local function SpellName(spell, sourceName)
	local name = SpellCall("GetSpellName", spell.spellID)
	if IsSecret(name) then
		return name
	end
	if name == nil then
		local id = Logic.Plain(spell.spellID)
		name = id and string.format("%s %d", L["Spell"], id) or ""
	end
	local creature = PlainString(spell.creatureName)
	if creature and creature ~= sourceName then
		return string.format("%s (%s)", name, creature)
	end
	return name
end

local function SourceData(meterType, sessionType, sessionID, guid, creature)
	local meter = C_DamageMeter
	if sessionID then
		return pcall(meter.GetCombatSessionSourceFromID, sessionID, meterType, guid, creature)
	end
	return pcall(meter.GetCombatSessionSourceFromType, sessionType, meterType, guid, creature)
end

local function Context()
	local info = Info()
	local meterTypes = Enum and Enum.DamageMeterType
	local meterType = meterTypes and meterTypes[info.value]
	if meterType == nil or not (Enum and Enum.DamageMeterSessionType) then
		return nil
	end
	local sessionType, sessionID, name = Fight()
	return info, meterType, sessionType, sessionID, name
end

local function SpellShown(spell, info)
	local shown = spell.totalAmount
	if info.perSecond then
		shown = spell.amountPerSecond
	end
	return shown
end

local function RowTooltip(tip, list, i)
	if drill.active and i <= (list.count or 0) then
		tip:AddLine(L["Click to go back to every source."])
		return true
	end
	return false
end

local function RowSplit(split, list, i)
	local slot = slots[i]
	if drill.active or not slot or not slot.ok or i > (list.count or 0) then
		return false
	end
	local info, meterType, sessionType, sessionID = Context()
	if not info or not SourceApi() or (sessionType == nil and sessionID == nil) then
		split:SetNote(L["Click for every spell"])
		return true
	end
	local ok, source = SourceData(meterType, sessionType, sessionID, slot.guid, slot.creature)
	if not ok or not Readable(source) or not Readable(source.combatSpells) then
		split:SetNote(L["The spells show after combat."])
		return true
	end
	local spells = source.combatSpells
	local total = source.totalAmount
	local percent = ns.Get("damage.percent")
	local listed = 0
	for n = 1, TOOLTIP_SPELLS do
		local spell = spells[n]
		if not Readable(spell) then
			break
		end
		listed = n
		local right = Logic.Abbreviate(SpellShown(spell, info))
		if percent then
			right = right .. SWITCH_GAP .. Logic.FormatPercent(Logic.Percent(spell.totalAmount, total))
		end
		split:AddLine(SpellName(spell, slot.name), right)
	end
	if listed == 0 then
		split:SetNote(L["No data yet"])
		return true
	end
	local count = #spells
	if count > listed then
		split:SetNote(string.format(L["Click for all %d spells"], count))
	end
	return true
end

local function RowSplits(list, i)
	if drill.active then
		return false
	end
	local slot = slots[i]
	return slot ~= nil and slot.ok == true and i <= (list.count or 0) and SourceApi() ~= nil
end

local function FillSpells(list, info, meterType, sessionType, sessionID)
	local ok, source = SourceData(meterType, sessionType, sessionID, drill.guid, drill.creature)
	if not ok then
		ns.LogOnce("damageSourceError", "C_DamageMeter's source call failed: " .. tostring(source))
		list:Finish(0, L["No data yet"])
		return
	end
	if not Readable(source) or not Readable(source.combatSpells) then
		Hidden(list)
		return
	end
	local spells = source.combatSpells
	local maxAmount, total = source.maxAmount, source.totalAmount
	if not Present(maxAmount) then
		maxAmount = 1
	end
	local percent = ns.Get("damage.percent")
	local count = 0
	for i = 1, list.capacity or 0 do
		local spell = spells[i]
		if not Readable(spell) then
			break
		end
		count = i
		local amount = spell.totalAmount
		if not Present(amount) then
			amount = 0
		end
		local shown = SpellShown(spell, info)
		local percentText = percent and Logic.FormatPercent(Logic.Percent(spell.totalAmount, total)) or ""
		local icon = SpellCall("GetSpellTexture", spell.spellID)
		list:SetRow(i, SpellName(spell, drill.name), drill.class, drill.reaction, amount, maxAmount, Logic.Abbreviate(shown), percentText, icon)
	end
	Damage.filled = Damage.view
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
	local info, meterType, sessionType, sessionID, name = Context()
	if not info then
		ns.LogOnce("damageEnum", "the Damage Meter enums are missing; the window stays empty")
		list:Finish(0, L["No data yet"])
		return
	end
	list:SetTitle(drill.active and drill.name or info.label)
	Switch(list, name)
	if sessionType == nil and sessionID == nil then
		list:Finish(0, L["No earlier fight yet"])
		return
	end
	if drill.active then
		FillSpells(list, info, meterType, sessionType, sessionID)
		return
	end
	local ok, session
	if sessionID then
		ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, meterType)
	else
		ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, meterType)
	end
	if not ok then
		ns.LogOnce("damageError", "C_DamageMeter's session call failed: " .. tostring(session))
		list:Finish(0, L["No data yet"])
		return
	end
	if not Readable(session) then
		Hidden(list)
		return
	end
	FillSources(list, info, session)
end

local function Schedule()
	if Damage.pending then
		return
	end
	Damage.pending = true
	C_Timer.After(UPDATE_DELAY, Refresh)
end

local function SkinVisibility()
	if Alone() then
		HideBlizzard()
	else
		RestoreBlizzard()
	end
end

function Damage:OnEvent(event, meterType, sessionID)
	if Damage.Mode() ~= "window" then
		SkinVisibility()
		return
	end
	if event == "PLAYER_REGEN_DISABLED" then
		self.combat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		self.combat = false
	elseif event == "DAMAGE_METER_RESET" then
		self.currentID = nil
		Back()
	elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
		local id = Logic.Plain(sessionID)
		if id and id > 0 then
			self.currentID = id
		end
	end
	Schedule()
end

local function OnRowClick(list, i, button)
	if drill.active then
		Back()
		Refresh()
		return
	end
	local slot = slots[i]
	if button ~= "LeftButton" or not slot or not slot.ok or i > (list.count or 0) or not SourceApi() then
		return
	end
	drill.active = true
	drill.guid, drill.creature, drill.name = slot.guid, slot.creature, slot.name
	drill.class, drill.reaction = slot.class, slot.reaction
	Damage.view = Damage.view + 1
	list:SetIcons(true)
	Refresh()
end

local function NextSession()
	local session = ns.Get("damage.session")
	for i, value in ipairs(SESSION_ORDER) do
		if value == session then
			return SESSION_ORDER[i % #SESSION_ORDER + 1]
		end
	end
	return SESSION_ORDER[1]
end

local function OnClick(_, button)
	if drill.active then
		Back()
		Refresh()
		return
	end
	if button == "RightButton" then
		K.Options.Write(ns.MODULE, "damage.session", NextSession())
		return
	end
	local _, index = Info()
	local nextType = ns.METER_TYPES[index % #ns.METER_TYPES + 1]
	K.Options.Write(ns.MODULE, "damage.meter", nextType.value)
end

local function Tooltip(tip)
	if drill.active then
		tip:AddLine(L["Click to go back to every source."])
		return
	end
	tip:AddLine(L["Click a name for its spells. Click the title for the next meter."])
	tip:AddLine(L["Click Now, Last or All for the next fight: this fight, the last fight or every fight."])
end

local function SwitchTooltip(tip)
	tip:AddLine(L["Click for the next fight: this fight, the last fight or every fight."])
	if Damage.list and Api() then
		local id, name = PreviousFight()
		if id then
			tip:AddLine(string.format(L["Last fight: %s"], name or L["Previous fight"]))
		else
			tip:AddLine(L["No earlier fight yet"])
		end
	end
end

local function OnSwitch()
	K.Options.Write(ns.MODULE, "damage.session", NextSession())
end

local function Columns()
	return { value = true, percent = ns.Get("damage.percent") }
end

local function Build()
	local width, height = ns.Footprint(KEY)
	Damage.list = ns.BarList.New(K.Scale.Root(), "damage", {
		width = width or 260, height = height or 174, columns = Columns, onClick = OnClick,
		onRowClick = OnRowClick, tooltip = Tooltip, onSwitch = OnSwitch, switchTooltip = SwitchTooltip,
		rowTooltip = RowTooltip, rowSplits = RowSplits, rowSplit = RowSplit,
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

local function Track(self)
	local meter, session = ns.Get("damage.meter"), ns.Get("damage.session")
	if meter ~= self.meter then
		self.meter = meter
		Back()
		self.view = self.view + 1
	end
	if session ~= self.session then
		self.session = session
		self.view = self.view + 1
	end
end

local function Window(self)
	ns.DamageSkin.Deactivate()
	self.holder:Show()
	for _, event in ipairs(EVENTS) do
		ns.Watch(self, event)
	end
	HideBlizzard()
	Track(self)
	self.list:Restyle()
	self.combat = InCombatLockdown() == true
	Refresh()
end

function Damage:Apply()
	if not self.holder or not ns.IsRunning() then
		return
	end
	ns.SetLive(KEY, ns.Get("damage.shown") and Damage.Mode() == "window")
	if not ns.Get("damage.shown") then
		self:Stop()
		return
	end
	if Damage.Mode() == "window" then
		Window(self)
		return
	end
	if ns.Get("damage.mode") ~= "skin" then
		ns.LogOnce("damageSkinPath", Api() and "C_DamageMeter is secret in combat on this client; the damage meter restyles Blizzard's window, which reads in combat"
			or "C_DamageMeter is missing; the damage meter restyles Blizzard's window")
	end
	ns.UnwatchAll(self)
	self.currentID = nil
	for _, event in ipairs(SKIN_EVENTS) do
		ns.Watch(self, event)
	end
	Back()
	self.list.panel:Hide()
	self.holder:Hide()
	SkinVisibility()
	ns.DamageSkin.Activate()
end

function Damage:Stop()
	if not self.holder then
		return
	end
	ns.UnwatchAll(self)
	self.currentID = nil
	Back()
	self.list.panel:Hide()
	self.holder:Hide()
	RestoreBlizzard()
	ns.DamageSkin.Deactivate()
end
