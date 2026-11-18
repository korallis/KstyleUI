-- test-bags-drop.lua: a held item goes to a suitable free slot through packed tiles and category space.
local B = dofile("Tools/regression/bags_env.lua")
local W, Item = B.W, B.Item

local function New()
	local env, K, ns = B.New({
		bags = {
			[0] = { size = 2, items = { [1] = Item("potion") } },
			[1] = { size = 2, family = 32, items = {} },
			[2] = { size = 2, items = {} },
			[5] = { size = 2, items = {} },
			[-1] = { size = 2, items = {} },
		},
		bank = { [6] = { size = 2, family = 32, items = {} }, [7] = { size = 3, items = { [1] = Item("helm") } } },
	})
	env.SetBank(true)
	env.RunTimers()
	W.Settle(env)
	return env, K, ns
end

local function Empty(win, bag)
	for _, slot in ipairs(win.sections[1].groups.empty.order) do
		if not bag or slot.bag == bag then
			return slot.button
		end
	end
	error("no empty tile for bag " .. tostring(bag))
end

local function Placed(env, target, held, bag, slot, drag)
	env.HoldItem(held)
	if drag then
		local receive = target:GetScript("OnReceiveDrag")
		if receive then receive(target) end
	else
		W.Click(target)
	end
	assert(not env.CursorHasItem(), "drop a held item onto the empty tile or category space")
	assert(env._container(bag).items[slot] == held, "drop uses the first suitable free slot")
end

do
	local env, _, ns = New()
	local held = Item("potion", { count = 2 })
	Placed(env, Empty(ns.Inventory.window), held, 0, 2)
	assert(env._bags[0].items[1].count == 5, "placing a split stack leaves its source alone")
	Placed(env, Empty(ns.Inventory.window, 1), Item("sword"), 2, 1, true)
	assert(not env._bags[1].items[1], "a profession bag mismatch is skipped")
	Placed(env, Empty(ns.Bank.window), Item("sword"), 7, 2)
	assert(not env._bank[6].items[1], "the bank skips an incompatible bag too")
	Placed(env, ns.Inventory.window.sections[1].groups.consumables.view, Item("helm"), 2, 2, true)
	Placed(env, ns.Bank.window.sections[1].groups.equipment.view, Item("potion"), 7, 3)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, _, ns = New()
	local tile = Empty(ns.Inventory.window)
	W.Click(tile, "RightButton")
	W.Click(tile)
	assert(B.Count(env, "PickupContainerItem") == 0, "empty cursor clicks do nothing new")
	env.HoldItem(Item("potion"))
	env.SetCombat(true)
	W.Click(tile)
	assert(B.Count(env, "PickupContainerItem") == 0 and env.CursorHasItem(), "no placement or deferred cursor action in combat")
	env.SetCombat(false)
	assert(env.CursorHasItem(), "leaving combat does not move the cursor item")
end

do
	local env, _, ns = New()
	env._bags[0].items[2] = Item("hearth")
	env._bags[2].items = { Item("sword"), Item("ring") }
	env.FireEvent("BAG_UPDATE_DELAYED")
	local tile = Empty(ns.Inventory.window, 1)
	env.HoldItem(Item("sword"))
	W.Click(tile)
	assert(env.CursorHasItem() and B.Count(env, "PickupContainerItem") == 0, "non-reagents and non-keys cannot use reagent bags or the keyring")
	Placed(env, tile, Item("cloth", { family = 32 }), 1, 1)
	Placed(env, Empty(ns.Inventory.window, 1), Item("cloth", { reagent = true }), 5, 1)
	Placed(env, Empty(ns.Inventory.window, 1), Item("key"), -1, 1)
end

print("bags drop ok")
