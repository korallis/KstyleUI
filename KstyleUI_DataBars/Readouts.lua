-- Readouts.lua: the data bar's guarded travel, social, account, map, combat, audio, profession and plugin readouts in the strip's shared registries.
local _, ns = ...

local K, L, Strip = ns.K, ns.L, ns.Strip
local Call, IsNumber = ns.Sources.Call, ns.IsNumber
local floor, format = math.floor, string.format
local Readouts = {}
ns.Readouts = Readouts

local function Plain(value, kind)
	if not ns.IsSecret(value) and type(value) == kind then return value end
end

local function Number(fn, ...)
	local value = Call(fn, ...)
	if IsNumber(value) then return value end
end

local function Count(value)
	return IsNumber(value) and tostring(value) or L["--"]
end

local function Settings(s)
	return s or ns.Settings().strip
end

local function Clamp(value, low, high, fallback)
	return IsNumber(value) and math.max(low, math.min(high, floor(value))) or fallback
end

function Readouts.CanSwitch()
	local api = C_SpecializationInfo
	local groups = Number(GetNumSpecGroups)
	local group = api and Number(api.GetActiveSpecGroup)
	return api and type(api.SetActiveSpecGroup) == "function" and groups and groups > 1 and group and (group == 1 or group == 2), group
end

local function Loadout(specID)
	local talents, traits = C_ClassTalents, C_Traits
	local id = talents and specID and Number(talents.GetLastSelectedSavedConfigID, specID)
	local info = id and traits and Call(traits.GetConfigInfo, id)
	return not ns.IsSecret(info) and type(info) == "table" and Plain(info.name, "string") or nil
end

function Readouts.SpecText(s, name, group, loadout)
	local custom = group == 1 and s.spec1Text or group == 2 and s.spec2Text or ""
	local text = custom ~= "" and custom or name
	if s.specLoadout and loadout then text = text .. " / " .. loadout end
	return s.specUpper and text:upper() or text
end

local function Spec(s)
	s = Settings(s)
	local api = C_SpecializationInfo
	local index = api and Number(api.GetSpecialization)
	local specID, name
	if index then specID, name = Call(api.GetSpecializationInfo, index) end
	name = Plain(name, "string")
	if not name then return L["--"] end
	local group = (s.spec1Text ~= "" or s.spec2Text ~= "") and Number(api.GetActiveSpecGroup) or nil
	return Readouts.SpecText(s, name, group, s.specLoadout and Loadout(Plain(specID, "number")) or nil)
end

local function Hearth()
	local travel = K.Safe.Side(K).travelData
	if travel then return travel.Hearth() end
	return L["--"], L["--"]
end

function Readouts.HearthText(s, bind, cooldown)
	local mode = s.hearthText
	if mode == "location" or mode == "smart" and cooldown == L["ready"] then return bind end
	if mode == "cooldown" or mode == "smart" then return cooldown end
	return cooldown .. " " .. bind
end

function Readouts.ChoiceName(value)
	local kind, id = value:match("^(%a+):(%d+)$")
	id = tonumber(id)
	if kind == "spell" and C_Spell then
		local info = Call(C_Spell.GetSpellInfo, id)
		return not ns.IsSecret(info) and type(info) == "table" and Plain(info.name, "string") or nil
	end
	return kind == "item" and C_Item and Plain(Call(C_Item.GetItemNameByID, id), "string") or nil
end

function Readouts.TravelChoices(click)
	local out, travel = { { value = "", label = click == "hearthLeft" and L["Hearthstone"] or L["None"] } }, K.Safe.Side(K).travelData
	local groups = travel and travel.Read() or {}
	for g = 1, 2 do
		for _, entry in ipairs(groups[g] or {}) do
			if entry.name and (entry.kind ~= "item" or entry.id ~= 6948 or click ~= "hearthLeft") then out[#out + 1] = { value = entry.kind .. ":" .. entry.id, label = entry.name } end
		end
	end
	return out
end

function Readouts.SaveHearth()
	if not Settings().hearthOthers then return end
	local bind, key = Plain(Call(GetBindLocation), "string"), K.Store.CharacterKey()
	if not (bind and key) then return end
	local account = K.Store.Account()
	if type(account.databarHearth) ~= "table" then account.databarHearth = {} end
	account.databarHearth[key] = bind
end

local function Bags()
	local api = C_Container
	if not api then return end
	if type(api.CalculateTotalNumberOfFreeBagSlots) == "function" then
		return Number(api.CalculateTotalNumberOfFreeBagSlots)
	end
	if type(api.GetContainerNumFreeSlots) ~= "function" then return end
	local total = 0
	local inventory = Constants and Constants.InventoryConstants
	for bag = 0, inventory and Plain(inventory.NumBagSlots, "number") or 4 do
		local free = Number(api.GetContainerNumFreeSlots, bag)
		if not free then return end
		total = total + free
	end
	return total
end

local function Slots(reagent)
	local api = C_Container
	if not api or type(api.GetContainerNumFreeSlots) ~= "function" or type(api.GetContainerNumSlots) ~= "function" then return end
	local inventory = Constants and Constants.InventoryConstants
	local last = inventory and Plain(inventory.NumBagSlots, "number") or 4
	if reagent then last = last + (inventory and Plain(inventory.NumReagentBagSlots, "number") or 0) end
	local free, total = 0, 0
	for bag = 0, last do
		local open, size = Number(api.GetContainerNumFreeSlots, bag), Number(api.GetContainerNumSlots, bag)
		if not open or not size then return end
		free, total = free + open, total + size
	end
	return free, total
end

function Readouts.BagText(s, free, total)
	if not IsNumber(free) then return L["--"] end
	local low = (s.bagsLow or 0) > 0 and free < s.bagsLow and "low" or nil
	local display, used = s.bagsDisplay, IsNumber(total) and total - free or nil
	if used and display == "used" then return tostring(used), low end
	if used and display == "freeTotal" then return free .. "/" .. total, low end
	if used and display == "usedTotal" then return used .. "/" .. total, low end
	return tostring(free), low
end

local lastRoster
function Readouts.RequestRoster()
	if Plain(Call(IsInGuild), "boolean") ~= true then return end
	local now = Number(GetTime)
	if not now or lastRoster and now - lastRoster < 60 then return end
	if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
		lastRoster = now
		Call(C_GuildInfo.GuildRoster)
	end
end

local function Guild()
	local _, online = Call(GetNumGuildMembers)
	return Count(online)
end

local function Friends()
	local wow = C_FriendList and Number(C_FriendList.GetNumOnlineFriends)
	local _, battle = Call(BNGetNumFriends)
	if wow and IsNumber(battle) then return Count(wow + battle), wow, battle end
	return L["--"], wow, IsNumber(battle) and battle or nil
end

local function GuildRows()
	local club, rows, presence = C_Club, {}, Enum and Enum.ClubMemberPresence or {}
	local id = club and Call(club.GetGuildClubId)
	local members = id and not ns.IsSecret(id) and Call(club.GetClubMembers, id)
	if ns.IsSecret(members) or type(members) ~= "table" then return rows end
	local online = { [presence.Online or 1] = true, [presence.Away or 4] = true, [presence.Busy or 5] = true }
	for _, member in ipairs(members) do
		local info = Call(club.GetMemberInfo, id, member)
		if not ns.IsSecret(info) and type(info) == "table" and Plain(info.isSelf, "boolean") ~= true and online[Plain(info.presence, "number") or 0] then
			rows[#rows + 1] = { Plain(info.name, "string") or L["--"], Plain(info.zone, "string"), Plain(info.memberNote, "string") }
		end
	end
	return rows
end

local function FriendRows()
	local list, bn, rows = C_FriendList, C_BattleNet, {}
	for i = 1, list and Number(list.GetNumFriends) or 0 do
		local info = Call(list.GetFriendInfoByIndex, i)
		if not ns.IsSecret(info) and type(info) == "table" and Plain(info.connected, "boolean") then
			rows[#rows + 1] = { Plain(info.name, "string") or L["--"], Plain(info.area, "string"), Plain(info.notes, "string") }
		end
	end
	for i = 1, bn and Number(BNGetNumFriends) or 0 do
		local info = Call(bn.GetFriendAccountInfo, i)
		local game = not ns.IsSecret(info) and type(info) == "table" and info.gameAccountInfo
		if not ns.IsSecret(game) and type(game) == "table" and Plain(game.isOnline, "boolean") then
			rows[#rows + 1] = { Plain(info.accountName, "string") or L["--"], Plain(game.characterName, "string"), Plain(info.note, "string") }
		end
	end
	return rows
end

function Readouts.Names(tip, rows, notes)
	local cap = Clamp(Settings().socialList, 0, 40, 0)
	if cap == 0 or #rows == 0 then return end
	table.sort(rows, function(a, b) return a[1] < b[1] end)
	tip:AddDivider()
	for i = 1, math.min(cap, #rows) do
		local row = rows[i]
		tip:AddDoubleLine(row[1], row[2] or "")
		if notes and row[3] and row[3] ~= "" then tip:AddLine(row[3], "textDisabled") end
	end
	if #rows > cap then tip:AddLine(format(L["and %d more"], #rows - cap), "textDisabled") end
end

local supplies
function Readouts.Supplies()
	if supplies then return supplies end
	supplies = {}
	local bags, items, E = C_Container, C_Item, Enum or {}
	local class, misc = E.ItemClass or {}, E.ItemMiscellaneousSubclass or {}
	local reagent, other, otherReagent = class.Reagent or 5, class.Miscellaneous or 15, misc.Reagent or 1
	if bags and items and type(bags.GetContainerItemInfo) == "function" and type(items.GetItemInfoInstant) == "function" then
		local inventory, seen = Constants and Constants.InventoryConstants, {}
		for bag = 0, (inventory and Plain(inventory.NumBagSlots, "number") or 4) + (inventory and Plain(inventory.NumReagentBagSlots, "number") or 0) do
			for slot = 1, Number(bags.GetContainerNumSlots, bag) or 0 do
				local info = Call(bags.GetContainerItemInfo, bag, slot)
				local id = not ns.IsSecret(info) and type(info) == "table" and Plain(info.itemID, "number")
				if id then
					local _, _, _, _, _, kind, sub = items.GetItemInfoInstant(id)
					kind, sub = Plain(kind, "number"), Plain(sub, "number")
					if kind == reagent and sub == 0 or kind == other and sub == otherReagent then
						if not seen[id] then
							seen[id] = { name = Plain(info.itemName, "string") or L["--"], icon = Plain(info.iconFileID, "number"), count = 0 }
							supplies[#supplies + 1] = seen[id]
						end
						seen[id].count = seen[id].count + (Plain(info.stackCount, "number") or 0)
					end
				end
			end
		end
	end
	local paper = C_PaperDollInfo
	local slot = paper and Plain(Call(UnitUsesAmmo, "player"), "boolean") and Number(paper.GetInventorySlotInfo, "AmmoSlot")
	local ammo = slot and Number(GetInventoryItemID, "player", slot)
	if ammo then
		table.insert(supplies, 1, { ammo = true, name = items and Plain(Call(items.GetItemNameByID, ammo), "string") or L["--"], icon = Number(GetInventoryItemTexture, "player", slot), count = Number(GetInventoryItemCount, "player", slot) or 0 })
	end
	return supplies
end

function Readouts.SupplyText(s, list)
	local parts = {}
	for _, entry in ipairs(list) do
		if #parts < 3 and (s.reagentsShown == "all" or (s.reagentsShown == "ammo") == (entry.ammo == true)) then
			parts[#parts + 1] = (entry.icon and "|T" .. entry.icon .. ":0|t " or "") .. entry.count .. (s.reagentsLabel and " " .. entry.name or "")
		end
	end
	return #parts > 0 and table.concat(parts, " \194\183 ") or L["--"]
end

local function Currencies(tip, icons)
	local api = C_CurrencyInfo
	if not api or type(api.GetBackpackCurrencyInfo) ~= "function" then return L["--"] end
	local parts = {}
	for index = 1, 3 do
		local info = Call(api.GetBackpackCurrencyInfo, index)
		if ns.IsSecret(info) then
			parts[#parts + 1] = L["--"]
		elseif type(info) == "table" then
			local name = Plain(info.name, "string") or L["--"]
			local value = Count(info.quantity)
			local icon = icons and Plain(info.iconFileID, "number")
			parts[#parts + 1] = value .. " " .. (icon and "|T" .. icon .. ":0|t" or name)
			if tip then tip:AddDoubleLine(name, value) end
		end
	end
	return table.concat(parts, " \194\183 ")
end

local function Days(history)
	local days = {}
	for day, total in pairs(history) do
		if Plain(day, "string") and IsNumber(total) then days[#days + 1] = day end
	end
	table.sort(days)
	return days
end

function Readouts.SaveGold()
	local account = K.Store.Account()
	if type(account.databarGold) ~= "table" then account.databarGold = {} end
	local money, key = Number(GetMoney), K.Store.CharacterKey()
	if money and key then account.databarGold[key] = money end
	local today = Settings().goldHistory and Plain(Call(date, "%Y-%m-%d"), "string")
	if not today then return end
	local total = 0
	for _, gold in pairs(account.databarGold) do
		if IsNumber(gold) then total = total + gold end
	end
	if type(account.databarGoldHistory) ~= "table" then account.databarGoldHistory = {} end
	local history = account.databarGoldHistory
	history[today] = total
	local days = Days(history)
	for i = 1, #days - 7 do history[days[i]] = nil end
end

function Readouts.XPText(s, info)
	if not (info and IsNumber(info.current) and IsNumber(info.max) and info.max > 0) then return L["--"] end
	local Format = ns.Format
	local text = s.xpText == "values" and Format.Number(info.current) .. " / " .. Format.Number(info.max) or Format.Percent(info.current, info.max, info.kind == "paragon") .. "%"
	local label = s.xpFormat == "context" and Plain(info.label, "string")
	return label and label .. " " .. text or text
end

local function XP(s)
	s = Settings(s)
	local info = s.xpMode ~= "rep" and ns.Sources.XP() or nil
	if not info and s.xpMode ~= "xp" then info = ns.Sources.Reputation() end
	return Readouts.XPText(s, info)
end

function Readouts.ItemLevelText(s, value)
	if not IsNumber(value) or value < 0 then return L["--"] end
	local decimals = Clamp(s.itemLevelDecimals, 0, 2, 0)
	local text = decimals == 0 and tostring(floor(value)) or format("%." .. decimals .. "f", value)
	local prefix = s.itemLevelPrefix == "short" and L["ilvl"] or s.itemLevelPrefix == "long" and L["Item level"]
	return prefix and prefix .. " " .. text or text
end

function Readouts.ClockText(s, text, mail, rest)
	if s.clockMail and mail then text = text .. " " .. L["mail"] end
	if s.clockRest and rest then text = text .. " " .. L["resting"] end
	return text
end

function Readouts.CoordsText(s, x, y)
	local f = "%." .. Clamp(s.coordsDecimals, 0, 2, 1) .. "f"
	return format(f .. ", " .. f, x * 100, y * 100)
end

local function Coords(s)
	local map = C_Map and Number(C_Map.GetBestMapForUnit, "player")
	local position = map and Call(C_Map.GetPlayerMapPosition, map, "player")
	if ns.IsSecret(position) or type(position) ~= "table" then return L["--"] end
	local x, y = Call(position.GetXY, position)
	if not (IsNumber(x) and IsNumber(y)) then return L["--"] end
	return Readouts.CoordsText(Settings(s), x, y)
end

local fight = { last = 0 }
local function Combat()
	local now = Number(GetTime)
	local seconds = fight.start and now and math.max(0, now - fight.start) or fight.last
	return format("%d:%02d", floor(seconds / 60), floor(seconds % 60))
end

local played
function Readouts.Played(seconds)
	local days, hours, minutes = floor(seconds / 86400), floor(seconds % 86400 / 3600), floor(seconds % 3600 / 60)
	if days > 0 then return format(L["%dd %dh"], days, hours) end
	if hours > 0 then return format(L["%dh %dm"], hours, minutes) end
	return format(L["%dm"], minutes)
end

local function Played(total)
	local now = Number(GetTime)
	if not played or not now then return L["--"] end
	return Readouts.Played((total and played.total or played.level) + now - played.at)
end

local CHANNELS = { Master = true, SFX = true, Music = true, Ambience = true, Dialog = true }
local function CVar(name)
	local api = C_CVar
	return api and Plain(Call(api.GetCVar, name), "string")
end

function Readouts.AudioText(muted, volume)
	if muted then return L["muted"] end
	return IsNumber(volume) and floor(volume * 100 + 0.5) .. "%" or L["--"]
end

local function Audio(s)
	local channel = Settings(s).audioChannel
	return Readouts.AudioText(CVar("Sound_EnableAllSound") == "0", tonumber(CVar("Sound_" .. (CHANNELS[channel] and channel or "Master") .. "Volume") or ""))
end

local PROFESSION = { prof1 = 1, prof2 = 2 }
local function Profession(slot)
	local index = Plain((select(slot, Call(GetProfessions))), "number")
	if not index then return end
	local name, _, rank, maxRank = Call(GetProfessionInfo, index)
	return Plain(name, "string"), Plain(rank, "number"), Plain(maxRank, "number")
end

function Readouts.ProfessionText(s, name, rank, maxRank)
	if not name then return L["--"] end
	if s.professionText == "values" and IsNumber(rank) and IsNumber(maxRank) then return name .. " " .. rank .. "/" .. maxRank end
	return name
end

local function Broker(s)
	local stub, name = rawget(_G, "LibStub"), Settings(s).brokerPlugin
	if name == "" or type(stub) ~= "table" or type(stub.GetLibrary) ~= "function" then return end
	local ldb = Call(stub.GetLibrary, stub, "LibDataBroker-1.1", true)
	local object = type(ldb) == "table" and Call(ldb.GetDataObjectByName, ldb, name)
	return type(object) == "table" and object or nil
end

function Readouts.BrokerText(s, label, text)
	return s.brokerLabel and label and label .. " " .. text or text
end

local function BrokerValue(s)
	s = Settings(s)
	local object = Broker(s)
	if not object then return L["--"] end
	local text = Plain(object.text, "string") or IsNumber(object.value) and object.value .. (Plain(object.suffix, "string") or "") or Plain(object.value, "string") or L["--"]
	return Readouts.BrokerText(s, Plain(object.label, "string") or s.brokerPlugin, text)
end

local titles = {
	xp = L["Experience and reputation"],
	bags = L["Bag space"], spec = L["Specialization"], hearth = L["Hearthstone"],
	guild = L["Guild"], friends = L["Friends"], currencies = L["Currencies"],
	location = L["Location"], itemLevel = L["Item level"], coords = L["Coordinates"], combat = L["Combat"],
	played = L["Time played"], audio = L["Audio"], prof1 = L["Profession 1"], prof2 = L["Profession 2"],
	broker = L["DataBroker"], spacer = L["Spacer"], reagents = L["Class resources"],
}
for id, title in pairs(titles) do
	Strip.LABELS[id] = { full = title, short = title, inline = id == "bags" and L["free"] or id == "guild" and L["guild"] or id == "friends" and L["friends"] or "" }
	Strip.TITLES[id] = title
end
local FREE, USED = Strip.LABELS.bags, { full = titles.bags, short = titles.bags, inline = L["used"] }
Strip.LABELS.bags = function(s) return (s.bagsDisplay == "used" or s.bagsDisplay == "usedTotal") and USED or FREE end
for _, id in ipairs({ "hearth", "coords", "combat", "played", "broker" }) do Strip.TIMED[id] = true end
Strip.VALUES.xp = XP
Strip.TOOLTIPS.xp = function(_, tip) tip:AddDoubleLine(L["Experience and reputation"], XP()) end
Strip.VALUES.bags = function(s)
	s = Settings(s)
	if s.bagsDisplay == "free" and not s.bagsReagent then return Readouts.BagText(s, Bags()) end
	return Readouts.BagText(s, Slots(s.bagsReagent))
end
Strip.VALUES.spec = Spec
Strip.VALUES.hearth = function(s)
	return Readouts.HearthText(Settings(s), Hearth())
end
Strip.VALUES.guild = Guild
Strip.VALUES.friends = Friends
Strip.VALUES.currencies = function(s) return Currencies(nil, Settings(s).currencyIcons) end
Strip.VALUES.reagents = function(s) return Readouts.SupplyText(Settings(s), Readouts.Supplies()) end
Strip.VALUES.location = function() return Plain(Call(GetZoneText), "string") or L["--"] end
Strip.VALUES.itemLevel = function(s)
	s = Settings(s)
	return Readouts.ItemLevelText(s, (select(s.itemLevelSource == "overall" and 1 or 2, Call(GetAverageItemLevel))))
end
local clock = Strip.VALUES.time
Strip.VALUES.time = function(s)
	s = Settings(s)
	local text = clock(s)
	return text and Readouts.ClockText(s, text, s.clockMail and Plain(Call(HasNewMail), "boolean"), s.clockRest and Plain(Call(IsResting), "boolean"))
end
Strip.VALUES.coords = Coords
Strip.VALUES.combat = Combat
Strip.VALUES.played = function(s) return Played(Settings(s).playedTotal) end
Strip.VALUES.audio = Audio
Strip.VALUES.broker = BrokerValue
Strip.VALUES.spacer = function() return "" end
Strip.WIDTH.location = function(s) return s.locationWidth == "manual" and s.locationMaxWidth or nil end
Strip.WIDTH.broker = function(s) return (s.brokerWidth or 0) > 0 and s.brokerWidth or nil end
Strip.WIDTH.spacer = function(s) return s.fontSize end
for id, slot in pairs(PROFESSION) do
	Strip.VALUES[id] = function(s) return Readouts.ProfessionText(Settings(s), Profession(slot)) end
	Strip.TOOLTIPS[id] = function(_, tip)
		local name, rank, maxRank = Profession(slot)
		tip:AddDoubleLine(name or L["--"], rank and maxRank and rank .. " / " .. maxRank or L["--"])
	end
end
for _, id in ipairs({ "location", "itemLevel", "coords" }) do
	Strip.TOOLTIPS[id] = function(_, tip) tip:AddDoubleLine(titles[id], Strip.VALUES[id]()) end
end

function Readouts.Visible(id)
	if id == "guild" then return Plain(Call(IsInGuild), "boolean") == true end
	if id == "spec" then local groups = Number(GetNumSpecGroups); return groups and groups > 1 end
	if id == "currencies" then return C_CurrencyInfo and type(C_CurrencyInfo.GetBackpackCurrencyInfo) == "function" and Currencies() ~= "" end
	if id == "combat" then return not Settings().combatOnly or fight.start ~= nil or InCombatLockdown() end
	if PROFESSION[id] then return Profession(PROFESSION[id]) ~= nil end
	if id == "broker" then return Settings().brokerPlugin ~= "" end
	if id == "spacer" then return Strip.OneLine(Settings()) end
	return true
end

local function ProtectedNote(tip, action)
	tip:AddDivider()
	tip:AddLine(InCombatLockdown() and L["Available after combat."] or action, "text")
end

Strip.TOOLTIPS.bags = function(_, tip)
	tip:AddDoubleLine(L["Free slots"], Count(Bags()))
	ProtectedNote(tip, L["Click: open your bags."])
end
Strip.TOOLTIPS.spec = function(_, tip)
	tip:AddDoubleLine(L["Specialization"], Spec())
	ProtectedNote(tip, Readouts.CanSwitch() and L["Click: switch specialization."] or L["Click: open talents."])
end
Strip.TOOLTIPS.hearth = function(_, tip)
	local bind, cooldown = Hearth()
	tip:AddDoubleLine(L["Home"], bind)
	tip:AddDoubleLine(L["Cooldown"], cooldown)
	if Settings().hearthOthers then
		Readouts.SaveHearth()
		local homes, me, keys = K.Store.Account().databarHearth, K.Store.CharacterKey(), {}
		for key in pairs(type(homes) == "table" and homes or {}) do
			if Plain(key, "string") and key ~= me then keys[#keys + 1] = key end
		end
		table.sort(keys)
		if #keys > 0 then tip:AddDivider() end
		for _, key in ipairs(keys) do tip:AddDoubleLine(key, Plain(homes[key], "string") or L["--"]) end
	end
	local s = Settings()
	local left = s.hearthLeft ~= "" and Readouts.ChoiceName(s.hearthLeft)
	ProtectedNote(tip, left and format(L["Click: %s."], left) or L["Click: use your Hearthstone."])
	for _, click in ipairs({ { "hearthRight", L["Right-click: %s."] }, { "hearthMiddle", L["Middle-click: %s."] } }) do
		local name = not InCombatLockdown() and s[click[1]] ~= "" and Readouts.ChoiceName(s[click[1]])
		if name then tip:AddLine(format(click[2], name), "text") end
	end
end
Strip.TOOLTIPS.guild = function(_, tip)
	Readouts.RequestRoster()
	tip:AddDoubleLine(L["Online"], Guild())
	if Settings().socialList > 0 then Readouts.Names(tip, GuildRows(), Settings().guildNotes) end
end
Strip.TOOLTIPS.friends = function(_, tip)
	local _, wow, battle = Friends()
	tip:AddDoubleLine(L["World of Warcraft"], Count(wow))
	tip:AddDoubleLine(L["Battle.net"], Count(battle))
	if Settings().socialList > 0 then Readouts.Names(tip, FriendRows(), Settings().friendNotes) end
end
Strip.TOOLTIPS.reagents = function(_, tip)
	local any = false
	for _, entry in ipairs(Readouts.Supplies()) do
		any = true
		tip:AddDoubleLine((entry.icon and "|T" .. entry.icon .. ":0|t " or "") .. entry.name, tostring(entry.count))
	end
	if not any then tip:AddLine(L["You carry no class reagents or ammunition."], "textDisabled") end
end
Strip.TOOLTIPS.currencies = function(_, tip)
	local text = Currencies(tip)
	if text == "" or text == L["--"] then tip:AddLine(L["--"], "textDisabled") end
end
Strip.TOOLTIPS.combat = function(_, tip)
	tip:AddDoubleLine(fight.start and L["This fight"] or L["Last fight"], Combat())
end
Strip.TOOLTIPS.played = function(_, tip)
	tip:AddDoubleLine(L["Total"], Played(true))
	tip:AddDoubleLine(L["This level"], Played(false))
	tip:AddDivider()
	tip:AddLine(L["Click: ask the server for your time played."], "text")
end
Strip.TOOLTIPS.audio = function(_, tip)
	tip:AddDoubleLine(L["Volume"], Audio())
	ProtectedNote(tip, L["Click: mute or unmute all sound."])
end
Strip.TOOLTIPS.broker = function(_, tip)
	local object = Broker()
	tip:AddDoubleLine(object and Plain(object.label, "string") or Settings().brokerPlugin, BrokerValue())
	if object and type(object.OnClick) == "function" then ProtectedNote(tip, L["Click: open the plugin."]) end
end
Strip.TOOLTIP_EXTRA.time = function(_, tip)
	tip:AddDoubleLine(L["Pending invites"], Count(C_Calendar and Number(C_Calendar.GetNumPendingInvites)))
end

local function Signed(copper)
	return (copper > 0 and "+" or "") .. ns.Format.Money(copper, "full")
end

Strip.TOOLTIP_EXTRA.gold = function(_, tip)
	local s = Settings()
	Readouts.SaveGold()
	local account = K.Store.Account()
	if s.goldCharacters then
		local keys, gold = {}, account.databarGold
		for key in pairs(gold) do
			if Plain(key, "string") then keys[#keys + 1] = key end
		end
		table.sort(keys)
		if #keys > 0 then tip:AddDivider() end
		for _, key in ipairs(keys) do
			local money = gold[key]
			tip:AddDoubleLine(key, IsNumber(money) and ns.Format.Money(money, "full") or L["--"])
		end
	end
	local history = s.goldHistory and account.databarGoldHistory
	local days = type(history) == "table" and Days(history) or {}
	if #days > 1 then
		local now = history[days[#days]]
		tip:AddDivider()
		tip:AddDoubleLine(format(L["Since %s"], days[#days - 1]), Signed(now - history[days[#days - 1]]))
		if #days > 2 then tip:AddDoubleLine(format(L["Since %s"], days[1]), Signed(now - history[days[1]])) end
	end
end

Strip.ACTIONS.spec = function(_, mouse)
	if mouse == "RightButton" or InCombatLockdown() then return end
	local can, group = Readouts.CanSwitch()
	if can then C_SpecializationInfo.SetActiveSpecGroup(3 - group) end
end
Strip.ACTIONS.played = function(_, mouse)
	if mouse ~= "RightButton" then Call(RequestTimePlayed) end
end
Strip.ACTIONS.audio = function(_, mouse)
	local api, on = C_CVar, CVar("Sound_EnableAllSound")
	if mouse == "RightButton" or InCombatLockdown() or not api or type(api.SetCVar) ~= "function" or on ~= "0" and on ~= "1" then return end
	Call(api.SetCVar, "Sound_EnableAllSound", on == "0" and "1" or "0")
end
Strip.ACTIONS.broker = function(item, mouse)
	local object = Broker()
	if object and type(object.OnClick) == "function" and not InCombatLockdown() then K.Call(object.OnClick, item.button, mouse) end
end

local EVENTS = {
	xp = { "PLAYER_XP_UPDATE", "UPDATE_FACTION", "PLAYER_LEVEL_UP" },
	bags = { "BAG_UPDATE_DELAYED" },
	time = { "CALENDAR_UPDATE_PENDING_INVITES" },
	mail = { "UPDATE_PENDING_MAIL" },
	rest = { "PLAYER_UPDATE_RESTING" },
	guild = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" },
	friends = { "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_CONNECTED", "BN_DISCONNECTED" },
	hearth = { "HEARTHSTONE_BOUND" },
	spec = { "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED" },
	loadout = { "TRAIT_CONFIG_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED" },
	currencies = { "CURRENCY_DISPLAY_UPDATE" },
	gold = { "PLAYER_MONEY" },
	durability = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" },
	location = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" },
	itemLevel = { "PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE" },
	combat = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" },
	played = { "TIME_PLAYED_MSG", "PLAYER_LEVEL_UP" },
	audio = { "CVAR_UPDATE" },
	prof = { "SKILL_LINES_CHANGED" },
	reagents = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" },
}
local READOUT = { mail = "time", rest = "time", loadout = "spec" }
local REFRESH = { PLAYER_GUILD_UPDATE = true, PLAYER_SPECIALIZATION_CHANGED = true, ACTIVE_TALENT_GROUP_CHANGED = true, SKILL_LINES_CHANGED = true }
local active = {}
local function Changed(id, event, ...)
	if id == "combat" then
		local now = Number(GetTime) or 0
		if event == "PLAYER_REGEN_DISABLED" then
			fight.start = now
		elseif fight.start then
			fight.last, fight.start = math.max(0, now - fight.start), nil
		end
		if Settings().combatOnly then Strip.Reorder() else Strip.Update(id) end
	elseif event == "TIME_PLAYED_MSG" then
		local total, level = ...
		if IsNumber(total) and IsNumber(level) then played = { total = total, level = level, at = Number(GetTime) or 0 } end
		Strip.Update(id)
	elseif id == "played" then
		local now = Number(GetTime)
		if played and now then played.total, played.level, played.at = played.total + now - played.at, 0, now end
		Strip.Update(id)
	elseif id == "reagents" then
		supplies = nil
		Strip.Update(id)
	elseif event == "CVAR_UPDATE" then
		local name = Plain((...), "string")
		if name and name:lower():find("^sound_") then Strip.Update(id) end
	elseif REFRESH[event] then
		Strip.Refresh()
	elseif event == "CURRENCY_DISPLAY_UPDATE" then
		local item = Strip.view and Strip.view.items.currencies
		if Readouts.Visible("currencies") ~= (item and (item.overflow or item.button:IsShown()) or false) then Strip.Refresh() else Strip.Update(id) end
	else
		if event == "PLAYER_MONEY" then Readouts.SaveGold() end
		if event == "HEARTHSTONE_BOUND" then Readouts.SaveHearth() end
		Strip.Update(id)
	end
end

function Readouts.Sync(shown)
	local wanted, s = {}, ns.Settings().strip
	if shown then
		for _, entry in ipairs(Strip.Modules(s)) do
			if entry.shown then wanted[entry.id] = true end
		end
		wanted.mail, wanted.rest, wanted.loadout = wanted.time and s.clockMail, wanted.time and s.clockRest, wanted.spec and s.specLoadout
		wanted.prof = wanted.prof1 or wanted.prof2
	end
	for id, events in pairs(EVENTS) do
		local on = wanted[id] == true
		if on ~= (active[id] == true) then
			local owner = "DataBars.Readouts." .. id
			active[id] = on
			if on then
				local readout = READOUT[id] or id
				local function Handle(...) Changed(readout, ...) end
				for _, event in ipairs(events) do K.Events.Register(owner, event, Handle) end
				if id == "hearth" then Readouts.SaveHearth() end
				if id == "reagents" then supplies = nil end
			else
				K.Events.UnregisterAll(owner)
			end
		end
	end
end

ns.AddPart({ Disable = function() Readouts.Sync(false) end })
