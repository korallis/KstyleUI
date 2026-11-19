-- test-bags-steady.lua: item changes keep every physical slot and the bag and bank windows in place.
local B = dofile("Tools/regression/bags_env.lua")
local Item = B.Item

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = B.New({ width = screen[1], height = screen[2],
		saved = { profiles = { Default = { Bags = { layout = "categories", emptySlots = "packed" } } } }, bags = {
		[0] = { size = 20, items = { Item("potion"), Item("sword"), Item("junk") } },
		[1] = { size = 8, items = { Item("helm") } },
		[5] = { size = 12, items = { Item("cloth") } },
		[-1] = { size = 4, items = { Item("key") } },
	}, bank = {
		[6] = { size = 28, items = { Item("cloth"), Item("helm"), Item("junk") } },
		[15] = { size = 28, items = { Item("ring"), Item("potion"), Item("junk") } },
	}, bankTabs = { [B.BANK.Character] = { 6 }, [B.BANK.Account] = { 15 } } })
	env.SetBank(true)
	env.SetMerchant(true)
	env.RunTimers()
	B.W.Settle(env)
	env._resolveRects = true
	local function Rect(frame)
		return { frame:GetRect() }
	end
	local function Snapshot(win)
		local result = { [win.panel] = Rect(win.panel) }
		for _, section in ipairs(win.sections) do
			for _, slot in ipairs(section.order) do
				assert(slot.button:IsVisible(), "show every empty socket in the steady grid")
				result[slot.button] = Rect(slot.button)
			end
		end
		return result
	end
	local function Same(before, label)
		env.RunTimers()
		B.W.Settle(env)
		for frame, rect in pairs(before) do
			assert(frame:IsVisible(), label .. ": every socket stays visible")
			local now = Rect(frame)
			for i = 1, 4 do
				assert(B.W.Near(rect[i], now[i]), label .. ": keep window size and every slot position at " .. screen[1] .. "x" .. screen[2])
			end
		end
	end
	for _, bankType in ipairs({ B.BANK.Character, B.BANK.Account }) do
		ns.Bank.SelectType(bankType)
		local before = Snapshot(ns.Bank.window)
		for frame, rect in pairs(Snapshot(ns.Inventory.window)) do before[frame] = rect end
		local bag = bankType == B.BANK.Character and 6 or 15
		for _, target in ipairs({ 0, 5, -1, bag }) do
			B.Put(env, target, 4, Item("ring"))
			Same(before, "loot or deposit")
			B.Put(env, target, 3, nil)
			Same(before, "sell or withdraw")
			B.Put(env, target, 1, Item("potion", { count = 3 }))
			B.Put(env, target, 2, Item("potion", { count = 2 }))
			Same(before, "split stack")
		end
		ns.Inventory.Sort()
		ns.Bank.Sort()
		B.Put(env, 0, 1, Item("sword"))
		B.Put(env, 0, 2, Item("potion"))
		B.Put(env, bag, 1, Item("helm"))
		B.Put(env, bag, 2, Item("cloth"))
		Same(before, "sort keeps the grid size")
		env.SetCombat(true)
		B.Put(env, 0, 6, Item("cloth"))
		Same(before, "looting in combat")
		env.SetCombat(false)
	end
	assert(ns.Settings.Get("compactBags") == false, "Compact bags defaults off, including existing profiles")
	local row = K.Options.Row("Bags", "compactBags")
	assert(row and row.type == "toggle" and row.label == "Compact bags", "expose Compact bags in Options")
	K.Options.Write("Bags", "compactBags", true)
	assert(ns.Inventory.window.sections[1].groups.equipment.view:IsShown(), "Compact bags restores category sections")
	K.Options.Write("Bags", "compactBags", false)
	Snapshot(ns.Inventory.window)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("bags steady ok")
