-- TravelData.lua: the reusable, secret-safe travel inventory; no frames or events until a consumer asks for it.
local _, ns = ...

local Travel = {}
ns.TravelData = Travel

local CLASS = { 18960, 556, 698, 437169 }
local PORTALS = { 3561, 3562, 3563, 3565, 3566, 3567, 1297659, 10059, 11416, 11417, 11418, 11419, 11420 }
local MOUNTS = { 13819, 23214, 5784, 23161 }

function Travel.Plain(value, kind)
	if (type(issecretvalue) == "function" and issecretvalue(value)) or type(value) ~= kind then return nil end
	return value
end

local Plain = Travel.Plain

local function Spell(list, id)
	local book, api = C_SpellBook, C_Spell
	if not (book and type(book.IsSpellKnown) == "function" and api and type(api.GetSpellInfo) == "function") then return end
	if Plain(book.IsSpellKnown(id), "boolean") ~= true then return end
	local info = Plain(api.GetSpellInfo(id), "table")
	if not info then return end
	list[#list + 1] = { kind = "spell", id = id, name = Plain(info.name, "string"), icon = Plain(info.iconID, "number") }
end

function Travel.Read()
	local groups = { {}, {}, {} }
	local carried, seenMounts = {}, {}
	local bagAPI, itemAPI = C_Container, C_Item
	if bagAPI and type(bagAPI.GetContainerNumSlots) == "function" and type(bagAPI.GetContainerItemInfo) == "function" then
		local inventory = Constants and Constants.InventoryConstants
		local bags = (Plain(inventory and inventory.NumBagSlots, "number") or 4) + (Plain(inventory and inventory.NumReagentBagSlots, "number") or 0)
		for bag = 0, bags do
			for slot = 1, Plain(bagAPI.GetContainerNumSlots(bag), "number") or 0 do
				local info = Plain(bagAPI.GetContainerItemInfo(bag, slot), "table")
				local id = info and Plain(info.itemID, "number")
				if id and not carried[id] then
					carried[id] = { kind = "item", id = id, name = Plain(info.itemName, "string"), icon = Plain(info.iconFileID, "number") }
					if itemAPI and type(itemAPI.GetItemInfoInstant) == "function" then
						local _, _, _, _, _, class, subclass = itemAPI.GetItemInfoInstant(id)
						if Plain(class, "number") == 15 and Plain(subclass, "number") == 5 then
							if type(itemAPI.IsUsableItem) == "function" and Plain(itemAPI.IsUsableItem(id), "boolean") == true then
								groups[3][#groups[3] + 1] = carried[id]
							end
						end
					end
				end
			end
		end
	end
	if carried[6948] then groups[1][1] = carried[6948] end
	for _, id in ipairs(CLASS) do Spell(groups[1], id) end
	for _, id in ipairs(PORTALS) do Spell(groups[2], id) end
	for _, id in ipairs(ns.TRAVEL_ITEMS) do
		local entry = carried[id]
		if not entry and itemAPI and type(itemAPI.IsEquippedItem) == "function" and Plain(itemAPI.IsEquippedItem(id), "boolean") == true then
			local name = type(itemAPI.GetItemNameByID) == "function" and Plain(itemAPI.GetItemNameByID(id), "string")
			local icon = type(itemAPI.GetItemIconByID) == "function" and Plain(itemAPI.GetItemIconByID(id), "number")
			entry = { kind = "item", id = id, name = name or nil, icon = icon or nil }
		end
		if entry then groups[2][#groups[2] + 1] = entry end
	end
	for _, id in ipairs(MOUNTS) do
		if C_Spell and type(C_Spell.IsSpellUsable) == "function" and Plain(C_Spell.IsSpellUsable(id), "boolean") == true then Spell(groups[3], id) end
		seenMounts[id] = true
	end
	local journal = C_MountJournal
	if journal and type(journal.GetMountIDs) == "function" and type(journal.GetMountInfoByID) == "function" then
		for _, mount in ipairs(Plain(journal.GetMountIDs(), "table") or {}) do
			if Plain(mount, "number") then
				local name, spell, icon, _, usable, _, _, _, _, hidden, collected = journal.GetMountInfoByID(mount)
				spell = Plain(spell, "number")
				if spell and not seenMounts[spell] and Plain(usable, "boolean") == true and Plain(collected, "boolean") == true and Plain(hidden, "boolean") == false then
					groups[3][#groups[3] + 1] = { kind = "spell", id = spell, name = Plain(name, "string"), icon = Plain(icon, "number") }
					seenMounts[spell] = true
				end
			end
		end
	end
	return groups, carried[6948] ~= nil
end

function Travel.Hearth()
	local bind = type(GetBindLocation) == "function" and Plain(GetBindLocation(), "string") or "--"
	local cooldown = "--"
	if C_Item and type(C_Item.GetItemCooldown) == "function" then
		local start, duration = C_Item.GetItemCooldown(6948)
		start, duration = Plain(start, "number"), Plain(duration, "number")
		local now = type(GetTime) == "function" and Plain(GetTime(), "number")
		if start and duration and now then cooldown = tostring(math.ceil(math.max(0, start + duration - now))) .. "s" end
	end
	return bind, cooldown
end
