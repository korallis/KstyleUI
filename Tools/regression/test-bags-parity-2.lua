-- test-bags-parity-2.lua: round 2 bag options keep today's defaults, apply when switched on, restore when off and follow their events.
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
	local inner = opts.setup
	opts.setup = function(env)
		env._alt = false
		env.IsAltKeyDown = function() return env._alt end
		env.C_Container.GetBagName = function(bag) return bag == 0 and "Backpack" or ("Pouch " .. bag) end
		local info = env.C_CurrencyInfo
		info.GetCurrencyListSize = function() return #CURRENCIES end
		info.GetCurrencyListInfo = function(i) return CURRENCIES[i] end
		info.GetCurrencyInfo = function(id)
			for _, entry in ipairs(CURRENCIES) do
				if entry.currencyID == id then return entry end
			end
		end
		if inner then inner(env) end
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

local function y(s)
	return select(5, s.button:GetPoint(1))
end

local function entry(win, label)
	for _, e in ipairs(win.list.entries) do
		if e:IsShown() and e.item.label == label then return e end
	end
end

local function click(env, button)
	button:GetScript("OnClick")(button, "LeftButton")
	env.RunTimers()
end

-- Defaults and a v0.2.8-shaped profile: nothing new is drawn, nothing is stored and every new key reads its default.
do
	local env, K, ns, win = new({ enabled = true, columns = 7 }, { bags = { [0] = { size = 6, items = { [2] = Item("sword"), [3] = Item("potion") } } } })
	local S = ns.Settings
	for key, value in pairs({ shrink = true, sortBottom = false, currency1 = 0, currency3 = 0, pins = false, pinsOnly = false, pinsInGrid = true, pinsDim = false, pinsPerCharacter = true, openTo = "all", sidebar = false, sidebarEmpty = false, sidebarAdd = true, sidebarHide = false, sidebarTabs = true }) do
		assert(S.Get(key) == value, key .. " keeps its default")
	end
	assert(K.Store.Module("Bags").columns == 7, "the old columns survive")
	assert(not win.list and #win.sections[4].order == 0 and win.view == "all", "no list, no Pinned section, all items")
	assert(win.sections[1].order[1] == slot(ns, 0, 1) and y(slot(ns, 0, 1)) == 0, "the grid keeps bag order")
	altClick(env, slot(ns, 0, 3))
	assert(K.Store.Account().bagPins == nil and #win.sections[4].order == 0, "Alt-click pins nothing while pins are off")
	clean(env, K)
end

-- Shrink while open: on by default; off holds the size until the window closes.
do
	local items = { Item("sword"), Item("potion"), Item("cloth"), Item("junk") }
	local env, K, ns, win = new({ enabled = true, compactBags = true }, { bags = { [0] = { size = 8, items = items } } })
	local panel = win.panel
	local function gap() return win.footerLine:GetTop() - panel:GetBottom() end
	local height, footer = panel:GetHeight(), gap()
	B.Put(env, 0, 2, nil)
	B.Put(env, 0, 3, nil)
	env.RunTimers()
	assert(panel:GetHeight() < height, "by default the window shrinks while open")
	B.Put(env, 0, 2, Item("potion"))
	B.Put(env, 0, 3, Item("cloth"))
	env.RunTimers()
	write(env, K, "shrink", false)
	height = panel:GetHeight()
	local width = panel:GetWidth()
	B.Put(env, 0, 2, nil)
	B.Put(env, 0, 3, nil)
	env.RunTimers()
	assert(W.Near(panel:GetHeight(), height) and W.Near(panel:GetWidth(), width), "off holds the size while open")
	assert(W.Near(gap(), footer), "the footer stays at the bottom of a held window")
	ns.Inventory.Close()
	env.RunTimers()
	ns.Inventory.Open()
	env.RunTimers()
	assert(panel:GetHeight() < height, "closing lets it fit again")
	B.Put(env, 0, 2, Item("potion"))
	env.RunTimers()
	local grown = panel:GetHeight()
	B.Put(env, 0, 2, nil)
	env.RunTimers()
	write(env, K, "shrink", true)
	assert(panel:GetHeight() < grown, "turning it back on shrinks at once")
	clean(env, K)
end

-- Sort to bottom: grids show empty slots first, items after in their order; the bank and bag by bag too.
do
	local env, K, ns, win = new({ enabled = true, columns = 4 }, {
		bags = { [0] = { size = 6, items = { [1] = Item("sword"), [3] = Item("potion") } } },
		bank = { [6] = { size = 3, items = { [1] = Item("helm") } } },
	})
	local order = win.sections[1].order
	write(env, K, "sortBottom", true)
	assert(order[1] == slot(ns, 0, 2) and order[5] == slot(ns, 0, 1) and order[6] == slot(ns, 0, 3), "empty slots first, items in their order")
	assert(y(slot(ns, 0, 2)) == 0 and y(slot(ns, 0, 1)) < 0, "the sword moves to the bottom row")
	B.Put(env, 0, 2, Item("cloth"))
	env.RunTimers()
	assert(order[4] == slot(ns, 0, 1) and order[5] == slot(ns, 0, 2), "a new item joins the packed items in bag order")
	env.SetBank(true)
	env.RunTimers()
	local bank = ns.Bank.window.sections[1].order
	assert(bank[3] == ns.Bank.window:Slot(6, 1), "the bank grid packs to the bottom too")
	env.SetBank(false)
	write(env, K, "openTo", "bags")
	assert(win.sections[1].groups.bag0.order[1] == slot(ns, 0, 4), "bag by bag packs each bag")
	write(env, K, "openTo", "all")
	write(env, K, "sortBottom", false)
	assert(order[1] == slot(ns, 0, 1) and y(slot(ns, 0, 1)) == 0, "off restores bag order")
	write(env, K, "compactBags", true)
	write(env, K, "sortBottom", true)
	assert(win.sections[1].groups.equipment.order[1] == slot(ns, 0, 1), "sections are left alone")
	clean(env, K)
end

-- Chosen currencies replace the backpack's, follow CURRENCY_DISPLAY_UPDATE and show in the preview.
do
	local env, K, _, win = new({ enabled = true, currencies = true }, { currencies = { { quantity = 55, iconFileID = 1 } } })
	assert(win.currency:GetText() == "|T1:0|t 55", "the backpack's by default")
	local options = K.Options.Row("Bags", "currency1").options()
	assert(#options == 3 and options[2].label == "Honor" and options[3].value == 390, "the dropdown lists the currency tab without its headers")
	write(env, K, "currency1", 390)
	assert(win.currency:GetText() == "|T133784:0|t 7", "a chosen currency replaces the backpack's, got " .. win.currency:GetText())
	CURRENCIES[3].quantity = 9
	env.FireEvent("CURRENCY_DISPLAY_UPDATE")
	assert(win.currency:GetText() == "|T133784:0|t 9", "it follows CURRENCY_DISPLAY_UPDATE")
	CURRENCIES[3].quantity = 7
	local preview = K.Options.Preview("Bags")(env.CreateFrame("Frame", nil, K.Scale.Root()))
	assert(preview.currency:GetText() == "|T133784:0|t 7", "the preview shows the chosen currency")
	write(env, K, "currency2", 4242)
	assert(win.currency:GetText() == "|T133784:0|t 7", "an unknown currency shows nothing")
	env.C_CurrencyInfo.GetCurrencyInfo = function() return env.Secret({}) end
	env.FireEvent("CURRENCY_DISPLAY_UPDATE")
	assert(win.currency:GetText():find("backpack", 1, true), "a secret answer shows no number")
	write(env, K, "currency1", 0)
	write(env, K, "currency2", 0)
	assert(win.currency:GetText() == "|T1:0|t 55", "choosing none restores the backpack's")
	clean(env, K)
end

-- Pinned items: Alt-click pins, Pinned sits first, Only in Pinned, grids, dimming, per character and combat.
do
	local env, K, ns, win = new({ enabled = true, compactBags = true, pins = true }, { bags = { [0] = { size = 6, items = { Item("sword"), Item("potion"), Item("cloth") } } } })
	local pins, groups = win.sections[4], win.sections[1].groups
	altClick(env, slot(ns, 0, 2))
	local copy = pins.order[1]
	assert(#pins.order == 1 and copy.pinned and shown(copy.button) and copy.icon:GetTexture() == 134829, "Alt-click pins the potion into Pinned")
	assert(copy.button:GetID() == 2 and copy.button:GetParent():GetID() == 0, "the copy is Blizzard's button for the same bag slot")
	assert(groups.consumables.total == 1 and shown(slot(ns, 0, 2).button), "and the potion stays in its section")
	assert(shown(pins.cap) and select(5, pins.view:GetPoint(1)) > select(5, win.viewport:GetPoint(1)), "Pinned sits above the sections")
	write(env, K, "pinsOnly", true)
	assert(not shown(slot(ns, 0, 2).button) and groups.consumables.total == 0, "Only in Pinned takes it out of its section")
	write(env, K, "recentItems", true)
	env._new["0:2"] = true
	env.FireEvent("BAG_UPDATE_DELAYED")
	env.RunTimers()
	assert(not groups.recent or groups.recent.total == 0, "and out of Recent items")
	write(env, K, "pinsOnly", false)
	assert(shown(slot(ns, 0, 2).button) and groups.recent.total == 1, "off puts it back")
	write(env, K, "recentItems", false)
	B.Put(env, 0, 2, nil)
	B.Put(env, 0, 5, Item("potion"))
	env.RunTimers()
	assert(#pins.order == 1 and pins.order[1].id == 5, "the copy follows the item to its new slot")
	env._locked["0:5"] = true
	env.FireEvent("ITEM_LOCK_CHANGED", 0, 5)
	assert(pins.order[1].state.locked and slot(ns, 0, 5).state.locked, "a picked-up item greys in both places")
	env._locked["0:5"] = nil
	env.FireEvent("ITEM_LOCK_CHANGED", 0, 5)
	write(env, K, "iconZoom", 12)
	assert(select(1, pins.order[1].icon:GetTexCoord()) == 0.12, "the copy follows the slot style")
	write(env, K, "iconZoom", 7)
	write(env, K, "compactBags", false)
	assert(shown(pins.view) and slot(ns, 0, 5).icon:GetAlpha() == 1, "the steady grid shows Pinned above it, the item undimmed")
	write(env, K, "pinsDim", true)
	assert(slot(ns, 0, 5).icon:GetAlpha() < 1 and pins.order[1].icon:GetAlpha() == 1 and slot(ns, 0, 1).icon:GetAlpha() == 1, "Dim pinned dims only the original")
	win:SetQuery("potion")
	assert(slot(ns, 0, 5).icon:GetAlpha() < 1 and pins.order[1].icon:GetAlpha() == 1, "a search keeps it dimmed")
	win:SetQuery("")
	write(env, K, "pinsInGrid", false)
	assert(#pins.order == 0 and not shown(pins.view) and slot(ns, 0, 5).icon:GetAlpha() == 1, "Pinned in grids off hides it and undims")
	write(env, K, "pinsInGrid", true)
	write(env, K, "pinsPerCharacter", false)
	assert(#pins.order == 0, "the shared pins start empty")
	altClick(env, slot(ns, 0, 1))
	write(env, K, "pinsPerCharacter", true)
	assert(#pins.order == 1 and pins.order[1].id == 5, "each character keeps its own pins")
	altClick(env, slot(ns, 0, 5))
	assert(#pins.order == 0, "Alt-click again unpins")
	env.HoldItem(Item("cloth"))
	altClick(env, slot(ns, 0, 3))
	env.HoldItem(nil)
	assert(#pins.order == 0, "no pin while an item is on the cursor")
	env.SetCombat(true)
	altClick(env, slot(ns, 0, 3))
	assert(#pins.order == 0, "a copy made in combat waits")
	env.SetCombat(false)
	env.RunTimers()
	assert(#pins.order == 1 and shown(pins.order[1].button), "and appears when combat ends")
	write(env, K, "pins", false)
	assert(#pins.order == 0 and not shown(pins.view) and slot(ns, 0, 5).icon:GetAlpha() == 1, "off hides Pinned")
	clean(env, K)
end

-- Opens to: one grid or bag by bag each time the window opens; the option applies at once.
do
	local env, K, ns, win = new({ enabled = true, compactBags = true, openTo = "bags" }, { bags = { [0] = { size = 4, items = { Item("sword") } }, [1] = { size = 2, items = { Item("potion") } } } })
	local groups = win.sections[1].groups
	assert(win.view == "bags" and groups.bag0.total == 4 and groups.bag1.total == 2, "bag by bag shows every slot of each bag")
	assert(groups.bag0.cap.label:GetText():lower():find("backpack", 1, true) and groups.bag0.rank < groups.bag1.rank, "named and in bag order")
	assert(not groups.equipment or groups.equipment.total == 0, "no item sections")
	write(env, K, "openTo", "grid")
	assert(not shown(groups.bag0.view) and shown(win.sections[1].view) and #win.sections[1].order == 6, "one grid at once")
	ns.Inventory.Close()
	env.RunTimers()
	write(env, K, "openTo", "all")
	ns.Inventory.Open()
	env.RunTimers()
	assert(win.view == "all" and groups.equipment.total == 1 and shown(groups.equipment.view), "all items restores the sections")
	clean(env, K)
end

-- The category list: entries, filtering, empty categories, the add entry, folding and hiding.
do
	local env, K, _, win = new({ enabled = true, compactBags = true, sidebar = true }, { bags = { [0] = { size = 6, items = { Item("sword"), Item("potion"), Item("cloth") } }, [-1] = { size = 2, items = { Item("key") } } } })
	local opened = {}
	K.Options.Open = function(page) opened[#opened + 1] = page return true end
	local list, groups, panel = win.list, win.sections[1].groups, win.panel
	assert(shown(list.frame) and entry(win, K.L["All items"]).item.selected and entry(win, K.L["Consumables"]).item.count == 1, "the list shows the views and each section with its count")
	local last = list.entries[#list.entries]
	assert(list.frame:GetLeft() >= panel:GetLeft() and list.frame:GetRight() < win.search:GetLeft() and last:GetBottom() > panel:GetBottom(), "the list sits in the window's left column, clear of the content")
	assert(not entry(win, K.L["Quest"]), "empty categories stay off the list")
	click(env, entry(win, K.L["Consumables"]))
	assert(win.only == "consumables" and shown(groups.consumables.view) and not shown(groups.equipment.view), "a click shows only that section")
	assert(entry(win, K.L["Consumables"]).item.selected, "and marks it")
	click(env, entry(win, K.L["Consumables"]))
	assert(win.only == nil and shown(groups.equipment.view), "a second click shows everything")
	click(env, entry(win, K.L["Keyring"]))
	assert(win.only == "section2" and shown(win.sections[2].view) and not win.viewport:IsShown(), "a plain section shows alone, with no empty band of sections")
	click(env, entry(win, K.L["Keyring"]))
	click(env, entry(win, K.L["One grid"]))
	assert(win.view == "grid" and shown(win.sections[1].view) and not shown(groups.equipment.view), "views switch")
	click(env, entry(win, K.L["All items"]))
	click(env, entry(win, K.L["Trade goods"]))
	B.Put(env, 0, 3, nil)
	env.RunTimers()
	assert(win.only == nil and shown(groups.equipment.view), "a section that empties falls back to everything")
	write(env, K, "sidebarEmpty", true)
	assert(entry(win, K.L["Quest"]) and entry(win, K.L["Quest"]).item.count == 0, "Empty categories lists them")
	click(env, entry(win, K.L["Add category"]))
	assert(opened[1] == "Bags", "the add entry opens the bag settings")
	write(env, K, "sidebarAdd", false)
	assert(not entry(win, K.L["Add category"]), "and can be removed")
	local wide, panelWide = list.frame:GetWidth(), panel:GetWidth()
	click(env, list.fold)
	assert(list.frame:GetWidth() < wide and not shown(list.entries[1].label) and shown(list.entries[1].mark), "folding leaves the marks")
	assert(W.Near(panelWide - panel:GetWidth(), wide - list.frame:GetWidth()), "and narrows the window by as much")
	write(env, K, "sidebarHide", true)
	assert(not shown(list.frame) and shown(list.expand), "a hidden folded list leaves the arrow by the title")
	assert(W.Near(win.search:GetLeft() - panel:GetLeft(), K.Widgets.WindowInset(panel)), "and gives the content its place back")
	local close = panel.closeButton
	assert(list.expand:GetRight() <= close:GetLeft(), "the arrow keeps clear of the close button")
	click(env, list.expand)
	assert(shown(list.frame) and not shown(list.expand) and shown(list.entries[1].label), "the arrow unfolds the list")
	write(env, K, "sidebar", false)
	assert(not shown(list.frame) and not shown(list.expand), "off removes the list")
	assert(W.Near(win.search:GetLeft() - panel:GetLeft(), K.Widgets.WindowInset(panel)), "and the content returns to the edge")
	clean(env, K)
end

-- The bank's list shows its tabs; a tab shows alone; Bank tabs in the list off drops them.
do
	local env, K, ns = new({ enabled = true, sidebar = true }, { bank = { [6] = { size = 4, items = { Item("helm") } }, [7] = { size = 3, items = { Item("potion") } } } })
	env.SetBank(true)
	env.RunTimers()
	local bank = ns.Bank.window
	assert(entry(bank, K.L["All tabs"]) and entry(bank, "Tab 2") and not entry(bank, K.L["One grid"]), "the bank lists its tabs, not the bag views")
	click(env, entry(bank, "Tab 2"))
	assert(#bank.sections[1].order == 3 and bank.sections[1].order[1].bag == 7, "a tab shows alone")
	click(env, entry(bank, K.L["All tabs"]))
	assert(#bank.sections[1].order == 7, "All tabs shows them all")
	click(env, entry(bank, "Tab 1"))
	write(env, K, "sidebarTabs", false)
	assert(not entry(bank, "Tab 1"), "off drops the tabs")
	env.SetBank(false)
	env.SetBank(true)
	env.RunTimers()
	assert(bank.onlyBag == nil and #bank.sections[1].order == 7, "a new visit shows every tab")
	clean(env, K)
end

-- The preview: Sort to bottom shows the empty sample first.
do
	local env, K = new({ enabled = true }, {})
	local preview = K.Options.Preview("Bags")(env.CreateFrame("Frame", nil, K.Scale.Root()))
	assert(preview.slots[1].icon:GetTexture() == 134829)
	write(env, K, "sortBottom", true)
	preview:Refresh()
	assert(preview.slots[1].icon:GetTexture() == nil and preview.slots[2].icon:GetTexture() == 134829, "the empty sample comes first")
	write(env, K, "sortBottom", false)
	preview:Refresh()
	assert(preview.slots[1].icon:GetTexture() == 134829, "off restores the samples")
	clean(env, K)
end

print("bags parity 2 ok: shrink, sort to bottom, currencies, pins, views, the category list and the preview")
