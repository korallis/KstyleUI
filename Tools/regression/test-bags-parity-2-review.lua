-- test-bags-parity-2-review.lua: the review of #619, one case per finding: pinned copies, filters, pin coverage, sort to bottom, size limits, counts, the add entry, the preview, secret guards, hot-path work and the list rows.
local B = dofile("Tools/regression/bags_env.lua")
local W, Item = B.W, B.Item

local CURRENCIES = {
	{ name = "Honor", currencyID = 1901, quantity = 120, iconFileID = 1455894 },
	{ name = "Badges", isHeader = true },
	{ name = "Arena", currencyID = 390, quantity = 7, iconFileID = 133784 },
}

local function new(settings, opts)
	opts = opts or {}
	opts.saved = { version = 42, profiles = { Default = { Bags = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	opts.setup = function(env)
		env._alt = false
		env.IsAltKeyDown = function() return env._alt end
		env.C_Container.GetBagName = function(bag) return bag == 0 and "Backpack" or ("Pouch " .. bag) end
		local info = env.C_CurrencyInfo
		info.GetCurrencyListSize = function() return #CURRENCIES end
		info.GetCurrencyListInfo = function(i) return CURRENCIES[i] end
	end
	local env, K, ns = B.New(opts)
	env.ToggleAllBags()
	env.RunTimers()
	return env, K, ns, ns.Inventory.window
end

local function write(env, K, key, value)
	assert(K.Options.Write("Bags", key, value) ~= false, key .. " must write")
	env.RunTimers()
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function shown(region)
	return region ~= nil and region:IsShown() == true
end

local function slot(ns, bag, id)
	return ns.Inventory.Slot(bag, id)
end

local function altClick(env, s)
	env._alt = true
	s.button:GetScript("OnClick")(s.button, "LeftButton")
	env._alt = false
	env.RunTimers()
end

local function click(env, button)
	button:GetScript("OnClick")(button, "LeftButton")
	env.RunTimers()
end

local function y(s)
	return select(5, s.button:GetPoint(1))
end

local function rows(list)
	return list.scroll and list.scroll.rows or list.rows or list.entries
end

local function entry(list, label)
	for _, row in ipairs(rows(list)) do
		if row:IsShown() and row.item and row.item.label == label then return row end
	end
end

local failed = {}
local function case(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		failed[#failed + 1] = name .. ": " .. tostring(err)
	end
end

case("1 a smaller bag leaves no pinned copy behind", function()
	local env, K, ns, w = new({ enabled = true, pins = true }, { bags = { [1] = { size = 4, items = { [1] = Item("potion"), [4] = Item("sword") } } } })
	altClick(env, slot(ns, 1, 1))
	altClick(env, slot(ns, 1, 4))
	local old = w.pinSection.clones[1][4]
	env._bags[1].size = 2
	B.Put(env, 1, 4, nil)
	env.RunTimers()
	assert(#w.pinSection.order == 1 and not B.Shown(old.button), "the copy of a slot the bag lost hides")
	clean(env, K)
end)

case("2 turning a control off clears its filter", function()
	local env, K, ns, w = new({ enabled = true, sidebar = true, compactBags = true }, {
		bags = { [0] = { size = 5, items = { Item("sword"), Item("potion") } } },
		bank = { [6] = { size = 4, items = { Item("helm") } }, [7] = { size = 3, items = { Item("potion") } } },
	})
	ns.List.Pick(w, { kind = "only", value = "consumables" })
	write(env, K, "sidebar", false)
	assert(w.only == nil and B.Shown(w.sections[1].groups.equipment.view), "the list off shows every section")
	write(env, K, "sidebar", true)
	ns.List.Pick(w, { kind = "view", value = "grid" })
	write(env, K, "sidebar", false)
	assert(w.view == "all", "the list off returns to the view the window opens to")
	write(env, K, "sidebar", true)
	env.SetBank(true)
	env.RunTimers()
	local bank = ns.Bank.window
	ns.List.Pick(bank, { kind = "tab", value = 7 })
	assert(#bank.sections[1].order == 3, "a tab shows alone")
	write(env, K, "sidebarTabs", false)
	assert(bank.onlyBag == nil and #bank.sections[1].order == 7, "the tabs off show every tab")
	write(env, K, "sidebarTabs", true)
	ns.List.Pick(bank, { kind = "tab", value = 7 })
	write(env, K, "sidebar", false)
	assert(#bank.sections[1].order == 7, "the list off shows every tab")
	clean(env, K)
end)

case("3 pins cover every slot that takes the gesture", function()
	local env, K, ns, w = new({ enabled = true, compactBags = true, pins = true }, { bags = { [0] = { size = 2, items = { Item("sword") } }, [-1] = { size = 2, items = { Item("key") } } } })
	altClick(env, slot(ns, -1, 1))
	assert(#w.pinSection.order == 1 and w.pinSection.order[1].bag == -1, "a pinned key shows in Pinned")
	clean(env, K)
	env, K, ns, w = new({ enabled = true, compactBags = true, pins = true, pinsOnly = true, categorizeReagents = false }, { bags = { [5] = { size = 3, items = { Item("cloth") } } } })
	local free = w.free:GetText()
	altClick(env, slot(ns, 5, 1))
	assert(#w.pinSection.order == 1 and not B.Shown(slot(ns, 5, 1).button), "Only in Pinned takes it out of the reagent bag's section")
	assert(w.free:GetText() == free, "and the footer still counts its slot")
	clean(env, K)
end)

case("4 sort to bottom packs to the bottom and flips Blizzard's direction", function()
	local env, K, ns = new({ enabled = true, columns = 4, growth = "RIGHT_UP" }, { bags = { [0] = { size = 8, items = { [1] = Item("sword") } } } })
	write(env, K, "sortBottom", true)
	local item = y(slot(ns, 0, 1))
	for id = 2, 8 do
		assert(y(slot(ns, 0, id)) >= item, "growing up, the item sits on the bottom row")
	end
	assert(y(slot(ns, 0, 8)) > item, "and the empty slots fill the top")
	ns.Inventory.Sort()
	env.RunTimers()
	assert(env._rtl == true, "Sort packs from the other side while it is on")
	write(env, K, "sortBottom", false)
	assert(env._rtl == false, "off restores the Sort direction choice")
	clean(env, K)
end)

case("5 the list keeps the window's size limits", function()
	for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		local env, K, _, w = new({ enabled = true, sidebar = true, sidebarEmpty = true, compactBags = true, maxHeight = 30 }, { width = size[1], height = size[2], bags = { [0] = { size = 4, items = { Item("sword") } } } })
		assert(w.panel:GetHeight() <= w:ScreenHeight() * 0.3, size[1] .. "x" .. size[2] .. " stays under 30%, got " .. w.panel:GetHeight())
		assert(w.list.scroll:GetMaxOffset() > 0, "and the list scrolls")
		clean(env, K)
	end
	local env, K, _, w = new({ enabled = true, sidebar = true, shrink = false }, { bags = { [0] = { size = 4, items = { Item("sword") } } } })
	local width = w.panel:GetWidth()
	click(env, w.list.fold)
	assert(W.Near(w.panel:GetWidth(), width), "a held window keeps its width when the list folds, got " .. w.panel:GetWidth() .. " from " .. width)
	clean(env, K)
end)

case("6 a split category is not listed as empty", function()
	local env, K, ns, w = new({ enabled = true, compactBags = true, sidebar = true, sidebarEmpty = true, gearBySlot = true }, { bags = { [0] = { size = 3, items = { Item("sword", { equipLoc = "INVTYPE_WEAPON" }) } } } })
	for _, category in ipairs(ns.Data.Categories()) do
		if category.key == "equipment" then
			assert(not entry(w.list, category.label), "Equipment holds the sword, so it is not listed with 0")
		end
	end
	clean(env, K)
end)

case("7 the add entry opens the custom categories", function()
	local env, K, ns, w = new({ enabled = true, sidebar = true }, { bags = { [0] = { size = 2, items = { Item("sword") } } } })
	local open, target = K.Options.Open, nil
	K.Options.Open = function(page) target = page return true end
	ns.List.Pick(w, { kind = "add" })
	K.Options.Open = open
	assert(type(target) == "table" and target.page == "Bags" and target.module == "Bags" and target.key == "custom1.name", "it jumps to the first custom category")
	assert(K.Options.Row("Bags", "custom1.name"), "a row the settings page has")
	clean(env, K)
end)

case("8 the preview shows the list, the view and the pins", function()
	local env, K = new({ enabled = true, compactBags = true }, {})
	local preview = K.Options.Preview("Bags")(env.CreateFrame("Frame", nil, K.Scale.Root()))
	write(env, K, "sortBottom", true)
	preview:Refresh()
	assert(preview.slots[1].icon:GetTexture() == 134829, "Sort to bottom leaves the sections' preview alone, as it leaves sections")
	write(env, K, "openTo", "grid")
	preview:Refresh()
	assert(preview.slots[1].icon:GetTexture() == nil, "and puts the empty sample first in one grid")
	write(env, K, "sortBottom", false)
	write(env, K, "openTo", "bags")
	preview:Refresh()
	assert(preview.title.label:GetText():lower():find("backpack", 1, true), "bag by bag titles the card with the bag's name")
	write(env, K, "sidebar", true)
	preview:Refresh()
	local view = preview.list and entry(preview.list, K.L["Bag by bag"])
	assert(shown(preview.list) and view and view.item.selected, "the list shows, with the view the window opens to")
	write(env, K, "pins", true)
	preview:Refresh()
	assert(shown(preview.pinCap) and preview.pin.icon:GetTexture() == 135274, "Pinned shows its sample")
	write(env, K, "pinsDim", true)
	preview:Refresh()
	assert(preview.slots[2].icon:GetAlpha() < 1, "Dim pinned dims the original in a grid")
	write(env, K, "openTo", "all")
	write(env, K, "pinsOnly", true)
	preview:Refresh()
	for _, s in ipairs(preview.slots) do
		assert(not (shown(s.button) and s.icon:GetTexture() == 135274), "Only in Pinned takes it out of the card")
	end
	write(env, K, "pins", false)
	write(env, K, "sidebar", false)
	preview:Refresh()
	assert(not shown(preview.pinCap) and not shown(preview.list), "off removes both")
	clean(env, K)
end)

case("9 a restricted Alt state pins nothing", function()
	local env, K, ns, w = new({ enabled = true, pins = true }, { bags = { [0] = { size = 2, items = { Item("sword") } } } })
	env.IsAltKeyDown = function() return env.Secret(false) end
	local s = slot(ns, 0, 1)
	s.button:GetScript("OnClick")(s.button, "LeftButton")
	env.RunTimers()
	assert(#w.pinSection.order == 0, "no copy made")
	clean(env, K)
end)

case("10 inventory events do no repeated work", function()
	local env, K, ns, w = new({ enabled = true, openTo = "bags" }, { bags = { [0] = { size = 80, items = { [1] = Item("sword") } } } })
	assert(w.pinSection == nil, "no Pinned section is made while pins are off")
	local calls, get = 0, env.C_Container.GetBagName
	env.C_Container.GetBagName = function(...) calls = calls + 1 return get(...) end
	env.FireEvent("BAG_UPDATE_DELAYED")
	env.RunTimers()
	assert(calls == 1, "one bag name read per bag, got " .. calls)
	local reads, read = 0, ns.Data.Read
	ns.Data.Read = function(...) reads = reads + 1 return read(...) end
	altClick(env, slot(ns, 0, 1))
	ns.Data.Read = read
	assert(reads == 0, "Alt-click reads nothing while pins are off, got " .. reads)
	local seen, drop = {}, ns.Data.Drop
	ns.Data.Drop = function(bags, ...)
		for _, bag in ipairs(bags) do
			assert(not seen[bag], "bag " .. bag .. " offered twice to a drop")
			seen[bag] = true
		end
		return drop(bags, ...)
	end
	env.HoldItem(Item("potion"))
	w:Drop()
	write(env, K, "pins", true)
	seen = {}
	w:Drop()
	env.HoldItem(nil)
	ns.Data.Drop = drop
	assert(K.Store.Account().bagPins == nil, "turning pins on stores nothing before a pin")
	write(env, K, "sidebar", true)
	local row, writes = rows(w.list)[1], 0
	for _, target in ipairs({ row, row.label }) do
		for _, name in ipairs({ "SetSize", "SetPoint", "SetHeight", "SetText" }) do
			local fn = target[name]
			if fn then
				target[name] = function(...) writes = writes + 1 return fn(...) end
			end
		end
	end
	env.FireEvent("BAG_UPDATE_DELAYED")
	env.RunTimers()
	assert(writes == 0, "an unchanged update leaves the list rows alone, got " .. writes)
	clean(env, K)
end)

case("11 the list rows match the settings rail", function()
	local env, K, _, w = new({ enabled = true, sidebar = true }, { bags = { [0] = { size = 4, items = { Item("sword") } } } })
	local all, grid = entry(w.list, K.L["All items"]), entry(w.list, K.L["One grid"])
	assert(W.Near(grid:GetHeight(), 26), "rows are the rail's section height")
	assert(shown(all.mark) and not shown(grid.mark) and W.Near(all.mark:GetWidth(), 2) and W.Near(all.mark:GetHeight(), 10), "only the selected row wears the rail's mark")
	W.Enter(grid)
	W.Settle(env)
	assert(select(4, grid.hover:GetVertexColor()) > 0, "and a pointer gets the hover wash")
	clean(env, K)
end)

assert(#failed == 0, #failed .. " of the review's findings still reproduce:\n" .. table.concat(failed, "\n"))
print("bags parity 2 review ok: every finding fixed")
