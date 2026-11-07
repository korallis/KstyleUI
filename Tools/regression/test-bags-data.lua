-- test-bags-data.lua: KstyleUI_Bags reads bags, keyring and items, finds junk and item levels, matches searches and lays out grids.
local B = dofile("Tools/regression/bags_env.lua")
local Item, Q = B.Item, B.QUALITY

local function New(opts)
	opts = opts or {}
	opts.enable = false
	local env, K, ns = B.New(opts)
	assert(type(ns.Data) == "table", "KstyleUI_Bags has no Data table")
	return env, K, ns.Data
end

-- Grids ----------------------------------------------------------------------------------------

do
	local _, _, Data = New()
	local cols, rows = Data.Grid(30, 10)
	assert(cols == 10 and rows == 3, "30 slots in 10 columns make 3 rows")
	cols, rows = Data.Grid(31, 10)
	assert(cols == 10 and rows == 4, "a partly filled row still counts")
	cols, rows = Data.Grid(4, 10)
	assert(cols == 4 and rows == 1, "fewer slots than columns use one row as wide as the slots")
	cols, rows = Data.Grid(0, 10)
	assert(cols == 0 and rows == 0, "no slots, no grid")
	cols = Data.Grid(12, 0)
	assert(cols == 1, "a column count below one is one column")

	local w, h = Data.Size(10, 3, 34, 4)
	assert(w == 10 * 34 + 9 * 4 and h == 3 * 34 + 2 * 4, "the size counts gaps between slots only")
	w, h = Data.Size(0, 0, 34, 4)
	assert(w == 0 and h == 0, "an empty grid has no size")

	local step = 38
	local x, y = Data.Cell(1, 10, 3, 34, 4, "RIGHT_DOWN")
	assert(x == 0 and y == 0, "the first slot sits at the top left when the grid grows right and down")
	x, y = Data.Cell(12, 10, 3, 34, 4, "RIGHT_DOWN")
	assert(x == step and y == -step, "slot 12 is the second slot of the second row")
	x, y = Data.Cell(1, 10, 3, 34, 4, "LEFT_DOWN")
	assert(x == 9 * step and y == 0, "growing left puts the first slot at the top right")
	x, y = Data.Cell(1, 10, 3, 34, 4, "RIGHT_UP")
	assert(x == 0 and y == -2 * step, "growing up puts the first slot on the bottom row")
	x, y = Data.Cell(21, 10, 3, 34, 4, "LEFT_UP")
	assert(x == 9 * step and y == 0, "the third row of a grid growing up and left starts at the top right")
	B.W.Raises(function()
		Data.Cell(1, 10, 3, 34, 4, "SIDEWAYS")
	end, "growth")
end

-- Bags and the keyring ---------------------------------------------------------------------------

do
	local env, _, Data = New({
		bags = {
			[0] = { size = 16, items = {} }, [1] = { size = 10, items = {} }, [2] = { size = 0 }, [5] = { size = 12, items = {} },
			[-1] = { size = 8, items = {} },
		},
	})
	local bags = Data.HeldBags()
	assert(#bags == 6, "the backpack, four bags and the reagent bag: got " .. #bags)
	for i = 1, 6 do
		assert(bags[i] == i - 1, "bags are listed in order, backpack first")
	end
	assert(Data.KeyringBag() == -1, "the keyring is bag -1 when the game shows it")
	assert(Data.NumSlots(0) == 16 and Data.NumSlots(2) == 0 and Data.NumSlots(3) == 0, "slot counts come from the game")
	env.GetKeyRingSize = function()
		return 4
	end
	assert(Data.NumSlots(-1) == 4, "the keyring's size comes from GetKeyRingSize, which trims empty rows")

	env.C_Container.GetContainerNumSlots = function()
		return env.Secret(16)
	end
	assert(Data.NumSlots(0) == 0, "a secret slot count counts as an empty bag")
	env.C_ActionBar.ShouldShowKeyring = function()
		return false
	end
	assert(Data.KeyringBag() == nil, "no keyring when the game hides it")
	env.C_ActionBar = nil
	assert(Data.KeyringBag() == -1, "without C_ActionBar the keyring shows")
	env.Constants = nil
	assert(#Data.HeldBags() == 6, "without the inventory constants the module falls back to five bags and a reagent bag")
end

-- Reading items ----------------------------------------------------------------------------------

do
	local env, _, Data = New({
		bags = { [0] = { size = 4, items = { [1] = Item("potion"), [2] = Item("junk"), [3] = Item("hearth") } } },
	})
	env._new["0:2"] = true
	env._locked["0:1"] = true
	local record = {}
	local got = Data.Read(0, 1, record)
	assert(got == record, "Read fills the table it is given")
	assert(record.bag == 0 and record.slot == 1 and record.empty == false, "a filled slot")
	assert(record.itemID == 118 and record.icon == 134829 and record.count == 5 and record.quality == Q.Common, "the item's info")
	assert(record.locked == true and record.isNew == false, "lock and new flags")
	Data.Read(0, 2, record)
	assert(record.itemID == 2000 and record.isNew == true and record.locked == false, "the table is reused for the next slot")
	assert(record.junk == true, "a poor item with a sell value is junk")
	Data.Read(0, 3, record)
	assert(record.junk == false, "a common item is not junk")
	Data.Read(0, 4, record)
	assert(record.empty == true and record.itemID == nil and record.icon == nil and record.count == nil, "an empty slot clears the old item")
	assert(record.junk == false and record.isNew == false and record.locked == false, "an empty slot has no flags")

	env.C_Container.GetContainerItemInfo = function()
		return { iconFileID = 1, stackCount = env.Secret(3), quality = env.Secret(4), itemID = 9, hyperlink = "x", isLocked = env.Secret(true) }
	end
	Data.Read(0, 1, record)
	assert(record.empty == false and record.count == nil and record.quality == nil and record.locked == false, "secret fields read as unknown")
end

-- Junk -------------------------------------------------------------------------------------------

do
	local _, _, Data = New()
	assert(Data.IsJunk({ quality = Q.Poor, noValue = false }) == true, "poor with a value is junk")
	assert(Data.IsJunk({ quality = Q.Poor, noValue = true }) == false, "poor with no sell value is not junk")
	assert(Data.IsJunk({ quality = Q.Common }) == false, "common is not junk")
	assert(Data.IsJunk({}) == false, "unknown quality is not junk")
end

-- Item levels ------------------------------------------------------------------------------------

do
	local env, _, Data = New({
		bags = { [0] = { size = 3, items = { [1] = Item("sword"), [2] = Item("potion"), [3] = Item("helm") } } },
	})
	local record = Data.Read(0, 1, {})
	assert(Data.ItemLevel(record) == 12, "a weapon shows its item level")
	Data.Read(0, 3, record)
	assert(Data.ItemLevel(record) == 66, "armour shows its item level")
	Data.Read(0, 2, record)
	assert(Data.ItemLevel(record) == nil, "a potion has no item level to show")
	Data.Read(0, 1, record)
	local before = B.Count(env, "GetDetailedItemLevelInfo")
	Data.ItemLevel(record)
	assert(B.Count(env, "GetDetailedItemLevelInfo") == before, "an item level is asked once per link")
	env.C_Item.GetDetailedItemLevelInfo = function()
		return env.Secret(5)
	end
	record.link = "|Hitem:1000:new|h"
	assert(Data.ItemLevel(record) == nil, "a secret item level is not shown")
	assert(Data.ItemLevel({ empty = true }) == nil, "an empty slot has no item level")
end

-- Search -----------------------------------------------------------------------------------------

do
	local _, _, Data = New({
		bags = { [0] = { size = 3, items = { [1] = Item("sword"), [2] = Item("potion") } } },
	})
	assert(Data.Query("  ") == nil and Data.Query(nil) == nil, "a blank search is no search")
	assert(Data.Query("  PoTion ") == "potion", "a search is trimmed and lower case")
	local sword, potion, empty = Data.Read(0, 1, {}), Data.Read(0, 2, {}), Data.Read(0, 3, {})
	assert(Data.Matches(sword, nil) and Data.Matches(empty, nil), "no search matches every slot")
	assert(Data.Matches(potion, "heal"), "a search matches part of the name")
	assert(not Data.Matches(sword, "heal"), "a search skips other names")
	assert(Data.Matches(sword, "one-handed"), "a search matches the item's type and subtype")
	assert(Data.Matches(sword, "%[") == false, "a search treats symbols as plain text")
	assert(not Data.Matches(empty, "heal"), "an empty slot never matches a search")
end

-- Free slots ------------------------------------------------------------------------------------

do
	local _, _, Data = New({
		bags = { [0] = { size = 4, items = { [1] = Item("sword"), [3] = Item("potion") } }, [1] = { size = 2, items = {} } },
	})
	local free, total = Data.FreeSlots({ 0, 1 })
	assert(free == 4 and total == 6, "free slots count every empty slot of the listed bags: " .. tostring(free) .. "/" .. tostring(total))
end

print("bags data ok")
