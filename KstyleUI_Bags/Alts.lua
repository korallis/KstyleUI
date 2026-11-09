-- Alts.lua: each character's items, scanned from the bags and the bank into KstyleUI's own account data: the counts other characters' tooltips show, and the catalogue the bag window browses read-only.
local _, ns = ...

local K = KstyleUI
local Data, Settings, L = ns.Data, ns.Settings, ns.L
local Theme, Tokens = K.Theme, K.Tokens
local format, sort, max = string.format, table.sort, math.max

local Alts = {}
ns.Alts = Alts

Alts.SECTION = "inventory"
Alts.VERSION = 2
Alts.FORGET_AFTER = 60 * 24 * 60 * 60
Alts.MAX_LINES = 8
local SCAN_DELAY = 0.5

local store
local me
local myKey
local scanQueued = false
local registered = false

local function Plain(value, kind)
	return Data.Plain(value, kind)
end

local function Now()
	return type(time) == "function" and Plain(time(), "number") or 0
end

local function Table()
	local account = K.Store.Account()
	local saved = account[Alts.SECTION]
	if type(saved) ~= "table" then
		saved = {}
		account[Alts.SECTION] = saved
	end
	saved.version = Alts.VERSION
	if type(saved.characters) ~= "table" then
		saved.characters = {}
	end
	if type(saved.warband) ~= "table" then
		saved.warband = {}
	end
	return saved
end

local function Prune(saved)
	local now = Now()
	for key, character in pairs(saved.characters) do
		local seen = type(character) == "table" and Plain(character.seen, "number") or nil
		if type(key) ~= "string" or not seen or (now > 0 and now - seen > Alts.FORGET_AFTER) then
			saved.characters[key] = nil
		end
	end
end

local function Me(saved)
	local key = K.Store.CharacterKey()
	if not key then
		return nil
	end
	local character = saved.characters[key]
	if type(character) ~= "table" then
		character = {}
		saved.characters[key] = character
	end
	local name = type(UnitName) == "function" and Plain(UnitName("player"), "string") or nil
	local realm = type(GetRealmName) == "function" and Plain(GetRealmName(), "string") or nil
	local _, class = nil, nil
	if type(UnitClass) == "function" then
		_, class = UnitClass("player")
	end
	character.name = name or character.name or key
	character.realm = realm or character.realm
	character.class = Plain(class, "string") or character.class
	character.seen = Now()
	if type(character.bags) ~= "table" then
		character.bags = {}
	end
	if type(character.bank) ~= "table" then
		character.bank = {}
	end
	if type(character.items) ~= "table" then
		character.items = {}
	end
	myKey = key
	return character
end

local function Describe(items, id, record)
	if type(items) ~= "table" then
		return
	end
	local entry = items[id]
	if type(entry) ~= "table" then
		entry = {}
		items[id] = entry
	end
	entry.icon = Plain(record.icon, "number") or entry.icon
	entry.quality = Plain(record.quality, "number") or entry.quality
	entry.name = Plain(record.name, "string") or entry.name
	entry.cat = Plain(Data.Category(record), "string") or entry.cat
end

local function Count(bags, into, items)
	for key in pairs(into) do
		into[key] = nil
	end
	local probe = {}
	local free, total = 0, 0
	for _, bag in ipairs(bags) do
		for slot = 1, Data.NumSlots(bag) do
			total = total + 1
			local record = Data.Read(bag, slot, probe)
			local id, count = record.itemID, record.count
			if record.empty then
				free = free + 1
			elseif id and count then
				into[id] = (into[id] or 0) + max(1, count)
				Describe(items, id, record)
			end
		end
	end
	return free, total
end

local function Forget(character)
	local items = character.items
	if type(items) ~= "table" then
		return
	end
	for id in pairs(items) do
		if not character.bags[id] and not character.bank[id] then
			items[id] = nil
		end
	end
end

function Alts.ScanBags()
	if not me then
		return
	end
	me.free, me.total = Count(Data.HeldBags(), me.bags, me.items)
	me.money = type(GetMoney) == "function" and Plain(GetMoney(), "number") or me.money
	Forget(me)
	me.seen = Now()
end

function Alts.ScanBank()
	local bank = ns.Bank
	if not me or not bank or type(bank.Tabs) ~= "function" then
		return
	end
	local character, account = bank.Types()
	if bank.CanView(character) then
		me.bankFree, me.bankTotal = Count(bank.Tabs(character), me.bank, me.items)
	end
	if bank.CanView(account) then
		Count(bank.Tabs(account), store.warband)
	end
	Forget(me)
	me.seen = Now()
end

local function ScanSoon()
	if scanQueued or not me then
		return
	end
	scanQueued = true
	C_Timer.After(SCAN_DELAY, function()
		scanQueued = false
		if me then
			Alts.ScanBags()
		end
	end)
end

local function BankChanged()
	if me and ns.Bank and ns.Bank.IsAtBank() then
		Alts.ScanBank()
	end
end

local function ItemID(data)
	local id = data.id
	if Data.IsSecret(id) then
		return nil
	end
	if type(id) ~= "number" then
		local link = data.hyperlink
		local item = C_Item
		if not Data.IsSecret(link) and type(link) == "string" and item and type(item.GetItemInfoInstant) == "function" then
			id = Plain((item.GetItemInfoInstant(link)), "number")
		end
	end
	return Plain(id, "number")
end

local function Counts(character, id, own)
	local bags = not own and Plain(character.bags and character.bags[id], "number") or 0
	local bank = Plain(character.bank and character.bank[id], "number") or 0
	if bags <= 0 and bank <= 0 then
		return nil
	end
	local parts = {}
	if bags > 0 then
		parts[#parts + 1] = format(L["%d in bags"], bags)
	end
	if bank > 0 then
		parts[#parts + 1] = format(L["%d in bank"], bank)
	end
	return table.concat(parts, ", "), bags + bank
end

function Alts.Characters()
	local list = {}
	if not store then
		return list
	end
	for key, character in pairs(store.characters) do
		if type(character) == "table" then
			list[#list + 1] = { key = key, name = character.name or key, realm = character.realm, class = character.class, own = key == myKey }
		end
	end
	sort(list, function(a, b)
		if a.own ~= b.own then
			return a.own
		end
		return tostring(a.name) < tostring(b.name)
	end)
	return list
end

local function Entries(counts, items, rank)
	local list = {}
	for id, count in pairs(counts) do
		local entry = type(items) == "table" and items[id] or nil
		if type(entry) == "table" and Plain(count, "number") then
			list[#list + 1] = { id = id, count = count, icon = entry.icon, quality = entry.quality, name = entry.name, cat = entry.cat, rank = rank[entry.cat] or rank.other or 0 }
		end
	end
	sort(list, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		if tostring(a.name) ~= tostring(b.name) then
			return tostring(a.name) < tostring(b.name)
		end
		return a.id < b.id
	end)
	return list
end

function Alts.View(key)
	local character = store and type(key) == "string" and store.characters[key] or nil
	if type(character) ~= "table" then
		return nil
	end
	local rank = {}
	for index, category in ipairs(Data.Categories()) do
		rank[category.key] = index
	end
	return {
		key = key, name = character.name or key, class = character.class, own = key == myKey,
		bags = Entries(character.bags or {}, character.items, rank),
		bank = Entries(character.bank or {}, character.items, rank),
		free = Plain(character.free, "number"), total = Plain(character.total, "number"),
		bankFree = Plain(character.bankFree, "number"), bankTotal = Plain(character.bankTotal, "number"),
		money = Plain(character.money, "number"),
	}
end

function Alts.Lines(id)
	local saved = store
	if not saved or not id then
		return {}
	end
	local lines = {}
	for key, character in pairs(saved.characters) do
		if type(character) == "table" then
			local text, total = Counts(character, id, key == myKey)
			if text then
				lines[#lines + 1] = { key = key, name = character.name or key, class = character.class, text = text, total = total, own = key == myKey }
			end
		end
	end
	sort(lines, function(a, b)
		if a.own ~= b.own then
			return a.own
		end
		return tostring(a.name) < tostring(b.name)
	end)
	local warband = Plain(saved.warband[id], "number")
	if warband and warband > 0 then
		lines[#lines + 1] = { name = L["Warband bank"], text = tostring(warband), total = warband }
	end
	return lines
end

local function OnTooltip(tooltip, data)
	if not store or not Settings.Get("altCounts") or type(data) ~= "table" or type(tooltip) ~= "table" or type(tooltip.AddDoubleLine) ~= "function" then
		return
	end
	local id = ItemID(data)
	if not id then
		return
	end
	local lines = Alts.Lines(id)
	local rr, rg, rb = Tokens.Color("text")
	local shown = 0
	local rest, restTotal = 0, 0
	for _, line in ipairs(lines) do
		if shown < Alts.MAX_LINES then
			shown = shown + 1
			local lr, lg, lb
			if line.class then
				lr, lg, lb = Theme.ClassColor(line.class)
			else
				lr, lg, lb = Tokens.Color("textEmphasis")
			end
			tooltip:AddDoubleLine(line.name, line.text, lr, lg, lb, rr, rg, rb)
		else
			rest, restTotal = rest + 1, restTotal + line.total
		end
	end
	if rest > 0 then
		local mr, mg, mb = Tokens.Color("muted")
		tooltip:AddDoubleLine(format(L["%d more characters"], rest), tostring(restTotal), mr, mg, mb, rr, rg, rb)
	end
end

local function Register()
	if registered then
		return
	end
	local processor = TooltipDataProcessor
	if type(processor) ~= "table" or type(processor.AddTooltipPostCall) ~= "function" then
		ns.Log("TooltipDataProcessor is missing; the other characters' counts are saved but not shown in tooltips")
		return
	end
	local types = Enum and Enum.TooltipDataType
	local kind = type(types) == "table" and types.Item or nil
	if kind == nil then
		kind = processor.AllTypes
	end
	if kind == nil then
		ns.Log("TooltipDataProcessor has no item type; the other characters' counts are not shown in tooltips")
		return
	end
	registered = true
	processor.AddTooltipPostCall(kind, function(tooltip, data)
		K.Call(OnTooltip, tooltip, data)
	end)
end

ns.On("BAG_UPDATE_DELAYED", ScanSoon)
ns.On("BAG_CONTAINER_UPDATE", ScanSoon)
ns.On("BANKFRAME_OPENED", function()
	if me then
		Alts.ScanBank()
	end
end)
ns.On("BANK_TABS_CHANGED", BankChanged)
ns.On("PLAYERBANKSLOTS_CHANGED", BankChanged)
ns.On("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", BankChanged)
ns.On("PLAYER_LOGOUT", function()
	if me then
		Alts.ScanBags()
	end
end)

function Alts.Enable()
	local Store = K.Store
	if not Store or not Store.IsLoaded or not Store.IsLoaded() then
		ns.Log("saved data is not loaded; the other characters' counts stay off")
		return
	end
	store = Table()
	Prune(store)
	me = Me(store)
	if not me then
		ns.Log("the character is not known yet; its counts are saved once it is")
	else
		Alts.ScanBags()
	end
	Register()
end

function Alts.Disable()
	if me then
		Alts.ScanBags()
	end
	me = nil
	store = nil
end
