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
		bankTabs = { [B.BANK.Character] = { 7, 6 } },
	})
	env.SetBank(true)
	env.RunTimers()
	W.Settle(env)
	return env, K, ns
end

local function Empty(win, bag)
	for _, slot in ipairs(win.sections[1].groups.empty.order) do
		if not bag or slot.bag == bag then
			local target = slot.dropTarget and slot.dropTarget:IsShown() and slot.dropTarget or slot.button
			local env, resolve = slot.button._env, slot.button._env._resolveRects
			env._resolveRects = true
			local left, bottom, width, height = slot.button:GetRect()
			local x, y, w, h = target:GetRect()
			env._resolveRects = resolve
			assert(W.Near(left, x) and W.Near(bottom, y) and W.Near(width, w) and W.Near(height, h) and width > 0, "the active drop target covers the visible EMPTY tile")
			return target
		end
	end
	error("no empty tile for bag " .. tostring(bag))
end

local function Placed(env, target, held, bag, slot, drag)
	env.HoldItem(held)
	if type(target) == "function" then target = target() end
	if drag then
		local receive = target:GetScript("OnReceiveDrag")
		if receive then receive(target) end
	else
		W.Click(target)
	end
	assert(not env.CursorHasItem(), "drop a held item onto category space or the EMPTY tile")
	assert(env._container(bag).items[slot] == held, "drop uses the requested bag before other suitable free slots")
end

-- The first scenario is red on staging: unused category row space has no stock slot underneath it.
do
	local env, _, ns = New()
	local inventory, bank = ns.Inventory.window, ns.Bank.window
	Placed(env, bank.sections[1].groups.equipment.view, Item("potion", { count = 2 }), 7, 2)
	assert(env._bags[0].items[1].count == 5, "placing a split stack leaves its source alone")
	Placed(env, function() return Empty(inventory, 1) end, Item("cloth", { family = 32 }), 1, 1)
	Placed(env, function() return Empty(inventory, 1) end, Item("sword"), 0, 2, true)
	Placed(env, function() return Empty(bank, 6) end, Item("cloth", { family = 32 }), 6, 1)
	Placed(env, function() return Empty(bank, 6) end, Item("sword"), 7, 3)
	Placed(env, inventory.sections[1].groups.consumables.view, Item("helm"), 2, 1, true)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, _, ns = New()
	local win = ns.Inventory.window
	local button = Empty(win)
	local slot = win.sections[1].groups.empty.order[1]
	assert(button == slot.button and not slot.dropTarget:IsShown(), "an empty cursor keeps the stock slot exposed")
	W.Enter(button)
	W.Settle(env)
	assert(slot.hoverT == 1, "EMPTY retains its hover rim without an item")
	W.Leave(button)
	W.Click(button, "RightButton")
	W.Click(button)
	assert(B.Count(env, "PickupContainerItem") == 0 and B.Count(env, "UIError") == 0, "empty cursor clicks do nothing new")
	for _, kind in ipairs({ "merchant", "money", "guildbankmoney" }) do
		env.HoldCursor(kind)
		local target = Empty(win)
		assert(target == slot.button and not slot.dropTarget:IsShown(), "non-item cursors expose the stock slot")
		W.Click(target)
		target:GetScript("OnReceiveDrag")(target)
	end
	assert(B.Count(env, "StockMerchantCursor") == 2 and B.Count(env, "StockMoneyCursor") == 4, "stock merchant and money click/drag paths still run")
	env.HoldItem(Item("potion"))
	local target = Empty(win)
	assert(slot.state.drop and target == slot.dropTarget, "item cursors highlight and enable the drop target")
	W.Enter(target)
	W.Settle(env)
	assert(slot.hoverT == 1, "the item drop overlay also keeps the hover rim")
	W.Leave(target)
	local paint, painted = ns.Slot.Paint, {}
	ns.Slot.Paint = function(tile) painted[tile] = true; paint(tile) end
	env.FireEvent("CURSOR_CHANGED")
	assert(next(painted) == nil, "unchanged cursor state must not repaint slots")
	env.HoldItem(nil)
	assert(not slot.state.drop and not slot.dropTarget:IsShown(), "clearing the item restores stock interaction")
	for tile in pairs(painted) do assert(tile.state.empty, "cursor changes must not repaint occupied slots") end
	ns.Slot.Paint = paint
	env.SetCombat(true)
	Placed(env, function() return Empty(win) end, Item("potion"), 0, 2)
	env.SetCombat(false)
	assert(not env.CursorHasItem(), "combat placement runs immediately and queues nothing")
end

do
	local env, _, ns = New()
	env._bags[0].items[2] = Item("hearth")
	env._bags[2].items = { Item("sword"), Item("ring") }
	env.FireEvent("BAG_UPDATE_DELAYED")
	env.HoldItem(Item("sword"))
	W.Click(Empty(ns.Inventory.window, 1))
	assert(env.CursorHasItem() and B.Count(env, "PickupContainerItem") == 0, "non-reagents and non-keys skip specialist storage")
	local errors = B.Calls(env, "UIError")
	assert(errors[1] and errors[1][1] == env.ERR_INV_FULL, "when nothing fits, show Blizzard's inventory-full error: " .. table.concat(env._errors, "; ") .. "; printed=" .. table.concat(env._printed, "; "))
	Placed(env, function() return Empty(ns.Inventory.window, 1) end, Item("cloth", { family = 32 }), 1, 1)
	Placed(env, function() return Empty(ns.Inventory.window, 1) end, Item("cloth", { reagent = true }), 5, 1)
	Placed(env, function() return Empty(ns.Inventory.window, 1) end, Item("key"), -1, 1)
end

do
	local env, _, ns = New()
	local key = Item("key")
	env.HoldItem(key)
	local keySlot = ns.Inventory.Slot(-1, 1)
	W.Click(keySlot.button)
	assert(env._bags[-1].items[1] == key and not env._bags[0].items[2], "an explicit keyring drop keeps the key out of the backpack")
	local helm = env._bank[7].items[1]
	env.C_Container.PickupContainerItem(7, 1)
	W.Click(Empty(ns.Inventory.window))
	assert(env._bags[0].items[2] == helm and not env._bank[7].items[1] and not env.CursorHasItem(), "bank to bags uses the bags destination")
	env.C_Container.PickupContainerItem(0, 2)
	W.Click(Empty(ns.Bank.window))
	assert(env._bank[7].items[1] == helm and not env._bags[0].items[2] and not env.CursorHasItem(), "bags to bank uses the selected bank destination")
	env.HoldItem(Item("sword"))
	local bankTile = Empty(ns.Bank.window)
	env.SetBank(false)
	local before = B.Count(env, "PickupContainerItem")
	W.Click(bankTile)
	assert(env.CursorHasItem() and B.Count(env, "PickupContainerItem") == before, "no bank placement after the visit closes")
end

print("bags drop ok")
