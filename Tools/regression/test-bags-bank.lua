-- test-bags-bank.lua: the bank window opens with the bank, shows each bank type's purchased tabs on Blizzard's item buttons, sorts, buys tabs, holds bank bags and closes the bank.
local B = dofile("Tools/regression/bags_env.lua")
local W = B.W
local Item, BANK = B.Item, B.BANK

local function BankContents()
	return {
		[6] = { size = 24, items = { [1] = Item("cloth"), [2] = Item("helm") } },
		[7] = { size = 8, items = { [3] = Item("potion") } },
		[15] = { size = 12, items = { [1] = Item("ring") } },
	}
end

local function New(opts)
	opts = opts or {}
	opts.bags = opts.bags or { [0] = { size = 16, items = { [1] = Item("junk") } } }
	opts.bank = opts.bank or BankContents()
	opts.bankTabs = opts.bankTabs or { [BANK.Character] = { 6, 7 } }
	opts.bankBags = opts.bankBags or { [2] = Item("cloth", { itemID = 4500, name = "Traveler's Backpack", icon = 133633, count = 1 }) }
	return B.New(opts)
end

local function Run(env)
	env.RunTimers()
	W.Settle(env)
end

local function Set(K, key, value)
	assert(K.Options.Write("Bags", key, value) ~= false, "writing " .. key)
end

-- Settings ----------------------------------------------------------------------------------------

do
	local _, K = New({ enable = false })
	local keys = {}
	for _, row in ipairs(K.Options.Get("Bags")) do
		if row.key then
			keys[row.key] = row.type
		end
	end
	for key, kind in pairs({ bankColumns = "slider", bankOpensBags = "toggle", replaceBank = "toggle" }) do
		assert(keys[key] == kind, "the settings page has a " .. kind .. " for " .. key)
	end
end

-- Blizzard's bank -----------------------------------------------------------------------------------

do
	local env, K = New()
	assert(K.Safe.IsHidden(env.BankFrame), "Enable hides Blizzard's bank under a hidden parent, before it ever shows")
	assert(#W.Calls(env.BankFrame, "SetScript") == 0, "no SetScript on BankFrame")

	local env2, K2 = New({ setup = function(e)
		e.KstyleUIDB = { profiles = { Default = { Bags = { replaceBank = false } } } }
	end })
	assert(not K2.Safe.IsHidden(env2.BankFrame), "with Replace bank off, Blizzard's bank stays")
	env2.SetBank(true)
	Run(env2)
	local _, _, ns2 = env2, K2, env2._addons.KstyleUI_Bags
	assert(not ns2.Bank.IsOpen(), "and KstyleUI's bank window stays closed")

	local env3, K3 = New({ gamepad = true })
	assert(not K3.Safe.IsHidden(env3.BankFrame), "the gamepad style keeps Blizzard's bank")
end

-- Opening and closing with the bank ---------------------------------------------------------------

do
	local env, K, ns = New()
	local Bank, Inventory = ns.Bank, ns.Inventory
	assert(Bank.window and not Bank.window.panel:IsShown(), "Enable builds the bank window, closed")
	env.SetBank(true)
	Run(env)
	assert(Bank.IsOpen() and Bank.window.panel:IsShown(), "BANKFRAME_OPENED opens the bank window")
	assert(Inventory.IsOpen(), "and the bags beside it")
	local slot = assert(Bank.Slot(6, 2), "bank tab 6 has its slots")
	assert(slot.button._template == "ContainerFrameItemButtonTemplate", "on Blizzard's item buttons")
	assert(slot.button:GetParent():GetID() == 6 and slot.button:GetID() == 2, "with the bank bag as the parent's ID")
	assert(Bank.Slot(7, 8) and not Bank.Slot(7, 9), "every purchased tab, each to its size")
	assert(Bank.Slot(6, 2).level:GetText() == "66", "bank slots show item levels")
	assert(Bank.window.free:GetText():find("29/32", 1, true), "the footer counts the bank's free slots: " .. tostring(Bank.window.free:GetText()))
	assert(K.Layout.Get("bags.bank").anchor == "TOPLEFT", "the bank registers with Layout as bags.bank")

	B.Put(env, 7, 4, Item("sword"))
	Run(env)
	assert(Bank.Slot(7, 4).level:GetText() == "12", "a bank update refreshes the slot")

	env.SetBank(false)
	Run(env)
	assert(not Bank.IsOpen() and not Bank.window.panel:IsShown(), "BANKFRAME_CLOSED closes the bank window")
	assert(not Inventory.IsOpen(), "and the bags the bank opened")
	assert(B.Count(env, "CloseBankFrame") == 0, "the game closed the bank, so KstyleUI does not close it again")

	env.ToggleAllBags()
	Run(env)
	env.SetBank(true)
	Run(env)
	env.SetBank(false)
	Run(env)
	assert(Inventory.IsOpen(), "bags the player opened stay open when the bank closes")
	Inventory.Close()
	Run(env)

	env.SetBank(true)
	Run(env)
	local close = Bank.window.panel.closeButton
	close:GetScript("OnClick")(close, "LeftButton")
	Run(env)
	assert(B.Count(env, "CloseBankFrame") == 1, "closing the bank window ends the bank visit")
	env.SetBank(false)
	Run(env)

	Set(K, "bankOpensBags", false)
	env.SetBank(true)
	Run(env)
	assert(Bank.IsOpen() and not Inventory.IsOpen(), "the bags stay closed when Bank opens bags is off")
	env.SetBank(false)
	Run(env)
end

-- Sort, buy, deposit and the bank types -------------------------------------------------------------

do
	local env, _, ns = New({ bankTabs = { [BANK.Character] = { 6, 7 }, [BANK.Account] = { 15 } } })
	local Bank = ns.Bank
	env.SetBank(true)
	Run(env)
	local win = Bank.window
	W.Click(win.sortButton)
	local sorts = B.Calls(env, "SortBank")
	assert(#sorts == 1 and sorts[1][1] == BANK.Character, "Sort sorts the character bank")
	assert(win.tabs and win.tabs:IsShown(), "two bank types show tabs")
	local buy = win.buyButton
	assert(buy._template == "BankPanelPurchaseButtonScriptTemplate", "Buy is Blizzard's purchase button template for addons")
	assert(buy:GetAttribute("overrideBankType") == BANK.Character and buy:IsShown(), "set to the character bank")
	assert(not win.depositButton:IsShown(), "the character bank has no deposit-all")
	win.tabs:Select(BANK.Account)
	Run(env)
	assert(Bank.Slot(15, 1) and Bank.Slot(15, 1).button:IsVisible(), "the Warband tab shows the account bank's tabs")
	assert(not Bank.Slot(6, 1).button:IsVisible(), "and hides the character bank")
	assert(buy:GetAttribute("overrideBankType") == BANK.Account, "Buy follows the bank type")
	assert(win.depositButton:IsShown(), "the account bank can deposit everything it takes")
	W.Click(win.depositButton)
	assert(B.Calls(env, "AutoDepositItemsIntoBank")[1][1] == BANK.Account, "Deposit deposits into the account bank")
	W.Click(win.sortButton)
	sorts = B.Calls(env, "SortBank")
	assert(sorts[#sorts][1] == BANK.Account, "Sort sorts the account bank")
	env._bankTabs[BANK.Account] = { 15, 16, 17, 18, 19, 20, 21 }
	env.FireEvent("BANK_TABS_CHANGED", BANK.Account)
	Run(env)
	assert(not buy:IsShown(), "Buy hides when no tab is left to buy")
end

-- Categories: the bank sorts into the same Lumen sections as the bags -------------------------------

do
	local env, K, ns = New({ bankTabs = { [BANK.Character] = { 6, 7 }, [BANK.Account] = { 15 } } })
	local Bank = ns.Bank
	env.SetBank(true)
	Run(env)
	local win = Bank.window
	local section = win.sections[1]
	local groups = section.groups
	assert(type(groups) == "table", "the bank section holds category groups")
	local function Has(group, bag, slot)
		for _, s in ipairs(group.order) do
			if s.bag == bag and s.id == slot then
				return true
			end
		end
		return false
	end
	assert(groups.equipment and #groups.equipment.order == 1 and Has(groups.equipment, 6, 2), "the helm is equipment")
	assert(groups.tradeGoods and Has(groups.tradeGoods, 6, 1) and groups.consumables and Has(groups.consumables, 7, 3), "cloth is trade goods and the potion a consumable")
	assert(groups.empty and groups.equipment.cap:IsShown() and groups.equipment.cap.label:GetText():find("EQUIPMENT", 1, true), "sections wear the Lumen caps")
	assert(not section.view:IsShown(), "the one bank grid hides while sections show")
	win.tabs:Select(BANK.Account)
	Run(env)
	assert(Has(groups.equipment, 15, 1) and not Has(groups.equipment, 6, 2), "the Warband bank sorts into the same sections")
	assert(Bank.Slot(15, 1).button:IsVisible() and not Bank.Slot(6, 2).button:IsVisible(), "the character bank's slots hide when the Warband bank shows, even in a section both fill")
	win.search:SetText("band & !weapon")
	win.search:GetScript("OnTextChanged")(win.search, true)
	assert(W.LastCall(Bank.Slot(15, 1).icon, "SetAlpha")[1] == 1, "the bank search uses the grammar")
	Set(K, "layout", "grid")
	assert(section.view:IsShown() and not groups.equipment.view:IsShown(), "the grid layout applies to the bank too")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Bank bags ----------------------------------------------------------------------------------------

do
	local env, _, ns = New()
	local Bank = ns.Bank
	env.SetBank(true)
	Run(env)
	local bags = Bank.window.bankBags
	assert(bags and #bags.slots == 6, "a slot for each bank bag beyond the first tab: " .. tostring(bags and #bags.slots))
	local first = bags.slots[1]
	assert(W.Calls(first.icon, "SetTexture")[1][1] == 133633, "a bank bag slot shows its bag")
	assert(not bags.slots[2].button:IsShown(), "slots not bought yet stay hidden")
	first.button:GetScript("OnClick")(first.button, "LeftButton")
	local picks = B.Calls(env, "PickupContainerItem")
	assert(#picks == 1 and picks[1][1] == -2 and picks[1][2] == 2, "a click picks up the bag from its bank bag slot")
	first.button:GetScript("OnEnter")(first.button)
	assert(B.Calls(env, "GameTooltip:SetBagItem")[1][1] == -2, "the tooltip shows the bag")
	env.SetCombat(true)
	first.button:GetScript("OnClick")(first.button, "LeftButton")
	assert(#B.Calls(env, "PickupContainerItem") == 1, "no pickup in combat")
	env.SetCombat(false)
end

-- Warband bank bags ------------------------------------------------------------------------------------

do
	local env, _, ns = New({
		bankTabs = { [BANK.Character] = { 6, 7 }, [BANK.Account] = { 15, 16 } },
		accountBags = { [2] = Item("cloth", { itemID = 4501, name = "Warband Satchel", icon = 133639, count = 1 }) },
	})
	env.SetBank(true)
	Run(env)
	ns.Bank.window.tabs:Select(BANK.Account)
	Run(env)
	local strip = ns.Bank.window.bankBags
	assert(strip.frame:IsShown(), "the Warband bank shows its bank bag slots too")
	local first = strip.slots[1]
	assert(W.LastCall(first.icon, "SetTexture")[1] == 133639, "with the Warband bank's bag")
	first.button:GetScript("OnClick")(first.button, "LeftButton")
	local picks = B.Calls(env, "PickupContainerItem")
	assert(picks[#picks][1] == -3 and picks[#picks][2] == 2, "a click picks up the bag from the Warband bank's bag slots")
end

-- Narrow windows keep a usable search field -------------------------------------------------------------

do
	local env, K, ns = New({ bankTabs = { [BANK.Character] = { 6 }, [BANK.Account] = { 15 } } })
	env.SetBank(true)
	Run(env)
	Set(K, "bankColumns", 4)
	ns.Bank.window.tabs:Select(BANK.Account)
	Run(env)
	local win = ns.Bank.window
	assert(win.buyButton:IsShown() and win.depositButton:IsShown(), "both actions show")
	assert(win.search:GetWidth() >= 100, "the search field keeps room to type: " .. tostring(win.search:GetWidth()))
end

-- Late item info and cooldowns ------------------------------------------------------------------------

do
	local env, _, ns = New()
	local helm = env._bank[6].items[2]
	helm.ilvl = nil
	env.SetBank(true)
	Run(env)
	local slot = ns.Bank.Slot(6, 2)
	assert(not slot.level:IsShown(), "an uncached item shows no level yet")
	helm.ilvl = 66
	env.FireEvent("GET_ITEM_INFO_RECEIVED", helm.itemID, true)
	Run(env)
	assert(slot.level:IsShown() and slot.level:GetText() == "66", "the bank refreshes when item info arrives")
	env._bank[7].items[3].cooldown = { 100, 30 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	local call = W.LastCall(ns.Bank.Slot(7, 3).cooldown, "SetCooldown")
	assert(call and call[1] == 100 and call[2] == 30, "bank cooldowns follow BAG_UPDATE_COOLDOWN")
end

-- Columns, combat, Disable -------------------------------------------------------------------------

do
	-- The bank window hugs its widest row: twelve cloth stacks in one tab make a twelve-wide trade goods row, and
	-- the column setting narrows the window only once it wraps that row.
	local bank = BankContents()
	for slot = 3, 14 do
		bank[6].items[slot] = Item("cloth", { count = slot })
	end
	local env, K, ns = New({ bank = bank })
	local Bank = ns.Bank
	env.SetBank(true)
	Run(env)
	local wide = Bank.window.panel:GetWidth()
	Set(K, "bankColumns", 8)
	assert(Bank.window.panel:GetWidth() < wide, "bank columns narrow the bank window once they wrap its widest row")
	Set(K, "replaceBank", false)
	assert(B.W.CoreEnv.Printed(env, "reload"), "changing Replace bank asks for a reload")
	K.Modules.Disable("Bags")
	Run(env)
	assert(not Bank.window.panel:IsShown(), "Disable closes the bank window")
	assert(B.Count(env, "CloseBankFrame") == 1, "and ends the bank visit")
	assert(K.Safe.IsHidden(env.BankFrame), "Blizzard's bank waits under the hidden parent while it is open")
	env.SetBank(false)
	Run(env)
	assert(not K.Safe.IsHidden(env.BankFrame) and env.BankFrame:GetParent() == env.UIParent, "and returns once the bank closes")
end

-- The interaction manager -------------------------------------------------------------------------

do
	local env, _, ns = New({ setup = function(e)
		e.Enum.PlayerInteractionType = { Merchant = 5, Banker = 8, CharacterBanker = 67, AccountBanker = 68 }
	end })
	env.BankFrame:Show()
	env.FireEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
	Run(env)
	assert(not ns.Bank.IsOpen(), "a merchant is not a bank")
	env.FireEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 67)
	Run(env)
	assert(ns.Bank.IsOpen(), "a banker interaction opens the bank even without BANKFRAME_OPENED")
	env.FireEvent("BANKFRAME_OPENED")
	Run(env)
	assert(ns.Bank.IsOpen(), "and BANKFRAME_OPENED after it changes nothing")
	env.FireEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 67)
	Run(env)
	assert(not ns.Bank.IsOpen() and B.Count(env, "CloseBankFrame") == 0, "the interaction's end closes it")
end

-- Turning the module on during a bank visit ---------------------------------------------------------

do
	local env, K, ns = New({ enable = false })
	env.SetBank(true)
	B.Enable(env, K)
	Run(env)
	assert(not K.Safe.IsHidden(env.BankFrame), "a bank that is already open keeps Blizzard's window: moving it now would run its OnHide and end the visit")
	assert(not ns.Bank.IsOpen(), "and KstyleUI's bank stays closed for this visit")
	env.SetBank(false)
	Run(env)
	assert(K.Safe.IsHidden(env.BankFrame), "KstyleUI's bank takes over once the visit ends")
	env.SetBank(true)
	Run(env)
	assert(ns.Bank.IsOpen(), "and opens at the next visit")
end

print("bags bank ok")
