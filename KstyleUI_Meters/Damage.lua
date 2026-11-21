-- Damage.lua: the damage meter: KstyleUI's own windows over C_DamageMeter (the main one and an optional second), with fight segments, a per-source spell list and reports to chat, in place of Blizzard's, or Blizzard's window restyled when C_DamageMeter is missing or the player picks it.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Logic = ns.Logic

local KEY, SECOND = "meters.damage", "meters.damage2"
local LIMITS = { minWidth = 120, maxWidth = 600, minHeight = 40, maxHeight = 800 }
local SECOND_PLACE, SECOND_WIDTH = { anchor = "BOTTOMRIGHT", x = -283, y = 17 }, 180
local SECONDS_PER_MINUTE = 60
local EVENTS = {
	"DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET",
	"GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
}
local SKIN_EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }
local SESSION_ORDER = { "Current", "Previous", "Overall" }
local SESSION_WORDS = { Current = L["Now"], Previous = L["Last"], Overall = L["All"] }
local FIGHTS = { Current = L["Current fight"], Previous = L["Previous fight"], Overall = L["Overall"] }
local GROUP_CHATS = { "INSTANCE_CHAT", "RAID", "PARTY" }
local REPORT_LINES = 10

local function Window(section, key)
	return { section = section, key = key, meterKey = section .. ".meter", sessionKey = section .. ".session", combat = false, view = 1, filled = 0,
		drill = { active = false }, slots = {}, switchWords = {}, switchShort = {} }
end
local Damage, Second = Window("damage", KEY), Window("damage2", SECOND)
ns.Damage, ns.Damage2 = Damage, Second

local IsSecret = Logic.IsSecret
local max, min = math.max, math.min
local PLAYER = "player"
local NO_REST = { Deaths = true, EnemyDamageTaken = true }
local FAMILY = { DamageDone = "HealingDone", Dps = "Hps", HealingDone = "DamageDone", Hps = "Dps" }
local HEALING = { HealingDone = true, Hps = true }
local CLASS_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local order = {}
local classIcons = {}
local abbreviate = Logic.Abbreviate

local function NumberText(amount, format)
	if format == "full" and type(BreakUpLargeNumbers) == "function" then
		local ok, text = pcall(BreakUpLargeNumbers, amount)
		if ok then return text end
	end
	return abbreviate(amount)
end

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

function ns.ResolveMode(mode)
	if not Api() then
		return "skin"
	end
	if mode == "auto" or mode == nil then
		return "window"
	end
	return mode
end

function Damage.Mode()
	return ns.ResolveMode(ns.Get("damage.mode"))
end

function Damage.Wanted()
	return ns.MeterShown("damage") and Damage.Mode() == "window"
end

function Second.Wanted()
	return ns.Get("damage2.shown") and Api()
end

local function Info(W)
	local meter = ns.Get(W.meterKey)
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

local function Visible(W)
	return W.Wanted() and not Alone() and not ns.windowsHidden
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

local function Hidden(W, list)
	ns.LogOnce("damageHidden", "C_DamageMeter data is hidden from addons right now; the window waits for it")
	if W.filled == W.view and (list.count or 0) > 0 then
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

local function PreviousFight(W)
	local meter = C_DamageMeter
	if type(meter.GetAvailableCombatSessions) ~= "function" or type(meter.GetCombatSessionFromID) ~= "function" then
		ns.LogOnce("noSessionList", "C_DamageMeter cannot list past fights on this client; the previous fight stays empty")
		return nil
	end
	local ok, sessions = pcall(meter.GetAvailableCombatSessions)
	if not ok or not Readable(sessions) then
		return nil
	end
	local current = W.currentID
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

local function Fight(W)
	local session = ns.Get(W.sessionKey)
	if session == "Previous" then
		local id, name = PreviousFight(W)
		return nil, id, name
	end
	local types = Enum and Enum.DamageMeterSessionType
	return types and types[session], nil, nil
end

local function Switch(W, list, name)
	local session = ns.Get(W.sessionKey)
	if list.switchWords and not list.hot and W.switchLayout == list.textLayout and W.switchName == name and W.switchSession == session then
		return
	end
	W.switchLayout, W.switchName, W.switchSession = list.textLayout, name, session
	local words, short, selected = W.switchWords, W.switchShort, 1
	for i, key in ipairs(SESSION_ORDER) do
		words[i] = SESSION_WORDS[key]
		short[i] = nil
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

local function Back(W)
	if not W.drill.active then
		return
	end
	W.drill.active = false
	W.view = W.view + 1
	if W.list then
		W.list:SetIcons(false)
	end
end

local function Slot(W, i)
	local slot = W.slots[i]
	if not slot then
		slot = {}
		W.slots[i] = slot
	end
	return slot
end

local function Line(W, i, place, label, text, share)
	local slot = Slot(W, i)
	slot.place, slot.label, slot.text, slot.share = place, label, text, share
end

local function Own(call)
	local ok, value = pcall(call, PLAYER)
	return ok and PlainString(value) or nil
end

local function Remember(W, i, source, reaction, deaths)
	local slot = Slot(W, i)
	local own = source.isLocalPlayer == true
	slot.guid = PlainString(source.sourceGUID) or (own and Own(UnitGUID) or nil)
	slot.creature = Logic.Plain(source.sourceCreatureID)
	slot.name = PlainString(source.name) or (own and Own(UnitName) or nil)
	slot.class = source.classFilename
	slot.reaction = reaction
	slot.own = own
	slot.ok = not deaths and slot.name ~= nil and (slot.guid ~= nil or slot.creature ~= nil)
end

local function RateOf(sources, info, guid)
	if not info.rate then
		return nil
	end
	for i = 1, #sources do
		local source = sources[i]
		if not Readable(source) then
			return nil
		end
		if (guid == nil and source.isLocalPlayer == true) or (guid ~= nil and PlainString(source.sourceGUID) == guid) then
			return Logic.FormatRate(source.amountPerSecond, info.rate, abbreviate)
		end
	end
	return nil
end

local function Entries(entries)
	local n = 0
	while Readable(entries[n + 1]) do
		n = n + 1
	end
	return n
end

local function Amount(entry, info)
	if info.perSecond then
		return entry.amountPerSecond
	end
	return entry.totalAmount
end

local function Order(entries, n, info)
	for i = 1, n do
		order[i] = i
	end
	for i = #order, n + 1, -1 do
		order[i] = nil
	end
	if info.deaths then
		return
	end
	for i = 1, n do
		if not Logic.Plain(Amount(entries[i], info)) then
			return
		end
	end
	for i = 2, n do
		local k = order[i]
		local amount = Amount(entries[k], info)
		local j = i - 1
		while j >= 1 and Amount(entries[order[j]], info) < amount do
			order[j + 1] = order[j]
			j = j - 1
		end
		order[j + 1] = k
	end
end

local function Span(W, list, n, pinned)
	local capacity = list.capacity or 0
	if W.offsetView ~= W.view then
		W.offsetView = W.view
		W.offset = 0
	end
	local room = capacity
	local first = max(0, min(W.offset or 0, n - room))
	local pin = pinned ~= nil and capacity >= 2 and (pinned <= first or pinned > first + room)
	if pin then
		room = capacity - 1
		first = max(0, min(W.offset or 0, n - room))
		pin = pinned <= first or pinned > first + room
		if not pin then
			room = capacity
		end
	end
	W.offset, W.top = first, max(0, n - room)
	return first, max(0, min(room, n - first)), pin
end

local function ClassIcon(class)
	if IsSecret(class) or type(class) ~= "string" or class == "" then
		return nil
	end
	local icon = classIcons[class]
	if icon == nil then
		icon = false
		local atlas = type(GetClassAtlas) == "function" and GetClassAtlas(class) or ("classicon-" .. class)
		local atlases = C_Texture
		local ok, found = false, nil
		if atlases and type(atlases.GetAtlasInfo) == "function" then
			ok, found = pcall(atlases.GetAtlasInfo, atlas)
		end
		if ok and found then
			icon = atlas
		elseif type(CLASS_ICON_TCOORDS) == "table" and type(CLASS_ICON_TCOORDS[class]) == "table" then
			icon = CLASS_ICON_TCOORDS[class]
			ns.LogOnce("classAtlas", "the class icon atlas is missing; the meter uses the class icon texture")
		end
		classIcons[class] = icon
	end
	return icon or nil
end

function ns.SetClassIcon(list, i, class)
	local icon = ClassIcon(class)
	if not icon then
		list:SetRowIcon(i)
	elseif type(icon) == "string" then
		list:SetRowIcon(i, nil, icon)
	else
		list:SetRowIcon(i, CLASS_TEXTURE, nil, icon[1], icon[2], icon[3], icon[4])
	end
end

local function SpellRow(list, i, id)
	local row = list.rows[i]
	if row.spellID ~= id then
		row.spellID = id
		ns.BarList.Unown(row.frame)
	end
end

local function SourceRow(W, list, i, source, info, maxAmount, total, percent, enemy, format, place, pinned)
	local display = source.sourceDisplayType
	local reaction = (enemy ~= nil and not IsSecret(display) and display == enemy) and "hostile" or "friendly"
	Remember(W, i, source, reaction, info.deaths)
	local name = source.name
	if pinned and not ns.Get("damage.hideRank") then
		name = place .. ". " .. name
	end
	local text, share
	if info.deaths then
		text, share = DeathText(source), ""
		list:SetRow(i, name, source.classFilename, reaction, 1, 1, text, share)
	else
		local amount = source.totalAmount
		if not Present(amount) then
			amount = 0
		end
		share = percent and Logic.FormatPercent(Logic.Percent(source.totalAmount, total)) or ""
		text = NumberText(Amount(source, info), format)
		list:SetRow(i, name, source.classFilename, reaction, amount, maxAmount, text, share)
	end
	Line(W, i, place, source.name, text, share)
	ns.SetClassIcon(list, i, source.classFilename)
	list:SetMarker(i, source.isLocalPlayer)
	SpellRow(list, i)
end

local function FillSources(W, list, info, session)
	local sources = session.combatSources
	if not Readable(sources) then
		Hidden(W, list)
		return
	end
	local maxAmount, total = session.maxAmount, session.totalAmount
	if not Present(maxAmount) then
		maxAmount = 1
	end
	local format = ns.Get("damage.format")
	local percent = ns.Get("damage.percent") and not info.deaths
	local displays = Enum and Enum.DamageMeterSourceDisplayType
	local enemy = displays and displays.Enemy
	list:SetRest(RateOf(sources, info))
	local n = Entries(sources)
	Order(sources, n, info)
	local mine
	for p = 1, n do
		if sources[order[p]].isLocalPlayer == true then
			mine = p
			break
		end
	end
	local first, shown, pin = Span(W, list, n, ns.Get("damage.alwaysPlayer") and mine or nil)
	for i = 1, shown do
		SourceRow(W, list, i, sources[order[first + i]], info, maxAmount, total, percent, enemy, format, first + i)
	end
	local count = shown
	if pin then
		count = shown + 1
		SourceRow(W, list, count, sources[order[mine]], info, maxAmount, total, percent, enemy, format, mine, true)
	end
	W.filled = W.view
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
ns.SpellCall = SpellCall

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

local function Context(W)
	local info = Info(W)
	local meterTypes = Enum and Enum.DamageMeterType
	local meterType = meterTypes and meterTypes[info.value]
	if meterType == nil or not (Enum and Enum.DamageMeterSessionType) then
		return nil
	end
	local sessionType, sessionID, name = Fight(W)
	return info, meterType, sessionType, sessionID, name
end

local function RowTooltip(W, tip, list, i)
	local shown, game = i <= (list.count or 0), GameTooltip
	local row = shown and list.rows[i]
	if row and row.spellID and ns.Get("damage.spellTooltips") and game and type(game.SetSpellByID) == "function" then
		game:SetOwner(row.frame, ns.BarList.Inward(row.frame))
		game:SetSpellByID(row.spellID)
		if W.drill.active then game:AddLine(L["Click to go back to every source."]) end
		game:Show()
		return false
	end
	if W.drill.active and shown then
		tip:AddLine(L["Click to go back to every source."])
		return true
	end
	return false
end

local function RowSplit(W, split, list, i)
	local slot = W.slots[i]
	if W.drill.active or not slot or not slot.ok or i > (list.count or 0) then
		return false
	end
	local info, meterType, sessionType, sessionID = Context(W)
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
	local total, maxAmount = source.totalAmount, source.maxAmount
	if not Present(maxAmount) then
		maxAmount = 1
	end
	local format = ns.Get("damage.format")
	local percent = ns.Get("damage.percent")
	local listed = 0
	for n = 1, ns.Get("damage.hoverSpells") do
		local spell = spells[n]
		if not Readable(spell) then
			break
		end
		listed = n
		local amount = spell.totalAmount
		if not Present(amount) then
			amount = 0
		end
		local percentText = percent and Logic.FormatPercent(Logic.Percent(spell.totalAmount, total)) or ""
		split:AddRow(SpellName(spell, slot.name), amount, maxAmount, NumberText(Amount(spell, info), format), percentText,
			SpellCall("GetSpellTexture", spell.spellID), Logic.SchoolToken(spell.spellID))
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

local function RowSplits(W, list, i)
	if not ns.Get("damage.hover") or W.drill.active or W.resting then
		return false
	end
	local slot = W.slots[i]
	return slot ~= nil and slot.ok == true and i <= (list.count or 0) and SourceApi()
end

local function Session(meterType, sessionType, sessionID)
	if sessionID then
		return pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, meterType)
	end
	return pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, meterType)
end

local function FillSpells(W, list, info, meterType, sessionType, sessionID, who)
	local ok, source = SourceData(meterType, sessionType, sessionID, who.guid, who.creature)
	if not ok then
		ns.LogOnce("damageSourceError", "C_DamageMeter's source call failed: " .. tostring(source))
		list:Finish(0, L["No data yet"])
		return
	end
	if not Readable(source) or not Readable(source.combatSpells) then
		Hidden(W, list)
		return
	end
	local spells = source.combatSpells
	local maxAmount, total = source.maxAmount, source.totalAmount
	if not Present(maxAmount) then
		maxAmount = 1
	end
	local sessionOk, session = Session(meterType, sessionType, sessionID)
	if sessionOk and Readable(session) and Readable(session.combatSources) and (who.own or who.guid) then
		list:SetRest(RateOf(session.combatSources, info, not who.own and who.guid or nil))
	end
	local format = ns.Get("damage.format")
	local percent = ns.Get("damage.percent")
	local n = Entries(spells)
	Order(spells, n, info)
	local first, count = Span(W, list, n)
	for i = 1, count do
		local spell = spells[order[first + i]]
		local amount = spell.totalAmount
		if not Present(amount) then
			amount = 0
		end
		local percentText = percent and Logic.FormatPercent(Logic.Percent(spell.totalAmount, total)) or ""
		local label, text = SpellName(spell, who.name), NumberText(Amount(spell, info), format)
		list:SetRow(i, label, who.class, who.reaction, amount, maxAmount, text, percentText, nil, Logic.SchoolToken(spell.spellID))
		list:SetRowIcon(i, SpellCall("GetSpellTexture", spell.spellID))
		list:SetMarker(i)
		SpellRow(list, i, Logic.Plain(spell.spellID))
		Line(W, i, first + i, label, text, percentText)
	end
	W.filled = W.view
	list:Finish(count, count == 0 and L["No data yet"] or nil)
end

local function OwnSource(info)
	if NO_REST[info.value] or not SourceApi() then
		return nil
	end
	local ok, guid = pcall(UnitGUID, PLAYER)
	guid = ok and PlainString(guid) or nil
	local name = PlainString((UnitName(PLAYER)))
	if not guid or not name then
		return nil
	end
	local _, class = UnitClass(PLAYER)
	return { guid = guid, name = name, class = class, reaction = "friendly", own = true }
end

local function Refresh(W)
	W.pending = false
	local list = W.list
	if not list or not ns.IsRunning() then
		return
	end
	local visible = Visible(W)
	list.panel:SetShown(visible)
	if not visible then
		return
	end
	local info, meterType, sessionType, sessionID, name = Context(W)
	if not info then
		ns.LogOnce("damageEnum", "the Damage Meter enums are missing; the window stays empty")
		list:Finish(0, L["No data yet"])
		return
	end
	local drill = W.drill
	local own = not drill.active and IsInGroup() ~= true and OwnSource(info) or nil
	W.resting = own ~= nil
	if drill.active and drill.own then
		list:SetTitle(info.cap or info.label)
	elseif drill.active then
		list:SetTitle(drill.name)
	elseif FAMILY[info.value] then
		list:SetTitleSwitch(L["Damage"], L["Healing"], HEALING[info.value] and 2 or 1)
	else
		list:SetTitle(info.cap or info.label)
	end
	Switch(W, list, name)
	if sessionType == nil and sessionID == nil then
		list:Finish(0, L["No earlier fight yet"])
		return
	end
	if drill.active or own then
		FillSpells(W, list, info, meterType, sessionType, sessionID, own or drill)
		return
	end
	local ok, session = Session(meterType, sessionType, sessionID)
	if not ok then
		ns.LogOnce("damageError", "C_DamageMeter's session call failed: " .. tostring(session))
		list:Finish(0, L["No data yet"])
		return
	end
	if not Readable(session) then
		Hidden(W, list)
		return
	end
	FillSources(W, list, info, session)
end
for _, W in ipairs({ Damage, Second }) do
	W.refresh = function() Refresh(W) end
end

function ns.ResetMeters()
	local meter = C_DamageMeter
	if type(meter) ~= "table" or type(meter.ResetAllCombatSessions) ~= "function" then
		ns.LogOnce("noReset", "C_DamageMeter.ResetAllCombatSessions is missing; nothing is reset")
		return
	end
	K.Combat.Queue(function() K.Call(meter.ResetAllCombatSessions) end)
end

local function Yes(call, ...)
	if type(call) ~= "function" then
		return false
	end
	local ok, value = pcall(call, ...)
	return ok and not IsSecret(value) and value == true
end

local function Locked()
	local chat = C_ChatInfo
	local check = type(chat) == "table" and chat.InChatMessagingLockdown
	if InCombatLockdown() == true then
		return true
	end
	if type(check) ~= "function" then
		return false
	end
	local ok, locked = pcall(check)
	return not ok or IsSecret(locked) or locked ~= false
end

local function Channel()
	local open = {
		INSTANCE_CHAT = LE_PARTY_CATEGORY_INSTANCE ~= nil and Yes(IsInGroup, LE_PARTY_CATEGORY_INSTANCE),
		RAID = Yes(IsInRaid), PARTY = Yes(IsInGroup), GUILD = Yes(IsInGuild),
	}
	local to = ns.Get("damage.reportTo")
	if to ~= "auto" then
		return open[to] and to or nil
	end
	for _, chat in ipairs(GROUP_CHATS) do
		if open[chat] then return chat end
	end
	return nil
end

local function Report(W)
	local list, drill = W.list, W.drill
	local count = list.panel:IsShown() and min(list.count or 0, REPORT_LINES) or 0
	if count == 0 then
		K.Print(L["No data yet"])
		return
	end
	if Locked() then
		K.Print(L["The meter can report after combat."])
		return
	end
	local lines = { string.format("%s%s (%s)", drill.active and drill.name .. ": " or "", Info(W).label, FIGHTS[ns.Get(W.sessionKey)]) }
	for i = 1, count do
		local slot = W.slots[i]
		local label, text, share = slot.label, slot.text, slot.share
		if IsSecret(label) or IsSecret(text) or IsSecret(share) or type(label) ~= "string" then
			K.Print(L["The meter can report after combat."])
			return
		end
		lines[#lines + 1] = string.format("%d. %s %s", slot.place, label, text) .. (share ~= "" and " (" .. share .. ")" or "")
	end
	local chat, send = Channel(), C_ChatInfo and C_ChatInfo.SendChatMessage
	for _, line in ipairs(lines) do
		if not chat or type(send) ~= "function" then
			K.Print(line)
		elseif not pcall(send, line, chat) then
			ns.LogOnce("reportFailed", "C_ChatInfo.SendChatMessage refused the report")
			return
		end
	end
end

local function Schedule(W)
	if W.pending then
		return
	end
	W.pending = true
	C_Timer.After(ns.Get("damage.refresh"), W.refresh)
end

local function SkinVisibility()
	if Alone() or ns.windowsHidden then
		HideBlizzard()
	else
		RestoreBlizzard()
	end
end

local function OnEvent(W, event, _, sessionID)
	if event == "PLAYER_REGEN_DISABLED" then
		W.combat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		W.combat = false
	elseif event == "DAMAGE_METER_RESET" then
		W.currentID = nil
		Back(W)
	elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
		local id = Logic.Plain(sessionID)
		if id and id > 0 then
			W.currentID = id
		end
	end
	Schedule(W)
end
Second.OnEvent = OnEvent

function Damage:OnEvent(event, meterType, sessionID)
	if Damage.Mode() ~= "window" then
		SkinVisibility()
		return
	end
	OnEvent(self, event, meterType, sessionID)
end

local function Reporting(W)
	if ns.Get("damage.report") and Yes(IsShiftKeyDown) then
		Report(W)
		return true
	end
	return false
end

local function OnRowClick(W, list, i, button)
	if Reporting(W) then
		return
	end
	local drill = W.drill
	if drill.active then
		Back(W)
		Refresh(W)
		return
	end
	local slot = W.slots[i]
	if W.resting or button ~= "LeftButton" or not slot or not slot.ok or i > (list.count or 0) or not SourceApi() then
		return
	end
	drill.active = true
	drill.guid, drill.creature, drill.name = slot.guid, slot.creature, slot.name
	drill.class, drill.reaction, drill.own = slot.class, slot.reaction, slot.own
	W.view = W.view + 1
	list:SetIcons(true)
	Refresh(W)
end

local function NextSession(W)
	local session = ns.Get(W.sessionKey)
	for i, value in ipairs(SESSION_ORDER) do
		if value == session then
			return SESSION_ORDER[i % #SESSION_ORDER + 1]
		end
	end
	return SESSION_ORDER[1]
end

local function OnClick(W, _, button)
	if Reporting(W) then
		return
	end
	if W.drill.active then
		Back(W)
		Refresh(W)
		return
	end
	if button == "RightButton" then
		K.Options.Write(ns.MODULE, W.sessionKey, NextSession(W))
		return
	end
	local _, index = Info(W)
	local nextType = ns.METER_TYPES[index % #ns.METER_TYPES + 1]
	K.Options.Write(ns.MODULE, W.meterKey, nextType.value)
end

local function Tooltip(W, tip)
	if W.drill.active then
		tip:AddLine(L["Click to go back to every source."])
	else
		tip:AddLine(L["Click a name for its spells. Click the card for the next meter."])
		tip:AddLine(L["Scroll for more names."])
		tip:AddLine(L["Click Now, Last or All for the next fight: this fight, the last fight or every fight."])
	end
	if ns.Get("damage.report") then
		tip:AddLine(L["Shift-click to report these rows to chat."])
	end
end

local function SwitchTooltip(W, tip)
	tip:AddLine(L["Click for the next fight: this fight, the last fight or every fight."])
	if W.list and Api() then
		local id, name = PreviousFight(W)
		if id then
			tip:AddLine(string.format(L["Last fight: %s"], name or L["Previous fight"]))
		else
			tip:AddLine(L["No earlier fight yet"])
		end
	end
end

local function OnTitle(W, _, button)
	if Reporting(W) then
		return
	end
	if W.drill.active then
		Back(W)
		Refresh(W)
		return
	end
	if button == "RightButton" then
		K.Options.Write(ns.MODULE, W.sessionKey, NextSession(W))
		return
	end
	K.Options.Write(ns.MODULE, W.meterKey, FAMILY[Info(W).value] or "DamageDone")
end

local function TitleTooltip(W, tip)
	if W.drill.active then
		tip:AddLine(L["Click to go back to every source."])
		return
	end
	tip:AddLine(L["Click to show damage or healing."])
end

local function OnWheel(W, _, delta)
	local top = W.top or 0
	local offset = max(0, min(top, (W.offset or 0) + (delta > 0 and -1 or 1)))
	if offset ~= W.offset then
		W.offset = offset
		Refresh(W)
	end
end

local function Icons()
	return ns.Get("damage.icons") == true
end

local function OnSwitch(W)
	if Reporting(W) then
		return
	end
	K.Options.Write(ns.MODULE, W.sessionKey, NextSession(W))
end

local function Columns()
	return { value = true, percent = ns.Get("damage.percent") }
end

local function Build(W)
	local function Bind(call) return function(...) return call(W, ...) end end
	local width, height = ns.Footprint(KEY)
	if W == Second then width = SECOND_WIDTH end
	W.list = ns.BarList.New(K.Scale.Root(), "damage", {
		key = W.key, width = width or 269, height = height or 158, columns = Columns, onClick = Bind(OnClick), block = true,
		onRowClick = Bind(OnRowClick), tooltip = Bind(Tooltip), onSwitch = Bind(OnSwitch), switchTooltip = Bind(SwitchTooltip),
		rowTooltip = Bind(RowTooltip), rowSplits = Bind(RowSplits), rowSplit = Bind(RowSplit),
		onTitle = Bind(OnTitle), titleTooltip = Bind(TitleTooltip), onWheel = Bind(OnWheel), icons = Icons, onReset = ns.ResetMeters,
	})
	W.holder = W.list.holder
	if W == Damage then
		ns.Place(W.holder, KEY, LIMITS)
	else
		K.Layout.Register(W.holder, SECOND, SECOND_PLACE, { label = L["Second damage window"], module = ns.MODULE, resizable = true,
			minWidth = LIMITS.minWidth, maxWidth = LIMITS.maxWidth, minHeight = LIMITS.minHeight, maxHeight = LIMITS.maxHeight })
	end
end

local function Resized(W)
	if W.list then
		W.list:Restyle()
		Schedule(W)
	end
end
Damage.Resized, Second.Resized = Resized, Resized

function Damage:Start()
	if not self.holder then
		Build(self)
	end
	self:Apply()
end

local function Track(W)
	local meter, session = ns.Get(W.meterKey), ns.Get(W.sessionKey)
	if meter ~= W.meter then
		W.meter = meter
		Back(W)
		W.view = W.view + 1
	end
	if session ~= W.session then
		W.session = session
		W.view = W.view + 1
	end
end

local function Open(W)
	abbreviate = ns.Get("damage.englishUnits") and Logic.Abbreviate or Logic.GameUnits
	W.holder:Show()
	for _, event in ipairs(EVENTS) do
		ns.Watch(W, event)
	end
	Track(W)
	W.list:Restyle()
	W.combat = InCombatLockdown() == true
	Refresh(W)
end

local function Close(W)
	ns.UnwatchAll(W)
	W.currentID = nil
	Back(W)
	W.list.panel:Hide()
	W.holder:Hide()
end

function Damage:Apply()
	if not self.holder or not ns.IsRunning() then
		return
	end
	ns.SetLive(KEY, Damage.Wanted())
	if not ns.MeterShown("damage") then
		self:Stop()
		if ns.Get("followRole") and not ns.damageOverlap then
			HideBlizzard()
		end
		return
	end
	if Damage.Mode() == "window" then
		ns.DamageSkin.Deactivate()
		ns.DamageCVar.Want(false)
		HideBlizzard()
		Open(self)
		return
	end
	if ns.Get("damage.mode") ~= "skin" then
		ns.LogOnce("damageSkinPath", "C_DamageMeter is missing; the damage meter restyles Blizzard's window")
	end
	ns.UnwatchAll(self)
	self.currentID = nil
	for _, event in ipairs(SKIN_EVENTS) do
		ns.Watch(self, event)
	end
	Back(self)
	self.list.panel:Hide()
	self.holder:Hide()
	SkinVisibility()
	ns.DamageCVar.Want(true)
	ns.DamageSkin.Activate()
end

function Damage:Stop()
	if not self.holder then
		return
	end
	Close(self)
	RestoreBlizzard()
	ns.DamageSkin.Deactivate()
	ns.DamageCVar.Want(false)
end

function Second:Apply()
	if not ns.IsRunning() then
		return
	end
	local on = Second.Wanted()
	ns.SetLive(SECOND, on)
	if not on then
		self:Stop()
		return
	end
	if not self.holder then
		Build(self)
	end
	Open(self)
end
Second.Start = Second.Apply

function Second:Stop()
	if self.holder then
		Close(self)
	end
end
