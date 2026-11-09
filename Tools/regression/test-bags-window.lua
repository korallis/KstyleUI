-- test-bags-window.lua: the bag window builds Blizzard's item-button template per slot, shows counts, item levels, quality, junk and new items, searches, sorts and follows its settings.
local B = dofile("Tools/regression/bags_env.lua")
local W = B.W
local Item, Q = B.Item, B.QUALITY

local function Bags()
	return {
		[0] = { size = 16, items = { [1] = Item("potion"), [2] = Item("sword"), [3] = Item("helm"), [4] = Item("junk"), [5] = Item("hearth") } },
		[1] = { size = 8, items = { [1] = Item("cloth"), [8] = Item("ring") } },
		[-1] = { size = 4, items = { [1] = Item("key") } },
	}
end

local function Open(env)
	env.ToggleAllBags()
	env.RunTimers()
	W.Settle(env)
end

local function Set(K, key, value)
	assert(K.Options.Write("Bags", key, value) ~= false, "writing " .. key)
end

-- Registration and settings ----------------------------------------------------------------------

do
	local env, K, ns = B.New({ bags = Bags(), enable = false })
	local listed = false
	for _, name in ipairs(K.Modules.List()) do
		listed = listed or name == "Bags"
	end
	assert(listed, "Bags registers with Modules")
	assert(K.Modules.IsEnabled("Bags") == false, "the module is off by default")
	assert(ns.Inventory and ns.Inventory.window == nil, "nothing is built while the module is off")
	local keys = {}
	for _, row in ipairs(K.Options.Get("Bags")) do
		if row.key then
			keys[row.key] = row.type
		end
	end
	for key, kind in pairs({
		enabled = "toggle", columns = "slider", slotSize = "slider", spacing = "slider", rows = "slider", growth = "dropdown",
		showCount = "toggle", showItemLevel = "toggle", showQuality = "toggle", qualityMin = "dropdown", showNewGlow = "toggle",
		showJunk = "toggle", showKeyring = "toggle", font = "font", fontSize = "slider", fontOutline = "dropdown",
		accentSource = "dropdown", accentColor = "color", sortDirection = "dropdown",
	}) do
		assert(keys[key] == kind, "the settings page has a " .. kind .. " for " .. key .. ", got " .. tostring(keys[key]))
	end
	assert(type(K.Options.Preview("Bags")) == "function", "the module gives the settings window a preview builder")
	local frames = #env._frames
	local preview = K.Options.Preview("Bags")(K.Scale.Root())
	assert(type(preview.Refresh) == "function", "the preview can refresh")
	for i = frames + 1, #env._frames do
		assert(env._frames[i]._template ~= "ContainerFrameItemButtonTemplate", "the preview never makes Blizzard's item buttons")
	end
	preview:Refresh()
end

-- Item buttons ------------------------------------------------------------------------------------

do
	local _, K, ns = B.New({ bags = Bags() })
	local Inventory = ns.Inventory
	local win = assert(Inventory.window, "Enable builds the bag window")
	assert(not win.panel:IsShown(), "the window starts closed")
	local slot = assert(Inventory.Slot(0, 3), "a slot for backpack slot 3")
	local button = slot.button
	assert(button:GetObjectType() == "ItemButton" and button._template == "ContainerFrameItemButtonTemplate", "slots are Blizzard's container item buttons")
	assert(button:GetID() == 3 and button:GetParent():GetID() == 0, "the button's ID is the slot and its parent's ID is the bag")
	assert(Inventory.Slot(1, 8).button:GetParent():GetID() == 1, "bag 1 slots sit in bag 1's frame")
	assert(Inventory.Slot(0, 17) == nil, "no slot past the bag's size")
	assert(rawget(button, "bagID") == nil, "the module never writes bagID onto Blizzard's button")
	assert(not button.BattlepayItemTexture:IsShown(), "the template's store highlight, shown by default, is hidden")
	for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
		assert(button[getter](button):GetAlpha() == 0, "the template's " .. getter:sub(4) .. " is silenced")
	end
	local entry = K.Layout.Get("bags.inventory")
	assert(entry and entry.anchor == "BOTTOMRIGHT", "the window registers with Layout as bags.inventory, bottom right")
	local found
	for _, element in ipairs(K.Layout.Elements()) do
		if element.key == "bags.inventory" then
			found = element
		end
	end
	assert(found and found.opts.scalable == true and found.module == "Bags", "the window is scalable and owned by Bags")
end

-- Contents ----------------------------------------------------------------------------------------

do
	local env, K, ns = B.New({ bags = Bags() })
	local Inventory = ns.Inventory
	Open(env)
	local win = Inventory.window
	assert(win.panel:IsShown(), "ToggleAllBags opens the window")
	local potion, sword, helm, junk = Inventory.Slot(0, 1), Inventory.Slot(0, 2), Inventory.Slot(0, 3), Inventory.Slot(0, 4)
	assert(potion.count:GetText() == "5" and potion.count:IsShown(), "a stack shows its count")
	assert(not sword.count:IsShown(), "a single item shows no count")
	assert(sword.level:GetText() == "12" and sword.level:IsShown(), "a weapon shows its item level")
	assert(not potion.level:IsShown(), "a potion shows no item level")
	assert(W.Calls(potion.icon, "SetTexture")[1][1] == 134829, "the icon is the item's")
	local er, eg, eb = K.Theme.QualityColor(Q.Epic)
	assert(W.SameRGB(helm.chrome.rim[1], er, eg, eb), "an epic item's hairline takes the epic colour")
	local rr, rg, rb = K.Widgets.IconRim(ns.Settings.Accent())
	assert(W.SameRGB(potion.chrome.rim[1], rr, rg, rb), "a common item rests on the accent rim, lifted 15% toward white, as an action button")
	assert(potion.chrome.outer == nil, "the socket's rim is its one line, with no halo line outside it")
	assert(W.SameColor(potion.chrome.fill[5], K.Tokens.Color("buttonFill")), "on the near-black button body, not a raised tile")
	assert(junk.junk:IsShown() and not potion.junk:IsShown(), "junk shows its marker")
	local empty = Inventory.Slot(0, 9)
	local ir, ig, ib = K.Tokens.Color("edgeInner")
	assert(W.SameRGB(empty.chrome.rim[1], ir, ig, ib), "an empty slot keeps the plain grey hairline")
	assert(W.SameColor(empty.chrome.fill[5], K.Widgets.Rgba("buttonFill", 0.55)), "on a fainter near-black body")
	assert(not empty.count:IsShown() and not empty.level:IsShown() and not empty.junk:IsShown(), "an empty slot shows nothing")
	assert(Inventory.Slot(-1, 1) and Inventory.Slot(-1, 1).button:GetParent():GetID() == -1, "the keyring has its own slots")
	assert(win.free:GetText():find("17/24", 1, true), "the footer counts free bag slots, without the keyring: " .. tostring(win.free:GetText()))
	assert(win.money:GetText() == "money:1234567", "the footer shows the player's money")
	env._money = 99
	env.FireEvent("PLAYER_MONEY")
	assert(win.money:GetText() == "money:99", "money follows PLAYER_MONEY")
	local moneyString = env.GetMoneyString
	env.GetMoneyString = nil
	env._money = 1234567
	env.FireEvent("PLAYER_MONEY")
	assert(win.money:GetText() == "123g 45s 67c", "without GetMoneyString the footer formats gold, silver and copper itself, as the data strip does: " .. tostring(win.money:GetText()))
	env._money = 4567
	env.FireEvent("PLAYER_MONEY")
	assert(win.money:GetText() == "45s 67c", "no gold shows no gold")
	env._money = 7
	env.FireEvent("PLAYER_MONEY")
	assert(win.money:GetText() == "7c", "copper alone")
	env.GetMoneyString = moneyString

	B.Put(env, 0, 9, Item("ring"))
	assert(Inventory.Slot(0, 9).level:GetText() == "30", "a bag update refreshes the slot")
	assert(win.free:GetText():find("16/24", 1, true), "and the free count")

	env._locked["0:1"] = true
	env.FireEvent("ITEM_LOCK_CHANGED", 0, 1)
	assert(W.LastCall(potion.icon, "SetDesaturated")[1] == true, "a locked item greys out")
	env._locked["0:1"] = nil
	env.FireEvent("ITEM_LOCK_CHANGED", 0, 1)
	assert(W.LastCall(potion.icon, "SetDesaturated")[1] == false, "and returns when unlocked")
end

-- New items ---------------------------------------------------------------------------------------

do
	local env, K, ns = B.New({ bags = Bags() })
	env._new["0:2"] = true
	Open(env)
	local sword = ns.Inventory.Slot(0, 2)
	assert(sword.glow and sword.glow:IsPlaying(), "a new item glows")
	assert(not ns.Inventory.Slot(0, 1).glow or not ns.Inventory.Slot(0, 1).glow:IsPlaying(), "an old item does not")
	W.Enter(sword.button)
	assert(not sword.glow:IsPlaying(), "hovering a new item stops its glow")
	env._new["0:3"] = true
	env.FireEvent("BAG_NEW_ITEMS_UPDATED")
	assert(ns.Inventory.Slot(0, 3).glow:IsPlaying(), "BAG_NEW_ITEMS_UPDATED lights new items")
	Set(K, "showNewGlow", false)
	assert(not ns.Inventory.Slot(0, 3).glow:IsPlaying(), "the glow follows its setting")
	Set(K, "showNewGlow", true)
	ns.Inventory.window.panel:Close()
	W.Settle(env)
	assert(env._new["0:3"] == nil, "closing the window clears the new marks, as Blizzard's bags do")
end

-- Settings change the window ---------------------------------------------------------------------

do
	local env, K, ns = B.New({ bags = Bags() })
	-- The grid geometry below (slot positions, growth, the row limit and the wheel) is the one-grid layout's.
	Set(K, "layout", "grid")
	Open(env)
	local Inventory = ns.Inventory
	local panel = Inventory.window.panel
	local wide = panel:GetWidth()
	Set(K, "columns", 6)
	assert(panel:GetWidth() < wide, "fewer columns make a narrower window")
	local narrow = panel:GetWidth()
	Set(K, "slotSize", 40)
	assert(panel:GetWidth() > narrow, "bigger slots make a wider window")
	assert(Inventory.Slot(0, 1).button:GetWidth() == 40, "slots take the slot size")
	Set(K, "spacing", 0)
	local _, _, _, x2 = Inventory.Slot(0, 2).button:GetPoint(1)
	assert(x2 == 40, "the second slot sits one slot over with no gap")
	Set(K, "growth", "LEFT_DOWN")
	local _, _, _, x1 = Inventory.Slot(0, 1).button:GetPoint(1)
	assert(x1 == 5 * 40, "growing left puts the first slot in the last column")
	Set(K, "showItemLevel", false)
	assert(not Inventory.Slot(0, 2).level:IsShown(), "item levels hide with their setting")
	Set(K, "showCount", false)
	assert(not Inventory.Slot(0, 1).count:IsShown(), "counts hide with their setting")
	Set(K, "showJunk", false)
	assert(not Inventory.Slot(0, 4).junk:IsShown(), "the junk marker hides with its setting")
	Set(K, "showQuality", false)
	local ir, ig, ib = K.Widgets.IconRim(ns.Settings.Accent())
	assert(W.SameRGB(Inventory.Slot(0, 3).chrome.rim[1], ir, ig, ib), "quality hairlines hide with their setting: the accent rim comes back")
	Set(K, "showQuality", true)
	Set(K, "qualityMin", Q.Epic)
	assert(W.SameRGB(Inventory.Slot(1, 8).chrome.rim[1], ir, ig, ib), "a rare item is plain when only epic and better are coloured")
	Set(K, "fontSize", 14)
	Set(K, "fontOutline", "OUTLINE")
	local font = W.LastCall(Inventory.Slot(0, 2).level, "SetFont")
	assert(font[2] == 14 and font[3] == "OUTLINE", "slot text takes the font size and outline")
	Set(K, "showKeyring", false)
	assert(not Inventory.Slot(-1, 1).button:IsVisible(), "the keyring hides with its setting")
	Set(K, "showKeyring", true)
	assert(Inventory.Slot(-1, 1).button:IsVisible(), "and shows again")
	local tall = panel:GetHeight()
	Set(K, "rows", 1)
	assert(panel:GetHeight() < tall, "a row limit makes the window shorter")
	assert(not Inventory.Slot(0, 16).button:IsShown(), "slots past the row limit hide until scrolled to")
	local view = Inventory.window.sections[1].view
	view:GetScript("OnMouseWheel")(view, -1)
	assert(Inventory.Slot(0, 7).button:IsShown() and not Inventory.Slot(0, 1).button:IsShown(), "the wheel scrolls one row")
	Set(K, "accentSource", "custom")
	Set(K, "accentColor", { r = 0.2, g = 0.4, b = 0.6 })
	assert(Inventory.window.panel.divider == nil, "no line under the window title, as the kit's panel")
	local hovered = Inventory.Slot(0, 1)
	hovered.hoverT = 1
	ns.Slot.Paint(hovered)
	assert(W.SameRGB(hovered.chrome.rim[1], 0.2, 0.4, 0.6), "a hovered slot's edge follows a custom accent")
end

-- Categories: the default layout sorts items into Lumen sections --------------------------------------------

do
	local env, K, ns = B.New({ bags = Bags() })
	local Inventory = ns.Inventory
	assert(ns.Settings.Get("layout") == "categories", "items sort into categories by default")
	local row = K.Options.Row("Bags", "layout")
	assert(row and row.type == "dropdown", "the layout has a dropdown")
	Open(env)
	local win = Inventory.window
	local section = win.sections[1]
	local groups = section.groups
	assert(type(groups) == "table", "the bags section holds category groups")
	local function Has(group, bag, slot)
		for _, s in ipairs(group.order) do
			if s.bag == bag and s.id == slot then
				return true
			end
		end
		return false
	end
	local equipment, consumables, trade, quest, other, junk, empty = groups.equipment, groups.consumables, groups.tradeGoods, groups.quest, groups.other, groups.junk, groups.empty
	assert(#equipment.order == 3 and Has(equipment, 0, 2) and Has(equipment, 0, 3) and Has(equipment, 1, 8), "the sword, helm and ring are equipment")
	assert(#consumables.order == 1 and Has(consumables, 0, 1), "the potion is a consumable")
	assert(#trade.order == 1 and Has(trade, 1, 1), "the cloth is trade goods")
	assert(#other.order == 1 and Has(other, 0, 5), "the hearthstone is other")
	assert(#junk.order == 1 and Has(junk, 0, 4), "the fang is junk")
	assert(#empty.order == 1 and empty.total == 24 - 7, "the empty group lists one slot per bag family and counts every free slot, got " .. tostring(#empty.order) .. "/" .. tostring(empty.total))
	assert(not Has(empty, -1, 2) and #win.sections[2].order == 4, "the keyring keeps its own section")
	assert(quest == nil, "a category nothing has fallen into is never built")
	assert(equipment.view:IsShown() and equipment.cap:IsShown(), "a category with items shows its grid and its cap")
	assert(not section.view:IsShown(), "the one big grid hides while categories show")
	assert(equipment.cap.label:GetText():upper() == equipment.cap.label:GetText() and equipment.cap.label:GetText():find("EQUIPMENT", 1, true), "the cap carries the category's name, as a tracked caption, got " .. tostring(equipment.cap.label:GetText()))
	assert(equipment.cap.count:GetText() == "3", "and the count of items in it")
	assert(equipment.cap.gem and equipment.cap.rule, "the cap is the Lumen section cap: gem and rule")
	-- Sections stack in the categories' order down the window.
	local function Top(group)
		local point = group.cap._points[1]
		return -point[5]
	end
	assert(Top(equipment) < Top(consumables) and Top(consumables) < Top(trade) and Top(trade) < Top(other) and Top(other) < Top(junk) and Top(junk) < Top(empty), "equipment, consumables, trade goods, other, junk, then the empty slots")
	-- Blizzard's item button still reads its bag from its parent: the parent frame under a group's grid carries the bag's ID.
	local sword = Inventory.Slot(0, 2)
	assert(sword.button:GetParent():GetID() == 0 and sword.button:GetParent():GetParent() == equipment.grid, "a sorted slot's parent carries its bag ID under its category's grid")
	local ring = Inventory.Slot(1, 8)
	assert(ring.button:GetParent():GetID() == 1 and ring.button:GetParent():GetParent() == equipment.grid, "a slot from another bag sits in the same category under a frame with its own bag ID")
	-- A row limit bounds the sections' viewport; it never hides a sorted slot.
	Set(K, "rows", 1)
	for _, slot in ipairs(equipment.order) do
		assert(slot.button:IsShown(), "a row limit never hides a sorted slot")
	end
	assert(win.viewport:IsShown() and win.viewport:GetHeight() < win.stack:GetHeight(), "the sections scroll in their viewport instead")
	Set(K, "rows", 0)
	-- Items that change category move with the next refresh.
	B.Put(env, 0, 1, nil)
	env.RunTimers()
	assert(#consumables.order == 0 and not consumables.view:IsShown(), "an emptied slot leaves its category")
	assert(Has(empty, 0, 1) and Inventory.Slot(0, 1).button:GetParent():GetParent() == empty.grid, "and joins the empty group")
	-- Back to one grid.
	Set(K, "layout", "grid")
	assert(section.view:IsShown() and not equipment.view:IsShown() and not equipment.cap:IsShown(), "the grid layout shows the one grid and hides the categories")
	assert(sword.button:GetParent():GetParent() == section.grid and sword.button:GetParent():GetID() == 0, "slots return to the grid's bag frames")
	assert(#section.order == 24, "the grid holds every bag slot")
	Set(K, "layout", "categories")
	assert(not section.view:IsShown() and equipment.view:IsShown(), "and categories come back")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The window never outgrows the screen: categories share one scrolling viewport -----------------------

do
	local names = { "potion", "sword", "cloth", "junk", "hearth", "ring", "key" }
	local bags = {}
	for bag = 0, 4 do
		bags[bag] = { size = 20, items = {} }
		for i = 1, 20 do
			bags[bag].items[i] = Item(names[(i + bag) % #names + 1])
		end
	end
	bags[-1] = { size = 32, items = {} }
	local env, K, ns = B.New({ bags = bags, height = 1080 })
	Open(env)
	local win = ns.Inventory.window
	local panel, root = win.panel, K.Scale.Root()
	local function Fits(label)
		local height, screen = panel:GetHeight(), root:GetHeight()
		assert(height <= screen, label .. ": the window is " .. tostring(height) .. " tall on a " .. tostring(screen) .. " screen")
		local footerBottom = -win.money._points[1][5]
		assert(footerBottom < height, label .. ": the footer sits inside the window")
	end
	Set(K, "rows", 2)
	for _, columns in ipairs({ 10, 6, 4 }) do
		Set(K, "columns", columns)
		Fits("categories, " .. columns .. " columns, 2 rows")
	end
	Set(K, "rows", 0)
	Fits("categories, 4 columns, every row")
	local viewport = win.viewport
	assert(viewport and viewport:IsShown() and viewport:GetHeight() < win.stack:GetHeight(), "the sections stack inside a viewport shorter than the stack")
	assert(W.LastCall(viewport, "SetClipsChildren")[1] == true, "the viewport clips")
	local before = win.stack._points[1][5]
	viewport:GetScript("OnMouseWheel")(viewport, -1)
	assert(win.stack._points[1][5] > before, "the wheel scrolls the stack up")
	for _ = 1, 200 do
		viewport:GetScript("OnMouseWheel")(viewport, -1)
	end
	local maxOffset = win.stack:GetHeight() - viewport:GetHeight()
	assert(math.abs(win.stack._points[1][5] - maxOffset) < 1, "the scroll stops at the end of the stack")
	for _ = 1, 400 do
		viewport:GetScript("OnMouseWheel")(viewport, 1)
	end
	assert(win.stack._points[1][5] == 0, "and at the top")
	assert(win.search:IsShown() and win.search:GetParent() ~= win.stack and win.money:GetParent() ~= win.stack, "search and footer stay outside the viewport")
	Set(K, "layout", "grid")
	Fits("grid, 4 columns, every row")
	Set(K, "layout", "categories")
	-- A keyring under the sections shares the budget with them, at a large slot size and a doubled window scale.
	for i = 1, 32 do
		B.Put(env, -1, i, Item("key"))
	end
	Set(K, "slotSize", 48)
	Set(K, "spacing", 12)
	K.Layout.Update("bags.inventory", { scale = 2 })
	env.RunTimers()
	W.Settle(env)
	local screenUnits = win:ScreenHeight()
	assert(panel:GetHeight() <= screenUnits, "categories with a 32-key keyring at scale 2: the window is " .. tostring(panel:GetHeight()) .. " tall on a " .. tostring(screenUnits) .. " unit screen")
	assert(win.sections[2].visibleRows >= 1 and win.sections[2].view:IsShown(), "the keyring keeps at least one row")
	Set(K, "layout", "grid")
	assert(panel:GetHeight() <= win:ScreenHeight(), "grid with the keyring at scale 2 fits too")
	assert(win.sections[2].visibleRows >= 2, "the keyring is not starved of rows the grid did not need, got " .. tostring(win.sections[2].visibleRows))
	Set(K, "layout", "categories")
	K.Layout.Update("bags.inventory", { scale = 1 })
	Set(K, "slotSize", 34)
	Set(K, "spacing", 4)
	env.RunTimers()
	W.Settle(env)
	Set(K, "rows", 2)
	local step = ns.Settings.Get("slotSize") + ns.Settings.Get("spacing")
	assert(viewport:GetHeight() <= 2 * step + 40, "Rows shown bounds the viewport in the category layout, got " .. tostring(viewport:GetHeight()))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Empty slots pack into one stacked tile per bag family, the tile and the cap carry the free count --------

do
	local env, K, ns = B.New({ bags = Bags() })
	Open(env)
	local win = ns.Inventory.window
	local empty = win.sections[1].groups.empty
	assert(#empty.order == 1, "the regular bags' free slots show as one tile, got " .. tostring(#empty.order))
	assert(empty.cap.count:GetText() == "17", "the cap counts every free slot, got " .. tostring(empty.cap.count:GetText()))
	local tile = empty.order[1]
	assert(tile.count:IsShown() and tile.count:GetText() == "17", "the tile wears the free count as a stack, got " .. tostring(tile.count:GetText()))
	assert(tile.state.empty, "and stays an empty slot to drop onto")
	local shown = 0
	for bag = 0, 1 do
		for slot = 1, 16 do
			local s = ns.Inventory.Slot(bag, slot)
			if s and s.state.empty and s.button:IsShown() then
				shown = shown + 1
			end
		end
	end
	assert(shown == 1, "the other empty slots' buttons hide, got " .. shown .. " shown")
	-- A special bag (a quiver, a soul bag) takes only its own kind, so its free slots are a tile of their own.
	env._bags[1].family = 1
	env.FireEvent("BAG_UPDATE", 1)
	env.FireEvent("BAG_UPDATE_DELAYED")
	env.RunTimers()
	W.Settle(env)
	assert(#empty.order == 2, "a bag of another family gets its own tile, got " .. tostring(#empty.order))
	local counts = {}
	for _, slot in ipairs(empty.order) do
		counts[#counts + 1] = slot.count:GetText()
	end
	table.sort(counts)
	assert(counts[1] == "11" and counts[2] == "6", "each tile counts its family's free slots, got " .. table.concat(counts, ","))
	env._bags[1].family = nil
	env.FireEvent("BAG_UPDATE_DELAYED")
	env.RunTimers()
	W.Settle(env)
	assert(#empty.order == 1)
	local row = K.Options.Row("Bags", "emptySlots")
	assert(row and row.type == "dropdown", "Empty slots has a dropdown")
	Set(K, "emptySlots", "all")
	assert(#empty.order == 17, "showing every empty slot lists them all")
	assert(not empty.order[1].count:IsShown(), "and each one is plain")
	Set(K, "emptySlots", "packed")
	assert(#empty.order == 1, "and packing them again")
	Set(K, "layout", "grid")
	assert(#win.sections[1].order == 24, "the grid layout shows every slot whatever the packing")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The window hugs its content: as wide as its widest row, never the column setting's full width ----------

do
	local env, K, ns = B.New({ bags = Bags() })
	Open(env)
	local win = ns.Inventory.window
	local panel = win.panel
	local Data = ns.Data
	local size, spacing = ns.Settings.Get("slotSize"), ns.Settings.Get("spacing")
	local pad = K.Widgets.WindowInset(panel)
	local full = Data.Size(ns.Settings.Get("columns"), 1, size, spacing) + 2 * pad
	assert(panel:GetWidth() < full, "with rows of three items at most, the window is narrower than ten columns: " .. panel:GetWidth() .. " vs " .. full)
	local hugged = panel:GetWidth()
	assert(win.search:GetWidth() >= 100, "and the search field keeps room to type: " .. tostring(win.search:GetWidth()))
	-- Seven cloth stacks make a seven-wide trade goods row; the window grows to fit it and no further.
	for slot = 2, 7 do
		B.Put(env, 1, slot, Item("cloth", { count = slot }))
	end
	env.RunTimers()
	W.Settle(env)
	local seven = Data.Size(7, 1, size, spacing) + 2 * pad
	assert(panel:GetWidth() == seven, "a seven-wide row widens the window to seven columns: " .. panel:GetWidth() .. " vs " .. seven)
	assert(panel:GetWidth() > hugged)
	assert(#win.sections[1].groups.tradeGoods.order == 7 and win.sections[1].groups.tradeGoods.cols == 7, "the row is seven wide")
	-- The column setting still caps a row: at six columns the seven stacks wrap and the window narrows with them,
	-- down to the width its search box and buttons need.
	Set(K, "columns", 6)
	local six = Data.Size(6, 1, size, spacing) + 2 * pad
	assert(panel:GetWidth() == math.max(six, hugged), "six columns wrap the row and the window hugs again: " .. panel:GetWidth() .. " vs " .. six .. " or " .. hugged)
	assert(win.sections[1].groups.tradeGoods.cols == 6)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The window hugs a five-wide row too: the header stacks rather than holding the window open ---------------

do
	local env, K, ns = B.New({ bags = Bags(), merchant = true })
	Open(env)
	local win = ns.Inventory.window
	local panel = win.panel
	local Data = ns.Data
	local size, spacing = ns.Settings.Get("slotSize"), ns.Settings.Get("spacing")
	local pad = K.Widgets.WindowInset(panel)
	local gap = K.Widgets.Snap(panel, K.Tokens.Size("gapMedium"))
	-- The header's frames hang from the content frame's top-left corner, so their anchor offsets place them.
	local function Offset(frame)
		local point = frame._points[1]
		assert(point and point[2] == panel.content, "anchored on the content frame")
		return point[4], -point[5]
	end
	-- At a merchant, with junk to sell, Sell junk joins Sort in the header. Five cloth stacks make the widest row
	-- five slots: narrower than the search box, Sort and Sell junk side by side.
	env.SetMerchant(true)
	for slot = 2, 5 do
		B.Put(env, 1, slot, Item("cloth", { count = slot }))
	end
	env.RunTimers()
	W.Settle(env)
	assert(win.junkButton:IsShown(), "Sell junk shows at the merchant")
	assert(win.sections[1].groups.tradeGoods.cols == 5, "the row is five wide")
	local five = Data.Size(5, 1, size, spacing)
	local shown = {}
	for _, button in ipairs(win.buttons) do
		if button:IsShown() then
			shown[#shown + 1] = button
		end
	end
	assert(#shown >= 1, "a header button beside Sort is shown")
	local need = 100 + gap + win.sortButton:GetWidth()
	for _, button in ipairs(shown) do
		need = need + gap + button:GetWidth()
	end
	assert(need > five, "the test case: the header's controls side by side need more than the five-wide row: " .. need .. " vs " .. five)
	assert(math.abs(panel:GetWidth() - (five + 2 * pad)) < 0.01, "the window hugs the five-wide row: " .. panel:GetWidth() .. " vs " .. five + 2 * pad)
	-- The header makes room by stacking: the search box takes the row's width, the buttons sit on their own row
	-- under it, right-aligned, and the sections start below both.
	assert(math.abs(win.search:GetWidth() - five) < 0.01, "the search box spans the row: " .. win.search:GetWidth() .. " vs " .. five)
	local _, searchTop = Offset(win.search)
	local sortRight, sortTop = Offset(win.sortButton)
	assert(sortTop >= searchTop + win.search:GetHeight(), "the buttons sit under the search box: " .. sortTop .. " vs " .. searchTop .. " + " .. win.search:GetHeight())
	local previous = win.sortButton
	for _, button in ipairs(shown) do
		local point = button._points[1]
		assert(point[1] == "TOPRIGHT" and point[2] == previous and point[3] == "TOPLEFT" and point[4] < 0, "each button sits left of the one before, on the same row")
		previous = button
	end
	assert(math.abs(sortRight - five) < 0.01, "the buttons end at the row's right edge: " .. sortRight .. " vs " .. five)
	local _, sectionsTop = Offset(win.viewport)
	assert(sectionsTop >= sortTop + win.sortButton:GetHeight(), "the sections start under the button row: " .. sectionsTop .. " vs " .. sortTop)
	-- With a ten-wide row the controls fit beside each other again, on one row.
	for slot = 6, 8 do
		B.Put(env, 1, slot, Item("cloth", { count = slot }))
	end
	for slot = 6, 7 do
		B.Put(env, 0, slot, Item("cloth", { count = slot }))
	end
	env.RunTimers()
	W.Settle(env)
	assert(win.sections[1].groups.tradeGoods.cols >= 9, "the row is wide: " .. tostring(win.sections[1].groups.tradeGoods.cols))
	local _, searchTopWide = Offset(win.search)
	local _, sortTopWide = Offset(win.sortButton)
	assert(math.abs(sortTopWide - searchTopWide) < 0.01, "the buttons share the search box's row again")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Custom categories: a named rule gets its own section ahead of the built-in ones -----------------

do
	local env, K, ns = B.New({ bags = Bags() })
	Open(env)
	local win = ns.Inventory.window
	local groups = win.sections[1].groups
	assert(groups.custom1 == nil, "no custom section without a rule")
	Set(K, "custom1.name", "Travel")
	Set(K, "custom1.rule", "hearth | potion")
	local travel = groups.custom1
	assert(travel and #travel.order == 2 and travel.view:IsShown() and travel.cap:IsShown(), "the custom section holds the hearthstone and the potion")
	assert(travel.cap.label:GetText():find("TRAVEL", 1, true), "the cap carries the custom name, got " .. tostring(travel.cap.label:GetText()))
	assert(groups.consumables.view:IsShown() == false and groups.other.view:IsShown() == false, "the items left their built-in sections")
	local function Top(group)
		return -group.cap._points[1][5]
	end
	assert(Top(travel) < Top(groups.equipment), "the custom section sits above equipment")
	Set(K, "custom1.name", "Going home")
	assert(travel.cap.label:GetText():find("GOING HOME", 1, true), "renaming the category renames its cap")
	Set(K, "custom1.rule", "")
	assert(not travel.view:IsShown() and groups.consumables.view:IsShown(), "clearing the rule hides the section and returns its items")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Search ------------------------------------------------------------------------------------------

do
	local env, _, ns = B.New({ bags = Bags() })
	Open(env)
	local Inventory = ns.Inventory
	local search = Inventory.window.search
	search:SetText("heal")
	search:GetScript("OnTextChanged")(search, true)
	local potion, sword = Inventory.Slot(0, 1), Inventory.Slot(0, 2)
	assert(W.LastCall(potion.icon, "SetAlpha")[1] == 1, "a match stays bright")
	assert(W.LastCall(sword.icon, "SetAlpha")[1] < 1, "other items dim")
	search:SetText("armor | !potion")
	search:GetScript("OnTextChanged")(search, true)
	local helm, hearth = Inventory.Slot(0, 3), Inventory.Slot(0, 5)
	assert(W.LastCall(helm.icon, "SetAlpha")[1] == 1 and W.LastCall(hearth.icon, "SetAlpha")[1] == 1, "the window searches with the grammar")
	assert(W.LastCall(potion.icon, "SetAlpha")[1] < 1, "and dims what the expression excludes")
	search:SetText("")
	search:GetScript("OnTextChanged")(search, true)
	assert(W.LastCall(sword.icon, "SetAlpha")[1] == 1, "clearing the search brightens everything")
end

-- Sorting -----------------------------------------------------------------------------------------

do
	local env, K, ns = B.New({ bags = Bags() })
	Open(env)
	local sort = ns.Inventory.window.sortButton
	W.Click(sort)
	assert(B.Count(env, "SortBags") == 1, "Sort asks the game to sort the bags")
	assert(B.Calls(env, "SetSortBagsRightToLeft")[1][1] == false, "left to right by default")
	Set(K, "sortDirection", "RIGHT")
	env.SetCombat(true)
	W.Click(sort)
	assert(B.Count(env, "SortBags") == 1, "no sort in combat")
	env.SetCombat(false)
	assert(B.Count(env, "SortBags") == 2, "the sort runs when combat ends")
	local calls = B.Calls(env, "SetSortBagsRightToLeft")
	assert(calls[#calls][1] == true, "the sort direction follows its setting")
end

-- Combat ------------------------------------------------------------------------------------------

do
	local env, K, ns = B.New({ bags = Bags(), enable = false })
	env.SetCombat(true)
	K.Modules.Enable("Bags")
	env.RunTimers()
	env.SetCombat(false)
	env.RunTimers()
	assert(ns.Inventory.window, "turning the module on in combat waits for the end of combat")

	local env2, _, ns2 = B.New({ bags = Bags() })
	env2.SetCombat(true)
	local made = 0
	for _, frame in ipairs(env2._frames) do
		if frame._template == "ContainerFrameItemButtonTemplate" then
			made = made + 1
		end
	end
	B.Put(env2, 1, 1, nil)
	env2._bags[2] = { size = 4, items = { [1] = Item("potion") } }
	env2.FireEvent("BAG_CONTAINER_UPDATE")
	env2.ToggleAllBags()
	env2.RunTimers()
	local after = 0
	for _, frame in ipairs(env2._frames) do
		if frame._template == "ContainerFrameItemButtonTemplate" then
			after = after + 1
		end
	end
	assert(after == made, "no item button is made in combat, because one made in lockdown cannot use items")
	assert(ns2.Inventory.window.panel:IsShown(), "the window still opens in combat")
	env2.SetCombat(false)
	env2.RunTimers()
	assert(ns2.Inventory.Slot(2, 1), "the new bag's slots are made when combat ends")
end

print("bags window ok")
