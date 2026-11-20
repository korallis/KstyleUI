-- test-bags-parity.lua: the bag parity options keep today's defaults, apply when switched on, restore when off and follow their events.
local B = dofile("Tools/regression/bags_env.lua")
local W, Item = B.W, B.Item

local function saved(settings)
	return { version = 42, profiles = { Default = { Bags = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function setup(env)
	env.INVTYPE_HEAD, env.INVTYPE_WEAPON, env.INVTYPE_FINGER = "Head", "One-Hand", "Finger"
	env.EXPANSION_NAME0, env.EXPANSION_NAME1 = "Classic", "Burning Crusade"
end

local function new(settings, opts)
	opts = opts or {}
	opts.saved = saved(settings)
	local inner = opts.setup
	opts.setup = function(env)
		setup(env)
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

local SWORD = Item("sword", { bind = 2, equipLoc = "INVTYPE_WEAPON" })
local HELM = Item("helm", { bind = 2, bound = true, equipLoc = "INVTYPE_HEAD", expansion = 1 })
local RING = Item("ring", { bound = true, equipLoc = "INVTYPE_FINGER" })

-- Defaults and a v0.2.8-shaped profile: nothing new is drawn and every new key reads its default.
do
	local env, K, ns, win = new({ enabled = true, columns = 7 }, { bags = { [0] = { size = 6, items = { SWORD, HELM, Item("cloth") } }, [5] = { size = 2, items = { Item("cloth", { reagent = true }) } } } })
	local S = ns.Settings
	for key, value in pairs({ maxHeight = 100, nearestCorner = false, goldTooltip = true, goldCoins = "copper", capSize = 11, listView = false, categorizeReagents = true, autoMerchant = "both", autoTrade = "none", warbandGoldAmount = "" }) do
		assert(S.Get(key) == value, key .. " keeps its default")
	end
	assert(K.Store.Module("Bags").columns == 7, "the old columns survive")
	local s1 = slot(ns, 0, 1)
	assert(not s1.bind and not s1.set and not s1.name and not s1.mark and not s1.list, "no new slot regions by default")
	assert(#win.sections[3].order == 0 and not win.currency and not win.bagStrip and not win.clearButton:IsShown(), "no reagent row, currency line, bag strip or clear button")
	assert(slot(ns, 5, 1).button:GetParent():GetParent() == win.sections[1].grid, "the reagent bag shares the grid")
	clean(env, K)
end

-- Slot labels, the reagent marker and the reagent row.
do
	local sets = { { name = "Tank", items = { 1002 } } }
	local env, K, ns, win = new({ enabled = true }, { sets = sets, bags = { [0] = { size = 6, items = { SWORD, HELM, RING, Item("potion") } }, [5] = { size = 2, items = { Item("cloth", { reagent = true }) } } } })
	local sword, helm, ring = slot(ns, 0, 1), slot(ns, 0, 2), slot(ns, 0, 3)
	write(env, K, "bindText", true)
	assert(shown(sword.bind) and sword.bind:GetText() == "BoE", "unbound BoE gear reads BoE")
	assert(not shown(helm.bind) and not slot(ns, 0, 4).bind, "bound gear and potions get no label")
	assert(select(1, sword.bind:GetPoint(1)) == "BOTTOMRIGHT" and select(1, sword.level:GetPoint(1)) == "TOPLEFT", "the label keeps clear of the item level")
	write(env, K, "labelSize", 13)
	assert(select(2, sword.bind:GetFont()) == 13, "label size applies")
	write(env, K, "setNames", true)
	assert(shown(ring.set) and ring.set:GetText() == "Tank" and select(1, ring.set:GetPoint(1)) == "BOTTOMLEFT", "set gear shows its set along the bottom")
	write(env, K, "separateFigures", false)
	assert(select(1, ring.set:GetPoint(1)) == "TOPLEFT" and select(1, ring.level:GetPoint(1)) == "BOTTOMLEFT", "with item levels at the bottom the set name moves to the top")
	sets[1].items = { 1001 }
	env.FireEvent("EQUIPMENT_SETS_CHANGED")
	env.RunTimers()
	assert(not shown(ring.set) and shown(helm.set), "a changed equipment set moves its name")
	win:SetQuery("potion")
	assert(helm.set:GetAlpha() < 1 and sword.bind:GetAlpha() < 1, "labels dim with their item")
	win:SetQuery("")
	write(env, K, "bindText", false)
	write(env, K, "setNames", false)
	assert(not shown(sword.bind) and not shown(helm.set), "turning labels off hides them")
	local reagent = slot(ns, 5, 1)
	write(env, K, "reagentMark", true)
	assert(shown(reagent.mark) and not slot(ns, 0, 4).mark, "the reagent bag's items wear the marker")
	write(env, K, "reagentMarkSize", 20)
	assert(W.Near(reagent.mark:GetWidth(), 20), "marker size applies")
	write(env, K, "separateReagents", true)
	assert(#win.sections[3].order == 2 and win.sections[3].cap:IsShown(), "the reagent bag gets its own row")
	assert(not shown(reagent.mark), "no marker once the reagent bag is apart")
	assert(reagent.button:GetParent():GetParent() == win.sections[3].grid, "reagent slots move to their row")
	write(env, K, "separateReagents", false)
	assert(#win.sections[3].order == 0 and reagent.button:GetParent():GetParent() == win.sections[1].grid and shown(reagent.mark), "turning it off restores the shared grid")
	write(env, K, "reagentMark", false)
	assert(not shown(reagent.mark))
	clean(env, K)
end

-- Sections: recent items, merging, value, gear by slot, types, sets, expansions and side-by-side sections.
do
	local potion = Item("potion", { count = 5 })
	local env, K, ns, win = new({ enabled = true, compactBags = true }, {
		sets = { { name = "Tank", items = { 1002 } } },
		bags = { [0] = { size = 12, items = { potion, SWORD, HELM, RING, Item("cloth"), Item("cloth"), Item("cloth", { itemID = 4338, name = "Mageweave Cloth", subtype = "Mageweave" }) } }, [5] = { size = 2, items = { Item("cloth", { reagent = true }) } } },
	})
	local main = win.sections[1]
	write(env, K, "recentItems", true)
	assert(not main.groups.recent or main.groups.recent.total == 0, "no recent section without new items")
	env._new["0:9"] = true
	B.Put(env, 0, 9, Item("potion", { count = 3 }))
	env.RunTimers()
	assert(main.groups.recent.total == 1 and main.groups.recent.view:IsShown(), "a new item opens the Recent section")
	assert(win:Panels()[1] == main.groups.recent, "Recent comes first")
	write(env, K, "recentGained", true)
	B.Put(env, 0, 9, Item("potion", { count = 5 }))
	env.RunTimers()
	assert(slot(ns, 0, 9).count:GetText() == "5", "picked-up amount counts what arrived, got " .. tostring(slot(ns, 0, 9).count:GetText()))
	write(env, K, "recentNewOnly", true)
	assert(not main.groups.recent or main.groups.recent.total == 0, "potions you already carried are not new")
	write(env, K, "recentNewOnly", false)
	write(env, K, "recentClear", true)
	assert(win.clearButton:IsShown(), "the clear button shows with recent items")
	win.clearButton:GetScript("OnClick")(win.clearButton)
	env.RunTimers()
	assert(B.Count(env, "RemoveNewItem") >= 1 and not win.clearButton:IsShown() and main.groups.recent.total == 0, "clearing empties Recent")
	write(env, K, "recentItems", false)
	write(env, K, "mergeStacks", true)
	local cloth1, cloth2 = slot(ns, 0, 5), slot(ns, 0, 6)
	assert(cloth1.count:GetText() == "60" and not cloth2.button:IsShown() and not slot(ns, 5, 1).button:IsShown(), "three cloth stacks merge into one tile, got " .. tostring(cloth1.count:GetText()))
	assert(slot(ns, 0, 2).button:IsShown() and slot(ns, 0, 3).button:IsShown(), "gear never merges")
	env.FireEvent("MAIL_SHOW")
	assert(cloth2.button:IsShown() and cloth1.count:GetText() == "20", "merging pauses at the mailbox")
	env.FireEvent("MAIL_CLOSED")
	assert(not cloth2.button:IsShown(), "merging resumes when the mailbox closes")
	env.SetMerchant(true)
	env.RunTimers()
	assert(cloth2.button:IsShown(), "merging pauses at a merchant")
	env.SetMerchant(false)
	env.RunTimers()
	write(env, K, "mergeStacks", false)
	assert(cloth2.button:IsShown() and cloth1.count:GetText() == "20", "turning merge off shows every stack")
	write(env, K, "sectionValue", true)
	assert(main.groups.tradeGoods.cap.count:GetText():find("c", 1, true), "the section heading carries its value")
	write(env, K, "sectionValue", false)
	assert(main.groups.tradeGoods.cap.count:GetText() == tostring(main.groups.tradeGoods.total), "value off restores the plain count")
	write(env, K, "sectionValue", true)
	write(env, K, "gearBySlot", true)
	local head, weapon = main.groups["equipment||Head"], main.groups["equipment||One-Hand"]
	assert(head and weapon and head.total == 1 and weapon.total == 1, "gear splits by slot")
	assert(#env._errors == 0 and K.ErrorCount() == 0 and head.cap.count:GetText():find("c", 1, true), "a section made while values show carries its value")
	write(env, K, "sectionValue", false)
	assert(head.cap.label:GetText():lower():find("head", 1, true) and head.rank < weapon.rank, "head comes before weapons")
	write(env, K, "compactGroups", true)
	local finger = main.groups["equipment||Finger"]
	assert(select(4, finger.view:GetPoint(1)) > 0 and select(5, finger.view:GetPoint(1)) == select(5, head.view:GetPoint(1)), "a small section sits beside the one before it")
	assert(select(4, weapon.view:GetPoint(1)) == 0, "a section that does not fit starts a new row")
	assert(finger.cap:GetWidth() < win.stack:GetWidth() / 2, "side-by-side headings take half the width")
	write(env, K, "compactGroups", false)
	assert(select(4, finger.view:GetPoint(1)) == 0, "off stacks sections again")
	write(env, K, "gearBySlot", false)
	write(env, K, "splitTypes", true)
	assert(main.groups["tradeGoods||Mageweave"] and main.groups["tradeGoods||Cloth"], "trade goods split by material")
	write(env, K, "splitTypes", false)
	write(env, K, "splitSets", true)
	assert(main.groups["set:Tank"].total == 1 and main.groups["set:Tank"].rank < main.groups.equipment.rank, "set gear gets its own section first")
	write(env, K, "splitSets", false)
	write(env, K, "nestExpansion", true)
	local tbc = main.groups["equipment|1|"]
	assert(tbc and tbc.cap.label:GetText():lower():find("burning crusade", 1, true), "items split by expansion")
	assert(tbc.rank < main.groups["equipment|0|"].rank, "newest expansion first")
	write(env, K, "nestExpansion", false)
	assert(main.groups.equipment.total == 3 and main.groups["equipment|1|"].total == 0, "off joins the sections again")
	write(env, K, "categorizeReagents", false)
	assert(#win.sections[3].order == 2 and not main.groups.tradeGoods.order[4], "the reagent bag gets its own section")
	write(env, K, "categorizeReagents", true)
	assert(#win.sections[3].order == 0)
	write(env, K, "capSize", 14)
	local label = main.groups.equipment.cap.label
	assert(select(2, label:GetFont()) == K.Widgets.FontSize(label, 14 * K.Theme.FontScale()), "heading size applies")
	clean(env, K)
end

-- List view.
do
	local env, K, ns, win = new({ enabled = true }, { bags = { [0] = { size = 4, items = { Item("potion"), Item("sword") } } } })
	local s1, s2 = slot(ns, 0, 1), slot(ns, 0, 2)
	write(env, K, "listView", true)
	assert(s1.list and s1.button:GetWidth() > s1.button:GetHeight() and W.Near(s1.button:GetHeight(), 24), "slots become rows")
	assert(shown(s1.name) and s1.name:GetText() == "Minor Healing Potion", "rows show the item name")
	assert(s2.stripe and not s1.stripe, "every other row is shaded")
	write(env, K, "listStripes", false)
	assert(not s2.stripe, "stripes turn off")
	write(env, K, "listRowHeight", 20)
	assert(W.Near(s1.button:GetHeight(), 20), "row height applies")
	write(env, K, "listFontSize", 14)
	assert(select(2, s1.name:GetFont()) == 14, "row text size applies")
	local width = s1.button:GetWidth()
	write(env, K, "listLeft", 10)
	write(env, K, "listRight", 6)
	assert(W.Near(s1.button:GetWidth(), width - 16) and select(4, win.sections[1].grid:GetPoint(1)) == 10, "gaps inset the rows")
	write(env, K, "listView", false)
	assert(not s1.list and W.Near(s1.button:GetWidth(), s1.button:GetHeight()) and not shown(s1.name) and not s2.stripe, "off restores square tiles")
	clean(env, K)
end

-- The window: maximum height, nearest corner, bag slots, currencies and the gold list.
do
	local env, K, ns, win = new({ enabled = true, columns = 4 }, {
		bags = { [0] = { size = 80, items = {} } },
		equippedBags = { [1] = { icon = 133633, quality = 1 } },
		currencies = { { name = "Honor", quantity = 120, iconFileID = 1455894, currencyTypesID = 1 } },
	})
	local panel = win.panel
	local full = panel:GetHeight()
	write(env, K, "maxHeight", 50)
	assert(panel:GetHeight() <= K.Scale.Root():GetHeight() * 0.5 + 1 and panel:GetHeight() < full, "the window stops at half the screen")
	write(env, K, "maxHeight", 100)
	assert(W.Near(panel:GetHeight(), full), "100 restores the old bound")
	write(env, K, "nearestCorner", true)
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 40, -40)
	win:SavePosition()
	assert(K.Layout.Get("bags.inventory").anchor == "TOPLEFT", "a window near the top left holds that corner")
	write(env, K, "bagSlots", true)
	local strip = win.bagStrip
	assert(strip and strip.frame:IsShown() and strip.slots[1].record.icon == 133633, "the bag strip shows the equipped bags")
	strip.slots[1].button:GetScript("OnClick")(strip.slots[1].button)
	assert(B.Count(env, "PickupBagFromSlot") == 1, "clicking a bag picks it up")
	env.SetCombat(true)
	strip.slots[1].button:GetScript("OnClick")(strip.slots[1].button)
	env.SetCombat(false)
	assert(B.Count(env, "PickupBagFromSlot") == 1, "bags never move in combat")
	write(env, K, "bagSlots", false)
	assert(not strip.frame:IsShown(), "off hides the strip")
	local height = panel:GetHeight()
	write(env, K, "currencies", true)
	assert(shown(win.currency) and win.currency:GetText():find("120", 1, true) and panel:GetHeight() > height, "the footer gains the tracked currencies")
	env._currencyQuantity = nil
	write(env, K, "currencies", false)
	assert(not shown(win.currency) and W.Near(panel:GetHeight(), height), "off restores the footer")
	K.Store.Account().inventory.characters["Alt-Realm"] = { name = "Alt", class = "MAGE", seen = env.time and env.time() or os.time(), money = 2500000, bags = {}, bank = {}, items = {} }
	local hover = win.moneyHover
	assert(hover:IsMouseEnabled(), "the gold list is on by default")
	hover:GetScript("OnEnter")(hover)
	local lines = env.GameTooltip._lines
	assert(lines[#lines][1] == K.L["Total"] and lines[#lines][2] == "373g 45s 67c", "the gold list totals every character, got " .. tostring(lines[#lines][2]))
	write(env, K, "goldCoins", "gold")
	env.GameTooltip:ClearLines()
	hover:GetScript("OnEnter")(hover)
	assert(env.GameTooltip._lines[#env.GameTooltip._lines][2] == "373g", "coins shown applies")
	write(env, K, "goldTooltip", false)
	assert(not hover:IsMouseEnabled(), "off stops the money from taking the mouse")
	clean(env, K)
end

-- Opening and closing with other windows.
do
	local env, K, ns = new({ enabled = true }, { bags = { [0] = { size = 4, items = {} } } })
	local Inventory = ns.Inventory
	env.ToggleAllBags()
	env.RunTimers()
	assert(not Inventory.IsOpen())
	env.OpenAllBags(env.MerchantFrame)
	env.RunTimers()
	assert(Inventory.IsOpen(), "a merchant opens the bags by default")
	env.CloseAllBags(env.MerchantFrame)
	env.RunTimers()
	assert(not Inventory.IsOpen(), "and closes them")
	write(env, K, "autoMerchant", "none")
	env.OpenAllBags(env.MerchantFrame)
	env.RunTimers()
	assert(not Inventory.IsOpen(), "leave bags alone keeps them shut at a merchant")
	env.CloseAllBags(env.MerchantFrame)
	env.RunTimers()
	write(env, K, "autoMerchant", "open")
	env.OpenAllBags(env.MerchantFrame)
	env.RunTimers()
	env.CloseAllBags(env.MerchantFrame)
	env.RunTimers()
	assert(Inventory.IsOpen(), "open only leaves the bags open after the merchant")
	Inventory.Close()
	write(env, K, "autoTrade", "both")
	env.FireEvent("TRADE_SHOW")
	assert(Inventory.IsOpen(), "a trade opens the bags")
	env.FireEvent("TRADE_CLOSED")
	assert(not Inventory.IsOpen(), "and closes the bags it opened")
	Inventory.Open()
	env.FireEvent("TRADE_SHOW")
	env.FireEvent("TRADE_CLOSED")
	assert(Inventory.IsOpen(), "bags you opened yourself stay open")
	Inventory.Close()
	write(env, K, "autoLoot", "open")
	env.FireEvent("LOOT_OPENED")
	env.FireEvent("LOOT_CLOSED")
	assert(Inventory.IsOpen(), "open only keeps the bags after looting")
	Inventory.Close()
	write(env, K, "autoQuest", "both")
	env.FireEvent("QUEST_DETAIL")
	assert(Inventory.IsOpen())
	env.FireEvent("QUEST_FINISHED")
	assert(not Inventory.IsOpen(), "the quest giver's bags close with it")
	clean(env, K)
end

-- Warband gold.
do
	local env, K, ns = new({ enabled = true, warbandGold = true, warbandGoldAmount = "100", warbandGoldChat = true }, { money = 1234567, warbandMoney = 50000 })
	env.SetBank(true)
	env.RunTimers()
	local call = B.Calls(env, "DepositMoney")[1]
	assert(call and call[1] == B.BANK.Account and call[2] == 234567 and env._money == 1000000, "gold above the amount goes to the Warband bank")
	env.SetBank(false)
	env._money = 990000
	env.SetBank(true)
	env.RunTimers()
	assert(B.Calls(env, "WithdrawMoney")[1][2] == 10000 and env._money == 1000000, "gold below the amount comes back")
	env.SetBank(false)
	write(env, K, "warbandGoldAmount", "")
	env._money = 5
	env.SetBank(true)
	env.RunTimers()
	assert(#B.Calls(env, "WithdrawMoney") == 1, "an empty amount moves nothing")
	env.SetBank(false)
	write(env, K, "warbandGold", false)
	write(env, K, "warbandGoldAmount", "100")
	env.SetBank(true)
	env.RunTimers()
	assert(#B.Calls(env, "WithdrawMoney") == 1 and #B.Calls(env, "DepositMoney") == 1, "off moves nothing")
	env.SetBank(false)
	clean(env, K)
	local env2, K2 = new({ enabled = true, warbandGold = true, warbandGoldAmount = "1" }, { moneyTransfer = false })
	env2.SetBank(true)
	env2.RunTimers()
	assert(B.Count(env2, "DepositMoney") == 0, "no transfer where the Warband bank cannot hold money")
	clean(env2, K2)
end

-- The bank splits by expansion on its own switch.
do
	local env, K, ns = new({ enabled = true, compactBags = true, nestExpansion = true }, { bank = { [6] = { size = 4, items = { HELM } } } })
	env.SetBank(true)
	env.RunTimers()
	local groups = ns.Bank.window.sections[1].groups
	assert(groups.equipment and groups.equipment.total == 1, "the bags' switch leaves the bank alone")
	write(env, K, "bankNestExpansion", true)
	assert(groups["equipment|1|"].total == 1, "the bank's own switch splits it")
	clean(env, K)
end

-- The live preview follows the slot options.
do
	local env, K = new({ enabled = true }, {})
	local holder = env.CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(320, 200)
	local preview = K.Options.Preview("Bags")(holder)
	local sword, helm, cloth = preview.slots[2], preview.slots[3], preview.slots[6]
	assert(not sword.bind and not helm.set and not cloth.mark, "the default preview is unchanged")
	write(env, K, "bindText", true)
	write(env, K, "setNames", true)
	write(env, K, "reagentMark", true)
	preview:Refresh()
	assert(shown(sword.bind) and shown(helm.set) and shown(cloth.mark), "the preview shows labels and the marker")
	write(env, K, "listView", true)
	preview:Refresh()
	assert(preview.slots[1].list and shown(preview.slots[1].name) and not preview.slots[5].button:IsShown(), "the preview shows list rows")
	clean(env, K)
end

print("bags parity ok: labels, sections, list, window, footer, auto open, warband gold and preview")
