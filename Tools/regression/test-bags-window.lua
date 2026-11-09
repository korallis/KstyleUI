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
