-- Data.lua: the bag model: which bags exist, what each slot holds, junk, item levels, search matches and grid maths.
local _, ns = ...

local Data = {}
ns.Data = Data

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local lower, find, match = string.lower, string.find, string.match

local FALLBACK_BAG_SLOTS = 4
local FALLBACK_REAGENT_SLOTS = 1
local KEYRING_FALLBACK = -1
local QUALITY_POOR = 0
local CLASS_WEAPON, CLASS_ARMOR = 2, 4
local GROWTH = {
	RIGHT_DOWN = { false, false },
	LEFT_DOWN = { true, false },
	RIGHT_UP = { false, true },
	LEFT_UP = { true, true },
}
Data.GROWTH = GROWTH

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end
Data.IsSecret = IsSecret

local function Plain(value, kind)
	if IsSecret(value) or type(value) ~= kind then
		return nil
	end
	if kind == "number" and value ~= value then
		return nil
	end
	return value
end
Data.Plain = Plain

function Data.Grid(count, columns)
	count = max(0, floor(Plain(count, "number") or 0))
	if count == 0 then
		return 0, 0
	end
	local cols = min(count, max(1, floor(Plain(columns, "number") or 1)))
	return cols, ceil(count / cols)
end

function Data.Size(cols, rows, size, spacing)
	if cols <= 0 or rows <= 0 then
		return 0, 0
	end
	return cols * size + (cols - 1) * spacing, rows * size + (rows - 1) * spacing
end

function Data.Cell(index, cols, rows, size, spacing, growth)
	local flip = GROWTH[growth]
	if not flip then
		error("KstyleUI_Bags Data.Cell: unknown growth " .. tostring(growth), 2)
	end
	local i = index - 1
	local col, row = i % cols, floor(i / cols)
	if flip[1] then
		col = cols - 1 - col
	end
	if flip[2] then
		row = rows - 1 - row
	end
	local step = size + spacing
	return col * step, -row * step
end

local function InventoryCount(field, fallback)
	local inventory = Constants and Constants.InventoryConstants
	return Plain(inventory and inventory[field], "number") or fallback
end

function Data.HeldBags()
	local first = Plain(BACKPACK_CONTAINER, "number") or 0
	local count = InventoryCount("NumBagSlots", FALLBACK_BAG_SLOTS) + InventoryCount("NumReagentBagSlots", FALLBACK_REAGENT_SLOTS)
	local bags = {}
	for bag = first, first + count do
		bags[#bags + 1] = bag
	end
	return bags
end

function Data.KeyringBag()
	local bar = C_ActionBar
	if bar and type(bar.ShouldShowKeyring) == "function" then
		local ok, shown = pcall(bar.ShouldShowKeyring)
		if not ok or IsSecret(shown) or not shown then
			return nil
		end
	end
	local index = Enum and Enum.BagIndex
	return Plain(KEYRING_CONTAINER, "number") or Plain(index and index.Keyring, "number") or KEYRING_FALLBACK
end

function Data.IsKeyring(bag)
	return bag ~= nil and bag == Data.KeyringBag()
end

function Data.NumSlots(bag)
	local size
	if bag == Data.KeyringBag() and type(GetKeyRingSize) == "function" then
		local ok, value = pcall(GetKeyRingSize)
		size = ok and Plain(value, "number") or nil
	end
	if size == nil and C_Container and C_Container.GetContainerNumSlots then
		size = Plain(C_Container.GetContainerNumSlots(bag), "number")
	end
	return max(0, floor(size or 0))
end

local function Clear(record)
	record.empty = true
	record.itemID, record.icon, record.count, record.quality, record.link, record.name = nil, nil, nil, nil, nil, nil
	record.locked, record.isNew, record.junk, record.noValue, record.bound = false, false, false, false, false
end

function Data.IsJunk(record)
	local quality = Plain(record.quality, "number")
	return quality ~= nil and quality == QUALITY_POOR and record.noValue ~= true
end

function Data.Read(bag, slot, record)
	record = record or {}
	record.bag, record.slot = bag, slot
	Clear(record)
	local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
	if IsSecret(info) or type(info) ~= "table" then
		return record
	end
	record.empty = false
	record.itemID = Plain(info.itemID, "number")
	record.icon = Plain(info.iconFileID, "number") or Plain(info.iconFileID, "string")
	record.count = Plain(info.stackCount, "number")
	record.quality = Plain(info.quality, "number")
	record.link = Plain(info.hyperlink, "string")
	record.name = Plain(info.itemName, "string")
	record.locked = Plain(info.isLocked, "boolean") == true
	record.noValue = Plain(info.hasNoValue, "boolean") == true
	record.bound = Plain(info.isBound, "boolean") == true
	local newItems = C_NewItems
	if newItems and newItems.IsNewItem then
		record.isNew = Plain(newItems.IsNewItem(bag, slot), "boolean") == true
	end
	record.junk = Data.IsJunk(record)
	return record
end

local levels = {}

local function ItemClass(record)
	local item = C_Item
	if not item or type(item.GetItemInfoInstant) ~= "function" or not record.itemID then
		return nil
	end
	local _, _, _, _, _, classID = item.GetItemInfoInstant(record.itemID)
	return Plain(classID, "number")
end

local function LevelFromLocation(record)
	local item, location = C_Item, ItemLocation
	if not item or type(item.GetCurrentItemLevel) ~= "function" or not location or type(location.CreateFromBagAndSlot) ~= "function" then
		return nil
	end
	local ok, level = pcall(item.GetCurrentItemLevel, location:CreateFromBagAndSlot(record.bag, record.slot))
	return ok and Plain(level, "number") or nil
end

function Data.ItemLevel(record)
	if record.empty or not record.link then
		return nil
	end
	local class = ItemClass(record)
	local weapon, armor = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or CLASS_WEAPON, (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or CLASS_ARMOR
	if class ~= weapon and class ~= armor then
		return nil
	end
	local cached = levels[record.link]
	if cached then
		return cached
	end
	local level
	local item = C_Item
	if item and type(item.GetDetailedItemLevelInfo) == "function" then
		local ok, value = pcall(item.GetDetailedItemLevelInfo, record.link)
		level = ok and Plain(value, "number") or nil
	end
	level = level or LevelFromLocation(record)
	if level and level > 0 then
		levels[record.link] = level
		return level
	end
	return nil
end

function Data.Query(text)
	text = Plain(text, "string")
	if not text then
		return nil
	end
	text = match(text, "^%s*(.-)%s*$")
	if text == "" then
		return nil
	end
	return lower(text)
end

local function Contains(text, query)
	text = Plain(text, "string")
	return text ~= nil and find(lower(text), query, 1, true) ~= nil
end

function Data.Matches(record, query)
	if not query then
		return true
	end
	if record.empty then
		return false
	end
	if Contains(record.name, query) then
		return true
	end
	local item = C_Item
	if item and type(item.GetItemInfoInstant) == "function" and record.itemID then
		local _, itemType, subType = item.GetItemInfoInstant(record.itemID)
		if Contains(itemType, query) or Contains(subType, query) then
			return true
		end
	end
	if not record.name and item and type(item.GetItemInfo) == "function" and record.link then
		return Contains((item.GetItemInfo(record.link)), query)
	end
	return false
end

function Data.FreeSlots(bags)
	local free, total = 0, 0
	local probe = {}
	for _, bag in ipairs(bags) do
		local size = Data.NumSlots(bag)
		total = total + size
		for slot = 1, size do
			if Data.Read(bag, slot, probe).empty then
				free = free + 1
			end
		end
	end
	return free, total
end
