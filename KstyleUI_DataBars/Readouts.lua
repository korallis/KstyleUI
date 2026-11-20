-- Readouts.lua: the data bar's guarded travel, social and account readouts in the strip's shared registries.
local _, ns = ...

local K, L, Strip = ns.K, ns.L, ns.Strip
local Call, IsNumber = ns.Sources.Call, ns.IsNumber
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

local function Spec()
	local api = C_SpecializationInfo
	local index = api and Number(api.GetSpecialization)
	if index then
		local _, name = Call(api.GetSpecializationInfo, index)
		return Plain(name, "string") or L["--"]
	end
	return L["--"]
end

function Readouts.CanSwitch()
	local api = C_SpecializationInfo
	local groups = Number(GetNumSpecGroups)
	local group = api and Number(api.GetActiveSpecGroup)
	return api and type(api.SetActiveSpecGroup) == "function" and groups and groups > 1 and group and (group == 1 or group == 2), group
end

local function Hearth()
	local travel = K.Safe.Side(K).travelData
	if travel then return travel.Hearth() end
	return L["--"], L["--"]
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
	local bags = inventory and Plain(inventory.NumBagSlots, "number") or 4
	local reagent = inventory and Plain(inventory.NumReagentBagSlots, "number") or 0
	for bag = 0, bags + reagent do
		local free = Number(api.GetContainerNumFreeSlots, bag)
		if not free then return end
		total = total + free
	end
	return total
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

local function Currencies(tip)
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
			parts[#parts + 1] = value .. " " .. name
			if tip then tip:AddDoubleLine(name, value) end
		end
	end
	return table.concat(parts, " \194\183 ")
end

function Readouts.SaveGold()
	local account = K.Store.Account()
	if type(account.databarGold) ~= "table" then account.databarGold = {} end
	local money, key = Number(GetMoney), K.Store.CharacterKey()
	if money and key then account.databarGold[key] = money end
end

local function XP()
	local info = ns.Sources.XP() or ns.Sources.Reputation()
	if info and IsNumber(info.current) and IsNumber(info.max) and info.max > 0 then
		return tostring(math.floor(info.current / info.max * 100)) .. "%"
	end
	return L["--"]
end

local titles = {
	xp = L["Experience and reputation"],
	bags = L["Bag space"], spec = L["Specialization"], hearth = L["Hearthstone"],
	guild = L["Guild"], friends = L["Friends"], currencies = L["Currencies"],
}
for id, title in pairs(titles) do
	Strip.LABELS[id] = { full = title, short = title, inline = id == "bags" and L["free"] or id == "guild" and L["guild"] or id == "friends" and L["friends"] or "" }
	Strip.TITLES[id] = title
end
Strip.TIMED.hearth = true
Strip.VALUES.xp = XP
Strip.TOOLTIPS.xp = function(_, tip) tip:AddDoubleLine(L["Experience and reputation"], XP()) end
Strip.VALUES.bags = function() return Count(Bags()) end
Strip.VALUES.spec = Spec
Strip.VALUES.hearth = function()
	local bind, cooldown = Hearth()
	return cooldown .. " " .. bind
end
Strip.VALUES.guild = Guild
Strip.VALUES.friends = Friends
Strip.VALUES.currencies = function() return Currencies() end

function Readouts.Visible(id)
	if id == "guild" then return Plain(Call(IsInGuild), "boolean") == true end
	if id == "spec" then local groups = Number(GetNumSpecGroups); return groups and groups > 1 end
	if id == "currencies" then return C_CurrencyInfo and type(C_CurrencyInfo.GetBackpackCurrencyInfo) == "function" and Currencies() ~= "" end
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
	ProtectedNote(tip, L["Click: use your Hearthstone."])
end
Strip.TOOLTIPS.guild = function(_, tip)
	Readouts.RequestRoster()
	tip:AddDoubleLine(L["Online"], Guild())
end
Strip.TOOLTIPS.friends = function(_, tip)
	local _, wow, battle = Friends()
	tip:AddDoubleLine(L["World of Warcraft"], Count(wow))
	tip:AddDoubleLine(L["Battle.net"], Count(battle))
end
Strip.TOOLTIPS.currencies = function(_, tip)
	local text = Currencies(tip)
	if text == "" or text == L["--"] then tip:AddLine(L["--"], "textDisabled") end
end
Strip.TOOLTIP_EXTRA.time = function(_, tip)
	tip:AddDoubleLine(L["Pending invites"], Count(C_Calendar and Number(C_Calendar.GetNumPendingInvites)))
end
Strip.TOOLTIP_EXTRA.gold = function(_, tip)
	Readouts.SaveGold()
	local keys, gold = {}, K.Store.Account().databarGold
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

Strip.ACTIONS.spec = function(_, mouse)
	if mouse == "RightButton" or InCombatLockdown() then return end
	local can, group = Readouts.CanSwitch()
	if can then C_SpecializationInfo.SetActiveSpecGroup(3 - group) end
end

local EVENTS = {
	xp = { "PLAYER_XP_UPDATE", "UPDATE_FACTION" },
	bags = { "BAG_UPDATE_DELAYED" },
	time = { "CALENDAR_UPDATE_PENDING_INVITES" },
	guild = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" },
	friends = { "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_CONNECTED", "BN_DISCONNECTED" },
	hearth = { "HEARTHSTONE_BOUND" },
	spec = { "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED" },
	currencies = { "CURRENCY_DISPLAY_UPDATE" },
	gold = { "PLAYER_MONEY" },
	durability = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" },
}
local active = {}
local function Changed(event)
	if event == "PLAYER_GUILD_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
		Strip.Refresh()
	elseif event == "CURRENCY_DISPLAY_UPDATE" then
		local item = Strip.view and Strip.view.items.currencies
		if Readouts.Visible("currencies") ~= (item and (item.overflow or item.button:IsShown()) or false) then Strip.Refresh() else Strip.Update() end
	else
		if event == "PLAYER_MONEY" then Readouts.SaveGold() end
		Strip.Update()
	end
end

function Readouts.Sync(shown)
	local wanted = {}
	if shown then
		for _, entry in ipairs(Strip.Modules(ns.Settings().strip)) do
			if entry.shown then wanted[entry.id] = true end
		end
	end
	for id, events in pairs(EVENTS) do
		local on = wanted[id] == true
		if on ~= (active[id] == true) then
			local owner = "DataBars.Readouts." .. id
			active[id] = on
			if on then
				for _, event in ipairs(events) do K.Events.Register(owner, event, Changed) end
			else
				K.Events.UnregisterAll(owner)
			end
		end
	end
end

ns.AddPart({ Disable = function() Readouts.Sync(false) end })
