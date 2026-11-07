-- bags_env.lua: load the core and KstyleUI_Bags into a stub environment with a fake inventory, bank and Blizzard bag frames.
--
--   local B = dofile("Tools/regression/bags_env.lua")
--   local env, K, ns = B.New({ bags = { [0] = { size = 16, items = { [1] = B.Item("potion") } } } })
--   env.ToggleAllBags()   -- Blizzard's own function; the module's hook opens its bag window
--   env.RunTimers()
--
-- The fake game keeps Blizzard's open state the way Blizzard's code does: ContainerFrameCombinedBags is
-- shown while the bags are open, under whatever parent it has. Every call the module makes into the
-- container and bank APIs is recorded in env._calls.
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local B = { W = W, CoreEnv = W.CoreEnv }

B.QUALITY = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Artifact = 6, Heirloom = 7 }
B.CLASS = { Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Reagent = 5, Tradegoods = 7, Quest = 12, Key = 13, Miscellaneous = 15 }
B.BANK = { Character = 0, Guild = 1, Account = 2 }

-- Items the tests put in bags, by name. Each call returns a fresh copy.
local ITEMS = {
	potion = { itemID = 118, name = "Minor Healing Potion", icon = 134829, count = 5, quality = 1, classID = 0, type = "Consumable", subtype = "Potion" },
	sword = { itemID = 1000, name = "Worn Shortsword", icon = 135274, count = 1, quality = 2, classID = 2, type = "Weapon", subtype = "One-Handed Swords", ilvl = 12 },
	helm = { itemID = 1001, name = "Nightslayer Cover", icon = 133074, count = 1, quality = 4, classID = 4, type = "Armor", subtype = "Leather", ilvl = 66 },
	ring = { itemID = 1002, name = "Band of Thorns", icon = 133344, count = 1, quality = 3, classID = 4, type = "Armor", subtype = "Miscellaneous", ilvl = 30 },
	junk = { itemID = 2000, name = "Broken Fang", icon = 133723, count = 3, quality = 0, classID = 15, type = "Miscellaneous", subtype = "Junk" },
	hearth = { itemID = 6948, name = "Hearthstone", icon = 134414, count = 1, quality = 1, classID = 15, type = "Miscellaneous", subtype = "Other", noValue = true },
	greyNoValue = { itemID = 2001, name = "Torn Note", icon = 134937, count = 1, quality = 0, classID = 15, type = "Miscellaneous", subtype = "Junk", noValue = true },
	key = { itemID = 3000, name = "Scarlet Key", icon = 134237, count = 1, quality = 1, classID = 13, type = "Key", subtype = "Key" },
	cloth = { itemID = 4306, name = "Silk Cloth", icon = 132905, count = 20, quality = 1, classID = 7, type = "Trade Goods", subtype = "Cloth" },
}

function B.Item(name, fields)
	local base = assert(ITEMS[name], "bags_env: no item named " .. tostring(name))
	local item = {}
	for k, v in pairs(base) do
		item[k] = v
	end
	for k, v in pairs(fields or {}) do
		item[k] = v
	end
	item.link = item.link or ("|cff000000|Hitem:" .. item.itemID .. "::::|h[" .. item.name .. "]|h|r")
	return item
end

local moduleFiles
function B.Files()
	if not moduleFiles then
		moduleFiles = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:match("^KstyleUI_Bags/") then
				moduleFiles[#moduleFiles + 1] = path
			end
		end
		assert(#moduleFiles > 0, "no KstyleUI_Bags files found")
	end
	return moduleFiles
end

local function record(env, name, ...)
	env._calls[#env._calls + 1] = { name = name, n = select("#", ...), ... }
end

-- Count(env, name) -> how many times the module called the named API.
function B.Count(env, name)
	local n = 0
	for _, call in ipairs(env._calls) do
		if call.name == name then
			n = n + 1
		end
	end
	return n
end

function B.Calls(env, name)
	local out = {}
	for _, call in ipairs(env._calls) do
		if call.name == name then
			out[#out + 1] = call
		end
	end
	return out
end

local function bagIndex()
	local t = {
		Accountbanktab = -3, Characterbanktab = -2, Keyring = -1, Backpack = 0,
		Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5,
	}
	for i = 1, 9 do
		t["CharacterBankTab_" .. i] = 5 + i
		t["AccountBankTab_" .. i] = 14 + i
	end
	return t
end

-- Game(env, opts) installs the fake game APIs. opts:
--   bags     { [bagID] = { size, items = { [slot] = item } } } for bags 0 to 5 and the keyring (-1)
--   bank     { [bagID] = { size, items } } for bank tabs 6 to 23
--   bankTabs { [bankType] = { bagID, ... } } purchased tabs; default: every bank bag in opts.bank as Character
--   keyring  false when C_ActionBar.ShouldShowKeyring returns false
--   money    copper, default 1234567
--   gamepad  true when the gamepad interface style is on
function B.Game(env, opts)
	opts = opts or {}
	env._calls = {}
	env._bags = opts.bags or { [0] = { size = 16, items = {} } }
	env._bank = opts.bank or {}
	env._new = {}
	env._locked = {}
	env._gamepad = opts.gamepad == true
	env._money = opts.money or 1234567
	env._bagsAllowed = true
	env._rtl = false
	env._merchant = false

	env.Enum = {
		BagIndex = bagIndex(),
		ItemQuality = B.QUALITY,
		ItemClass = B.CLASS,
		BankType = B.BANK,
	}
	env.Constants = { InventoryConstants = { NumBagSlots = 4, NumReagentBagSlots = 1 } }
	env.BACKPACK_CONTAINER = 0
	env.KEYRING_CONTAINER = -1
	env.NUM_CONTAINER_FRAMES = 7
	env.ITEM_INVENTORY_BANK_BAG_OFFSET = 5

	local function container(bag)
		return env._bags[bag] or env._bank[bag]
	end
	env._container = container

	local function item(bag, slot)
		if bag == -2 then
			return env._bankBags[slot]
		elseif bag == -3 then
			return env._accountBags[slot]
		end
		local c = container(bag)
		return c and c.items and c.items[slot]
	end

	env.C_Container = {
		GetContainerNumSlots = function(bag)
			local c = container(bag)
			return c and c.size or 0
		end,
		GetContainerItemInfo = function(bag, slot)
			local it = item(bag, slot)
			if not it then
				return nil
			end
			return {
				iconFileID = it.icon, stackCount = it.count, isLocked = env._locked[bag .. ":" .. slot] == true,
				quality = it.quality, isReadable = false, hasLoot = false, hyperlink = it.link, isFiltered = false,
				hasNoValue = it.noValue == true, itemID = it.itemID, isBound = it.bound == true, itemName = it.name,
			}
		end,
		GetContainerItemLink = function(bag, slot)
			local it = item(bag, slot)
			return it and it.link
		end,
		GetContainerItemCooldown = function(bag, slot)
			local it = item(bag, slot)
			if it and it.cooldown then
				return it.cooldown[1], it.cooldown[2], 1
			end
			return 0, 0, 1
		end,
		SortBags = function()
			record(env, "SortBags")
		end,
		SortBankBags = function()
			record(env, "SortBankBags")
		end,
		SortBank = function(bankType)
			record(env, "SortBank", bankType)
		end,
		SortAccountBankBags = function()
			record(env, "SortAccountBankBags")
		end,
		SetSortBagsRightToLeft = function(on)
			record(env, "SetSortBagsRightToLeft", on)
			env._rtl = on
		end,
		GetSortBagsRightToLeft = function()
			return env._rtl
		end,
		UseContainerItem = function(bag, slot)
			assert(not env.InCombatLockdown(), "UseContainerItem ran in combat")
			record(env, "UseContainerItem", bag, slot)
			local c = container(bag)
			if c and c.items then
				c.items[slot] = nil
			end
		end,
		PickupContainerItem = function(bag, slot)
			assert(not env.InCombatLockdown(), "PickupContainerItem ran in combat")
			record(env, "PickupContainerItem", bag, slot)
		end,
	}

	env.C_NewItems = {
		IsNewItem = function(bag, slot)
			return env._new[bag .. ":" .. slot] == true
		end,
		RemoveNewItem = function(bag, slot)
			record(env, "RemoveNewItem", bag, slot)
			env._new[bag .. ":" .. slot] = nil
		end,
		ClearAll = function()
			env._new = {}
		end,
	}

	local byID = {}
	local function index(it)
		if it then
			byID[it.itemID] = it
		end
	end
	for _, c in pairs(env._bags) do
		for _, it in pairs(c.items or {}) do
			index(it)
		end
	end
	for _, c in pairs(env._bank) do
		for _, it in pairs(c.items or {}) do
			index(it)
		end
	end
	for _, it in pairs(ITEMS) do
		byID[it.itemID] = byID[it.itemID] or it
	end
	local function byLink(link)
		local id = type(link) == "string" and tonumber(link:match("item:(%d+)") or "")
		return id and byID[id]
	end
	env._index = index

	env.C_Item = {
		GetItemInfoInstant = function(itemID)
			local it = byID[itemID] or byLink(itemID)
			if not it then
				return nil
			end
			return it.itemID, it.type, it.subtype, "", it.icon, it.classID, 0
		end,
		GetItemInfo = function(link)
			local it = byLink(link) or byID[link]
			if not it then
				return nil
			end
			return it.name, it.link, it.quality, it.ilvl or 1, 1, it.type, it.subtype, 20, "", it.icon, it.noValue and 0 or 5, it.classID, 0
		end,
		GetDetailedItemLevelInfo = function(link)
			record(env, "GetDetailedItemLevelInfo", link)
			local it = byLink(link)
			if it and it.ilvl then
				return it.ilvl, false, it.ilvl
			end
		end,
		GetItemQualityColor = function(quality)
			return 0.5, 0.5, 0.5
		end,
	}

	env.ItemLocation = {
		CreateFromBagAndSlot = function(_, bag, slot)
			return { bagID = bag, slotIndex = slot }
		end,
	}

	env.C_ActionBar = {
		ShouldShowKeyring = function()
			return opts.keyring ~= false
		end,
	}
	env.GetKeyRingSize = function()
		local c = env._bags[-1]
		return c and c.size or 0
	end

	-- The bank: purchased tabs per bank type (opts.bankTabs), the bank bag slots that hold bags, and
	-- BANKFRAME_OPENED and BANKFRAME_CLOSED through env.SetBank.
	local tabs = opts.bankTabs
	if not tabs then
		tabs = { [B.BANK.Character] = {} }
		for bag in pairs(env._bank) do
			table.insert(tabs[B.BANK.Character], bag)
		end
		table.sort(tabs[B.BANK.Character])
	end
	env._bankTabs = tabs
	env._bankMax = opts.bankMax or 7
	env._bankBags = opts.bankBags or {}
	env._accountBags = opts.accountBags or {}
	env._atBank = false
	env.C_Bank = {
		CanViewBank = function(bankType)
			return env._bankTabs[bankType] ~= nil
		end,
		AreAnyBankTypesViewable = function()
			return next(env._bankTabs) ~= nil
		end,
		FetchPurchasedBankTabIDs = function(bankType)
			local out = {}
			for i, bag in ipairs(env._bankTabs[bankType] or {}) do
				out[i] = bag
			end
			return out
		end,
		FetchNumPurchasedBankTabs = function(bankType)
			return #(env._bankTabs[bankType] or {})
		end,
		FetchMaxNumBankTabs = function()
			return env._bankMax
		end,
		CanPurchaseBankTab = function(bankType)
			return env._bankTabs[bankType] ~= nil and #env._bankTabs[bankType] < env._bankMax
		end,
		ShouldUsePlayerBagsInBank = function()
			return opts.playerBagsInBank ~= false
		end,
		DoesBankTypeSupportAutoDeposit = function(bankType)
			return bankType == B.BANK.Account
		end,
		AutoDepositItemsIntoBank = function(bankType)
			record(env, "AutoDepositItemsIntoBank", bankType)
		end,
		CloseBankFrame = function()
			record(env, "CloseBankFrame")
		end,
	}
	env.SetBank = function(atBank)
		env._atBank = atBank and true or false
		if atBank then
			env.BankFrame:Show()
			env.FireEvent("BANKFRAME_OPENED")
		else
			env.BankFrame:Hide()
			env.FireEvent("BANKFRAME_CLOSED")
		end
	end
	env.GameTooltip = env.CreateFrame("GameTooltip", "GameTooltip", env.UIParent)
	rawset(env.GameTooltip, "SetOwner", function(_, owner)
		record(env, "GameTooltip:SetOwner", owner)
	end)
	rawset(env.GameTooltip, "SetBagItem", function(_, bag, slot)
		record(env, "GameTooltip:SetBagItem", bag, slot)
		return item(bag, slot) ~= nil
	end)
	env.GameTooltip_Hide = function()
		env.GameTooltip:Hide()
	end

	env.GetMoney = function()
		return env._money
	end
	env.GetMoneyString = function(money)
		return "money:" .. tostring(money)
	end

	env.InputUtil = {
		IsGamepadUIEnabled = function()
			return env._gamepad
		end,
	}

	-- ContainerFrameItemButtonTemplate's own art, as Forever's ContainerFrame.xml and the ItemButton
	-- intrinsic make it: the button-state textures and the store highlight are visible by default.
	local createFrame = env.CreateFrame
	env.CreateFrame = function(frameType, name, parent, template)
		local frame = createFrame(frameType, name, parent, template)
		if template == "ContainerFrameItemButtonTemplate" then
			frame:Hide()
			frame:SetNormalTexture(frame:CreateTexture())
			frame:SetPushedTexture(frame:CreateTexture())
			frame:SetHighlightTexture(frame:CreateTexture())
			frame.BattlepayItemTexture = frame:CreateTexture(nil, "OVERLAY")
			frame.NewItemTexture = frame:CreateTexture(nil, "OVERLAY")
			frame.NewItemTexture:SetAlpha(0)
			frame.icon = frame:CreateTexture(nil, "BORDER")
		end
		return frame
	end

	-- Blizzard's bag frames and open state.
	local holder = env.CreateFrame("Frame", "ContainerFrameContainer", env.UIParent)
	local combined = env.CreateFrame("Frame", "ContainerFrameCombinedBags", env.UIParent)
	combined:Hide()
	for i = 1, env.NUM_CONTAINER_FRAMES do
		env.CreateFrame("Frame", "ContainerFrame" .. i, holder):Hide()
	end
	env.BankFrame = env.CreateFrame("Frame", "BankFrame", env.UIParent)
	env.BankFrame:Hide()
	env.MerchantFrame = env.CreateFrame("Frame", "MerchantFrame", env.UIParent)
	env.MerchantFrame:Hide()

	local opener
	local function blizzOpen()
		return combined:IsShown()
	end
	env.ContainerFrame_AllowedToOpenBags = function()
		return env._bagsAllowed
	end
	local function open(frame)
		if not env._bagsAllowed then
			return
		end
		if blizzOpen() then
			return
		end
		if frame and not opener then
			opener = frame:GetName()
		end
		combined:Show()
	end
	local function close(frame)
		if frame and frame:GetName() ~= opener then
			return false
		end
		opener = nil
		local was = combined:IsShown()
		combined:Hide()
		return was
	end
	env.OpenBackpack = function()
		open()
	end
	env.OpenBag = function()
		env.OpenBackpack()
	end
	env.OpenAllBags = function(frame)
		if blizzOpen() then
			return
		end
		if frame and not opener then
			opener = frame:GetName()
		end
		env.OpenBackpack()
		env.OpenBag(5)
	end
	env.CloseBackpack = function()
		local was = combined:IsShown()
		combined:Hide()
		return was
	end
	env.CloseBag = function()
		return env.CloseBackpack()
	end
	env.CloseAllBags = function(frame)
		if frame and frame:GetName() ~= opener then
			return false
		end
		opener = nil
		local closed = env.CloseBackpack()
		for i = 1, 5 do
			closed = env.CloseBag(i) or closed
		end
		return closed
	end
	env.ToggleBackpack = function()
		if not env._bagsAllowed then
			return
		end
		if blizzOpen() then
			combined:Hide()
		else
			env.OpenBackpack()
		end
	end
	env.ToggleBag = function()
		env.ToggleBackpack()
	end
	env.ToggleAllBags = function()
		if not env._bagsAllowed then
			return
		end
		if blizzOpen() then
			env.CloseBackpack()
			env.CloseBag(-1)
			for i = 1, 5 do
				env.CloseBag(i)
			end
			return
		end
		env.OpenBackpack()
		env.OpenBag(5)
	end
	env._blizzClose = close
	env._blizzOpen = blizzOpen

	-- Merchant: MERCHANT_SHOW and MERCHANT_CLOSED, with MerchantFrame shown between them.
	env.SetMerchant = function(shown)
		env._merchant = shown and true or false
		if shown then
			env.MerchantFrame:Show()
			env.FireEvent("MERCHANT_SHOW")
		else
			env.MerchantFrame:Hide()
			env.FireEvent("MERCHANT_CLOSED")
		end
	end
end

-- Enable(env, K) switches the module on and runs the deferred work Safe and Combat scheduled.
function B.Enable(env, K)
	K.Modules.Enable("Bags")
	env.RunTimers()
end

-- New(opts) -> env, KstyleUI, ns. opts: the B.Game options, plus
--   enable   false to leave the module off
--   setup    function(env) that runs after the fake game is installed
function B.New(opts)
	opts = opts or {}
	local env, K = W.New({
		boot = false,
		setup = function(env)
			B.Game(env, opts)
			if opts.setup then
				opts.setup(env)
			end
		end,
	})
	Load(B.Files(), env)
	W.CoreEnv.Boot(env)
	env.RunTimers()
	if opts.enable ~= false then
		B.Enable(env, K)
	end
	return env, K, env._addons.KstyleUI_Bags
end

-- Put(env, bag, slot, item) changes a slot and fires BAG_UPDATE and BAG_UPDATE_DELAYED, as the game does.
function B.Put(env, bag, slot, item)
	local c = env._container(bag)
	c.items = c.items or {}
	c.items[slot] = item
	env._index(item)
	env.FireEvent("BAG_UPDATE", bag)
	env.FireEvent("BAG_UPDATE_DELAYED")
end

-- Shown(frame) is true when the frame and every parent are shown.
function B.Shown(frame)
	return frame:IsVisible() == true
end

return B
