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

-- Search grammar: & | ! ( ), keywords, type: and item level ranges ------------------------------

do
	local env, _, Data = New({
		bags = {
			[0] = {
				size = 8,
				items = {
					[1] = Item("sword"), [2] = Item("potion"), [3] = Item("helm", { bound = true }), [4] = Item("junk"),
					[5] = Item("cloth"), [6] = Item("ring"), [7] = Item("hearth"),
				},
			},
		},
	})
	env._new["0:2"] = true
	local function Slot(i)
		return Data.Read(0, i, {})
	end
	local sword, potion, helm, junk, cloth, ring, hearth, empty = Slot(1), Slot(2), Slot(3), Slot(4), Slot(5), Slot(6), Slot(7), Slot(8)
	local function M(record, text)
		return Data.Matches(record, Data.Query(text)) == true
	end
	assert(M(sword, "sword & weapon") and not M(sword, "sword & potion"), "& needs both sides")
	assert(M(sword, "sword | potion") and M(potion, "sword | potion") and not M(cloth, "sword | potion"), "| needs one side")
	assert(M(potion, "!sword") and not M(sword, "!sword"), "! negates a term")
	assert(not M(empty, "!sword"), "an empty slot never matches, even a negated search")
	assert(M(cloth, "!(sword | potion)") and not M(potion, "!(sword | potion)"), "brackets group")
	assert(M(sword, "weapon | armor & !leather") and M(ring, "weapon | armor & !leather") and not M(helm, "weapon | armor & !leather"), "& binds tighter than |")
	assert(M(potion, "  heal  &  potion "), "spaces around operators are ignored")
	assert(M(potion, "minor heal"), "a phrase with a space is one term, as before")
	assert(M(sword, "sword &") and M(sword, "| sword") and M(sword, "(sword"), "an unfinished expression still matches what it can")
	assert(M(junk, "junk") and not M(hearth, "junk"), "junk is a keyword for a poor item that sells")
	assert(M(potion, "new") and not M(sword, "new"), "new matches an item the game marks new")
	assert(M(helm, "bound") and not M(sword, "bound") and M(sword, "unbound") and not M(helm, "unbound"), "bound and unbound read the bind state")
	assert(M(sword, "equipment") and M(ring, "gear") and not M(potion, "equipment"), "equipment and gear are the equipment category")
	assert(M(potion, "consumable") and M(cloth, "trade") and M(cloth, "reagent") and M(hearth, "other"), "the other categories are keywords too")
	assert(M(ring, "rare") and M(helm, "epic") and M(sword, "uncommon") and M(potion, "common") and M(junk, "poor") and not M(sword, "rare"), "quality names match the quality")
	assert(M(sword, "type:weapon") and M(sword, "type:one-handed") and not M(sword, "type:worn"), "type: searches the type and subtype only")
	assert(M(sword, "name:worn") and not M(sword, "name:weapon"), "name: searches the name only")
	assert(M(helm, "ilvl>30") and not M(ring, "ilvl>30") and M(ring, "ilvl>=30"), "ilvl> and ilvl>= compare the item level")
	assert(M(sword, "ilvl<30") and M(ring, "ilvl<=30") and not M(helm, "ilvl<30"), "ilvl< and ilvl<= compare the item level")
	assert(M(ring, "ilvl=30") and M(ring, "ilvl:30") and not M(sword, "ilvl=30"), "ilvl= and ilvl: match one level")
	assert(M(ring, "ilvl:12-30") and M(sword, "ilvl:12-30") and not M(helm, "ilvl:12-30"), "ilvl:a-b is a range")
	assert(M(helm, "#>60") and M(ring, "#12-30") and M(sword, "#12"), "# is short for ilvl")
	assert(not M(potion, "ilvl>0") and not M(potion, "ilvl<999"), "an item without a level never matches a level search")
	assert(M(helm, "armor & ilvl>60 & epic & bound"), "keywords combine")
	assert(M(potion, "!!potion") and not M(sword, "!!potion"), "double negation cancels")
	assert(not M(sword, "&") and not M(sword, "!") and not M(sword, "()"), "an expression with no term matches nothing")
	local compiled = Data.Compile(Data.Query("sword | potion"))
	assert(type(compiled) == "function" and Data.Compile(Data.Query("sword | potion")) == compiled, "a compiled search is cached by its text")
	assert(Data.Compile(nil) == nil, "no search compiles to nothing")
end

-- Free slots ------------------------------------------------------------------------------------

do
	local _, _, Data = New({
		bags = { [0] = { size = 4, items = { [1] = Item("sword"), [3] = Item("potion") } }, [1] = { size = 2, items = {} } },
	})
	local free, total = Data.FreeSlots({ 0, 1 })
	assert(free == 4 and total == 6, "free slots count every empty slot of the listed bags: " .. tostring(free) .. "/" .. tostring(total))
end

-- Categories ------------------------------------------------------------------------------------

do
	local env, _, Data = New({
		bags = {
			[0] = {
				size = 9,
				items = {
					[1] = Item("potion"), [2] = Item("sword"), [3] = Item("helm"), [4] = Item("junk"), [5] = Item("hearth"),
					[6] = Item("cloth"), [7] = Item("key"), [8] = Item("greyNoValue"),
				},
			},
		},
	})
	local order = {}
	for i, category in ipairs(Data.CATEGORIES) do
		order[category.key] = i
		assert(type(category.key) == "string" and type(category.label) == "string" and category.label ~= "", "each category has a key and a label")
	end
	assert(order.equipment and order.consumables and order.tradeGoods and order.quest and order.other and order.junk and order.empty, "the seven categories exist")
	assert(order.equipment < order.consumables and order.consumables < order.tradeGoods, "equipment, then consumables, then trade goods")
	assert(order.junk < order.empty and order.other < order.junk, "junk sits before the empty slots, after everything else")
	local function Category(slot)
		return Data.Category(Data.Read(0, slot, {}))
	end
	assert(Category(1) == "consumables", "a potion is a consumable")
	assert(Category(2) == "equipment" and Category(3) == "equipment", "weapons and armour are equipment")
	assert(Category(4) == "junk", "a poor item with a sell value is junk, whatever its class")
	assert(Category(5) == "other", "the hearthstone is other")
	assert(Category(6) == "tradeGoods", "cloth is trade goods")
	assert(Category(7) == "other", "a key outside the keyring is other")
	assert(Category(8) == "other", "a poor item with no sell value is not junk")
	assert(Category(9) == "empty", "an empty slot is empty")
	local info = env.C_Item.GetItemInfoInstant
	env.C_Item.GetItemInfoInstant = nil
	assert(Category(2) == "other", "without the item class the item is other, not an error")
	env.C_Item.GetItemInfoInstant = info
	local secret = Data.Read(0, 2, {})
	secret.itemID = env.Secret(1000)
	assert(Data.Category(secret) == "other", "a secret item ID is other")
end

-- Custom categories: named search rules that sort before the built-in categories ---------------

do
	local _, K, Data = New({
		bags = {
			[0] = { size = 4, items = { [1] = Item("potion"), [2] = Item("sword"), [3] = Item("hearth") } },
		},
	})
	local function Category(slot)
		return Data.Category(Data.Read(0, slot, {}))
	end
	local list = Data.Categories()
	assert(#list == #Data.CATEGORIES and list[1].key == "equipment", "with no custom category the list is the built-in one")
	assert(K.Options.Write("Bags", "custom1.name", "Travel") ~= false and K.Options.Write("Bags", "custom1.rule", "hearth | potion") ~= false, "custom category rows write")
	list = Data.Categories()
	assert(#list == #Data.CATEGORIES + 1 and list[1].key == "custom1" and list[1].label == "Travel" and list[2].key == "equipment", "a custom category comes first, with its name as the label")
	assert(Category(1) == "custom1" and Category(3) == "custom1", "items the rule matches land in the custom category")
	assert(Category(2) == "equipment" and Category(4) == "empty", "other items keep their built-in category")
	K.Options.Write("Bags", "custom2.name", "Blades")
	assert(#Data.Categories() == #Data.CATEGORIES + 1, "a custom category without a rule is not listed")
	K.Options.Write("Bags", "custom2.rule", "sword")
	assert(#Data.Categories() == #Data.CATEGORIES + 2 and Data.Categories()[2].key == "custom2", "custom categories keep their slot order")
	assert(Category(2) == "custom2", "the rule claims the sword")
	K.Options.Write("Bags", "custom1.rule", "")
	assert(Category(1) == "consumables" and Category(3) == "other", "clearing a rule returns its items to the built-in categories")
	K.Options.Write("Bags", "custom2.rule", "&")
	assert(Category(2) == "equipment", "a rule that matches nothing claims nothing")
end

print("bags data ok")
