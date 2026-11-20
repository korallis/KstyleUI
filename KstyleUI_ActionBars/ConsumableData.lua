-- ConsumableData.lua: curated Forever consumable ranks, highest first, and secret-safe bag selection.
local _, ns = ...

local C = { kinds = {
	{ key = "healing", label = KstyleUI.L["Healing potion"], ids = { 13446, 223913, 3928, 288896, 1710, 223914, 287977, 929, 858, 287967, 118, 287966 } },
	{ key = "mana", label = KstyleUI.L["Mana potion"], ids = { 13444, 13443, 288897, 6149, 3827, 3385, 287969, 2455, 287968 } },
	{ key = "healthstone", label = KstyleUI.L["Healthstone"], ids = { 5510, 5509, 5511, 5512 } },
	{ key = "bandage", label = KstyleUI.L["Bandage"], ids = { 232433, 14530, 19066, 20066, 19307, 14529, 8545, 19067, 20065, 20232, 20237, 272057, 8544, 6451, 19068, 20067, 20235, 6450, 3531, 3530, 2581, 1251 } },
	{ key = "food", label = KstyleUI.L["Food"], ids = { 22895, 8076, 8950, 8952, 287963, 8953, 8957, 8932, 8075, 4601, 3927, 4608, 1487, 4544, 1707, 4607, 1114, 4542, 422, 4606, 1113, 4541, 414, 4605, 5349, 4540, 117, 4536, 4604, 787 } },
	{ key = "drink", label = KstyleUI.L["Drink"], ids = { 8079, 18300, 8078, 8077, 1645, 3772, 1708, 2136, 1205, 2288, 1179, 5350, 159 } },
	{ key = "rejuvenation", label = KstyleUI.L["Rejuvenation potion"], ids = { 18253, 2456 } },
	{ key = "buffFood", label = KstyleUI.L["Buff food"], ids = { 20452, 13934, 18254, 13931, 13928, 287974, 13810, 13813, 12218, 12217, 12215, 12216, 12213, 12214, 18045, 3665, 3726, 3220, 3662, 6888 } },
	{ key = "flask", label = KstyleUI.L["Flask"], ids = { 274274, 274275, 274276, 274273, 13512, 13511, 13510, 13513, 13506 } },
	{ key = "battle", label = KstyleUI.L["Battle elixir"], ids = { 13452, 13454, 9206, 9187, 8949, 3391, 3390, 6373, 2457, 2454 } },
	{ key = "guardian", label = KstyleUI.L["Guardian elixir"], ids = { 20007, 20004, 13445, 13447, 9088, 8951, 3826, 3389, 3388, 3383, 2458, 5997 } },
	{ key = "scroll", label = KstyleUI.L["Scroll"], ids = { 4422, 4421, 2289, 1477, 1711, 1712, 1478, 954, 3012, 1180, 955, 1181, 3013 } },
} }
ns.Consumables = C
C.def = { key = "consumables", kind = "consumable", element = "consumables.bar", max = 12 }

local function Plain(value, kind)
	if ns.IsSecret(value) or type(value) ~= kind then return nil end
	if kind == "number" and (value ~= value or value == math.huge or value == -math.huge) then return nil end
	return value
end
C.Plain = Plain

C.travel = { 6948, 282006, 260830, 191288, 18986, 260823, 260819, 260821, 18149, 18150, 282416, 282418, 278162, 224912, 224806, 224893 }
local travel, travelSpells = {}, { [556] = true, [3561] = true, [3562] = true, [3563] = true, [3565] = true, [3566] = true, [3567] = true, [18960] = true, [1297659] = true }
for _, id in ipairs(C.travel) do travel[id] = true end
local ranks, travelUses

function C.TravelChanged(event, id)
	if event == "SPELLS_CHANGED" then travelUses = nil
	elseif travelUses then travelUses[id] = nil end
	C.Refresh()
end

local function Classify(id, cfg)
	if travel[id] then return end
	if not ranks then
		ranks = {}
		for _, kind in ipairs(C.kinds) do
			for rank, item in ipairs(kind.ids) do ranks[item] = { key = kind.key, rank = rank } end
		end
	end
	local known = ranks[id]
	if known then return cfg[known.key] ~= false and known.key or nil, known.rank end
	local item = C_Item
	if cfg.other == false or not (item and item.GetItemInfoInstant and item.GetItemSpell and item.GetItemInfo) then return end
	local _, _, _, _, _, class = item.GetItemInfoInstant(id)
	if Plain(class, "number") ~= 0 then return end
	local _, spell = item.GetItemSpell(id)
	spell = Plain(spell, "number")
	if not spell then return end
	travelUses = travelUses or {}
	for _, travelID in ipairs(C.travel) do
		if travelUses[travelID] == nil then
			local _, use = item.GetItemSpell(travelID)
			travelUses[travelID] = Plain(use, "number") or false
		end
		if travelUses[travelID] == spell then return end
	end
	if travelSpells[spell] then return end
	local _, _, _, level, required, _, _, stack = item.GetItemInfo(id)
	stack = Plain(stack, "number")
	if not stack or stack <= 1 then return end
	return "other:" .. spell, -(Plain(required, "number") or Plain(level, "number") or 0)
end

function C.Scan(cfg)
	local counts, candidates, picked = {}, {}, {}
	local api = C_Container
	if not (api and api.GetContainerNumSlots and api.GetContainerItemInfo) then return picked, counts end
	local inventory = Constants and Constants.InventoryConstants or {}
	local bags = (Plain(inventory.NumBagSlots, "number") or 4) + (Plain(inventory.NumReagentBagSlots, "number") or 1)
	for bag = 0, bags do
		local slots = Plain(api.GetContainerNumSlots(bag), "number") or 0
		for slot = 1, slots do
			local info = api.GetContainerItemInfo(bag, slot)
			if not ns.IsSecret(info) and type(info) == "table" then
				local id, count = Plain(info.itemID, "number"), Plain(info.stackCount, "number")
				if id and count and count > 0 then
					counts[id] = (counts[id] or 0) + count
					local key, rank = Classify(id, cfg)
					local old = key and candidates[key]
					if key and (not old or rank < old.rank or rank == old.rank and id < old.id) then
						candidates[key] = { id = id, rank = rank, key = key, icon = Plain(info.iconFileID, "number") or Plain(info.iconFileID, "string") }
					end
				end
			end
		end
	end
	for _, kind in ipairs(C.kinds) do
		if candidates[kind.key] then picked[#picked + 1] = candidates[kind.key] end
	end
	local others = {}
	for key, item in pairs(candidates) do if key:match("^other:") then others[#others + 1] = item end end
	table.sort(others, function(a, b) return a.rank < b.rank or a.rank == b.rank and a.id < b.id end)
	for _, item in ipairs(others) do if #picked < 12 then picked[#picked + 1] = item end end
	for i = #picked, (cfg.buttons or 12) + 1, -1 do picked[i] = nil end
	return picked, counts
end
