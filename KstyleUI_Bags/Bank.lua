-- Bank.lua: the bank window: each bank type's purchased tabs in the same sections as the bags, its bank bags, Sort, Buy and Deposit, opened and closed with the bank.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Data, Settings, Slot, Inventory, L = ns.Data, ns.Settings, ns.Slot, ns.Inventory, ns.L
local max, min = math.max, math.min

local Bank = {}
ns.Bank = Bank

Bank.KEY = "bags.bank"
Bank.POSITION = { anchor = "TOPLEFT", x = 60, y = -110 }
Bank.PURCHASE_TEMPLATE = "BankPanelPurchaseButtonScriptTemplate"

local CHARACTER_FALLBACK, ACCOUNT_FALLBACK = 0, 2
local BAG_SLOTS_FALLBACK = { character = -2, account = -3 }
local FIRST_TAB_FALLBACK = 6
local TABS_FALLBACK = 9
local RESTORE_OWNER = "Bags.Bank"
local NONE = {}

local replaced = false
local afterVisit
local atBank = false
local open = false
local openedBags = false
local bankType
local tabLists = {}

local function Types()
	local types = Enum and Enum.BankType
	local character = Data.Plain(types and types.Character, "number") or CHARACTER_FALLBACK
	local account = Data.Plain(types and types.Account, "number") or ACCOUNT_FALLBACK
	return character, account
end

local function BagSlotsContainer()
	local index = Enum and Enum.BagIndex
	local _, account = Types()
	if bankType == account then
		return Data.Plain(index and index.Accountbanktab, "number") or BAG_SLOTS_FALLBACK.account
	end
	return Data.Plain(index and index.Characterbanktab, "number") or BAG_SLOTS_FALLBACK.character
end

local function Call(name, ...)
	local bank = C_Bank
	local fn = bank and bank[name]
	if type(fn) ~= "function" then
		return nil
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		ns.Log("C_Bank." .. name .. " failed: " .. tostring(result))
		return nil
	end
	return result
end

local function Flag(name, ...)
	local value = Call(name, ...)
	return not Data.IsSecret(value) and value == true
end

local function CanView(kind)
	return Flag("CanViewBank", kind)
end

local function Count(name, kind)
	return Data.Plain(Call(name, kind), "number") or 0
end

local function TabBags(kind)
	local list = tabLists[kind]
	if not list then
		list = {}
		tabLists[kind] = list
	end
	for i = #list, 1, -1 do
		list[i] = nil
	end
	local ids = Call("FetchPurchasedBankTabIDs", kind)
	if type(ids) == "table" and not Data.IsSecret(ids) then
		for _, id in ipairs(ids) do
			id = Data.Plain(id, "number")
			if id then
				list[#list + 1] = id
			end
		end
		return list
	end
	local tabs = Call("FetchPurchasedBankTabData", kind)
	if type(tabs) == "table" and not Data.IsSecret(tabs) then
		for _, tab in ipairs(tabs) do
			local id = type(tab) == "table" and Data.Plain(tab.ID, "number")
			if id then
				list[#list + 1] = id
			end
		end
		return list
	end
	local character = Types()
	if kind == character then
		local index = Enum and Enum.BagIndex
		local first = Data.Plain(index and index.CharacterBankTab_1, "number") or FIRST_TAB_FALLBACK
		for bag = first, first + TABS_FALLBACK - 1 do
			if Data.NumSlots(bag) > 0 then
				list[#list + 1] = bag
			end
		end
	end
	return list
end

function Bank.Types()
	return Types()
end

function Bank.CanView(kind)
	return CanView(kind)
end

function Bank.Tabs(kind)
	return TabBags(kind)
end

function Bank.IsAtBank()
	return atBank
end

local function SelectedBags()
	if not bankType then
		return NONE
	end
	return TabBags(bankType)
end

local function FirstType()
	local character, account = Types()
	if CanView(character) then
		return character
	elseif CanView(account) then
		return account
	end
	return character
end

function Bank.Sort()
	local kind = bankType or FirstType()
	if InCombatLockdown() then
		K.Print(L["Sorting waits until combat ends."])
	end
	K.Combat.Queue(function()
		local container = C_Container
		local character, account = Types()
		if not container then
			return
		end
		if type(container.SortBank) == "function" then
			container.SortBank(kind)
		elseif kind == character and type(container.SortBankBags) == "function" then
			container.SortBankBags()
		elseif kind == account and type(container.SortAccountBankBags) == "function" then
			container.SortAccountBankBags()
		else
			ns.Log("no bank sort API for bank type " .. tostring(kind))
		end
	end)
end

local function Deposit()
	local kind = bankType
	K.Combat.Queue(function()
		if Flag("DoesBankTypeSupportAutoDeposit", kind) then
			Call("AutoDepositItemsIntoBank", kind)
		end
	end)
end

local function PickupBag(button)
	if InCombatLockdown() then
		return
	end
	local container = C_Container
	if container and type(container.PickupContainerItem) == "function" then
		container.PickupContainerItem(BagSlotsContainer(), button:GetID())
	end
end

local function BagTooltip(button)
	local tooltip = GameTooltip
	if not tooltip or type(tooltip.SetOwner) ~= "function" then
		return
	end
	tooltip:SetOwner(button, "ANCHOR_RIGHT")
	local shown = type(tooltip.SetBagItem) == "function" and tooltip:SetBagItem(BagSlotsContainer(), button:GetID())
	if not shown then
		tooltip:SetText(BANK_BAG or L["Bank bag"])
	end
	tooltip:Show()
end

local function HideTooltip()
	if type(GameTooltip_Hide) == "function" then
		GameTooltip_Hide()
	end
end

local function NewBagSlot(parent, id)
	local slot = Slot.New(parent, id)
	local button = slot.button
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnClick", PickupBag)
	button:SetScript("OnDragStart", PickupBag)
	button:SetScript("OnReceiveDrag", PickupBag)
	button:HookScript("OnEnter", BagTooltip)
	button:HookScript("OnLeave", HideTooltip)
	return slot
end

local function UpdateBankBags(win)
	local strip = win.bankBags
	local kind = bankType or FirstType()
	local maxTabs = min(Count("FetchMaxNumBankTabs", kind), TABS_FALLBACK)
	local purchased = Count("FetchNumPurchasedBankTabs", kind)
	strip.count = 0
	local shown = Flag("ShouldUsePlayerBagsInBank") and maxTabs > 1
	if shown then
		for id = 2, maxTabs do
			local index = id - 1
			local slot = strip.slots[index]
			if not slot then
				slot = NewBagSlot(strip.frame, id)
				strip.slots[index] = slot
			end
			local bought = id <= purchased
			slot.button:SetShown(bought)
			if bought then
				strip.count = strip.count + 1
				local record = Data.Read(BagSlotsContainer(), id, slot.record)
				Slot.Update(slot, record, nil, true)
			end
		end
	end
	for index = max(1, maxTabs), #strip.slots do
		strip.slots[index].button:Hide()
	end
	strip.frame:SetShown(shown and strip.count > 0)
end

local function UpdateButtons(win)
	local kind = bankType or FirstType()
	local buy = win.buyButton
	buy:SetAttribute("overrideBankType", kind)
	buy:SetShown(Flag("CanPurchaseBankTab", kind))
	win.depositButton:SetShown(Flag("DoesBankTypeSupportAutoDeposit", kind))
	local character, account = Types()
	win.tabs:SetShown(CanView(character) and CanView(account))
end

local function Above(win, content, top, width)
	local tabs = win.tabs
	if not tabs:IsShown() then
		return top
	end
	tabs:ClearAllPoints()
	tabs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
	return top + Widgets.Snap(win.panel, (Data.Plain(tabs:GetHeight(), "number") or Tokens.Size("rowHeight")) + Tokens.Size("gapMedium"))
end

local function Below(win, content, top, width)
	local strip = win.bankBags
	if not strip.frame:IsShown() then
		return top
	end
	local size = Widgets.Snap(win.panel, Tokens.Size("rowHeight"))
	local gap = Widgets.Snap(win.panel, Tokens.Size("gapSmall"))
	strip.frame:ClearAllPoints()
	strip.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
	strip.frame:SetSize(max(1, width), size)
	local x = 0
	for _, slot in ipairs(strip.slots) do
		if slot.button:IsShown() then
			Slot.Layout(slot, size)
			slot.button:ClearAllPoints()
			slot.button:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", x, 0)
			x = x + size + gap
		end
	end
	return top + size + Widgets.Snap(win.panel, Tokens.Size("gapMedium"))
end

local function Refreshed(win)
	UpdateButtons(win)
	UpdateBankBags(win)
end

local function Closed()
	local wasOpen = open
	open = false
	if wasOpen and atBank then
		Call("CloseBankFrame")
	end
end

function Bank.SelectType(kind)
	if kind == bankType then
		return
	end
	bankType = kind
	local window = Bank.window
	if window and open then
		window:Refresh(true)
	end
end

function Bank.Build()
	if Bank.window then
		return Bank.window
	end
	local character, account = Types()
	local win = ns.Window.New({
		key = Bank.KEY,
		label = L["Bank window"],
		title = L["Bank"],
		position = Bank.POSITION,
		columns = "bankColumns",
		sections = { { bags = SelectedBags, free = true, categories = true } },
		sort = Bank.Sort,
		onClosed = Closed,
		above = Above,
		below = Below,
		refresh = Refreshed,
	})
	local panel = win.panel
	win.tabs = Widgets.Tabs(panel, {
		tabs = { { value = character, label = L["Bank"] }, { value = account, label = L["Warband"] } },
		value = character,
		onSelect = Bank.SelectType,
	})
	win.tabs:Hide()
	win.buyButton = win:AddButton(Widgets.Button(panel, { text = L["Buy tab"], template = Bank.PURCHASE_TEMPLATE }))
	win.buyButton:Hide()
	win.depositButton = win:AddButton(Widgets.Button(panel, { text = L["Deposit all"], onClick = Deposit }))
	win.depositButton:Hide()
	local strip = { frame = CreateFrame("Frame", nil, panel), slots = {}, count = 0 }
	strip.frame:Hide()
	win.bankBags = strip
	Bank.window = win
	return win
end

function Bank.Slot(bag, slot)
	local window = Bank.window
	return window and window:Slot(bag, slot)
end

function Bank.IsOpen()
	return open
end

function Bank.Open()
	local window = Bank.window
	if not window then
		return
	end
	bankType = bankType or FirstType()
	if not CanView(bankType) then
		bankType = FirstType()
	end
	window.tabs:Select(bankType, true)
	open = true
	window:Open()
end

local function Opened()
	atBank = true
	if not replaced or not Bank.window or afterVisit == "hide" then
		return
	end
	bankType = FirstType()
	Bank.Open()
	if Settings.Get("bankOpensBags") and not Inventory.IsOpen() then
		Inventory.Open()
		openedBags = true
	end
end

local function GameClosed()
	atBank = false
	local window = Bank.window
	if window and open then
		window:Close()
	end
	open = false
	if openedBags then
		openedBags = false
		if Inventory.IsOpen() then
			Inventory.Close()
		end
	end
end

local function Refresh()
	local window = Bank.window
	if window and open then
		window:Refresh()
	end
end

local function InfoArrived()
	local window = Bank.window
	if window and open then
		window:RefreshSoon()
	end
end

local BANKERS = { "Banker", "CharacterBanker", "AccountBanker" }

local function IsBanker(kind)
	kind = Data.Plain(kind, "number")
	local types = Enum and Enum.PlayerInteractionType
	if not kind or not types then
		return false
	end
	for _, name in ipairs(BANKERS) do
		if types[name] == kind then
			return true
		end
	end
	return false
end

ns.On("BANKFRAME_OPENED", Opened)
ns.On("BANKFRAME_CLOSED", GameClosed)
ns.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
	if IsBanker(kind) and not atBank then
		ns.Log("the bank opened without BANKFRAME_OPENED; following PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
		Opened()
	end
end)
ns.On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind)
	if IsBanker(kind) and atBank then
		GameClosed()
	end
end)
ns.On("BAG_UPDATE_DELAYED", Refresh)
ns.On("BAG_CONTAINER_UPDATE", Refresh)
ns.On("BANK_TABS_CHANGED", Refresh)
ns.On("PLAYERBANKSLOTS_CHANGED", Refresh)
ns.On("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", Refresh)
ns.On("GET_ITEM_INFO_RECEIVED", InfoArrived)
ns.On("BAG_UPDATE_COOLDOWN", function()
	local window = Bank.window
	if window and open then
		window:UpdateCooldowns()
	end
end)
ns.On("PLAYER_MONEY", function()
	local window = Bank.window
	if window then
		window:UpdateMoney()
	end
end)
ns.On("ITEM_LOCK_CHANGED", function(_, bag, slot)
	local window = Bank.window
	if window and open and bag and slot then
		window:UpdateLock(bag, slot)
	end
end)

function Bank.IsReplaced()
	return replaced
end

function Bank.WaitingForVisit()
	return afterVisit ~= nil
end

local function BlizzardBankShown()
	local frame = BankFrame
	if not frame then
		return false
	end
	local shown = frame:IsShown()
	return not Data.IsSecret(shown) and shown == true
end

local function VisitEnded()
	K.Events.Unregister(RESTORE_OWNER, "BANKFRAME_CLOSED")
	local action = afterVisit
	afterVisit = nil
	if action == "hide" then
		K.Safe.HideBlizzard(BankFrame)
	elseif action == "restore" then
		K.Safe.RestoreBlizzard(BankFrame)
	end
end

local function AfterVisit(action)
	afterVisit = action
	K.Events.Register(RESTORE_OWNER, "BANKFRAME_CLOSED", VisitEnded)
end

function Bank.Enable()
	replaced = Settings.Get("replaceBank")
	if not replaced then
		ns.Log("Replace bank is off; Blizzard's bank stays")
		return
	end
	Bank.Build()
	if BlizzardBankShown() then
		AfterVisit("hide")
		ns.Log("Blizzard's bank is open; KstyleUI's bank takes over after this visit")
	else
		afterVisit = nil
		K.Safe.HideBlizzard(BankFrame)
	end
end

function Bank.Disable()
	local window = Bank.window
	if window and open then
		Call("CloseBankFrame")
	end
	open = false
	openedBags = false
	if window then
		window:Hide()
	end
	if not replaced then
		return
	end
	replaced = false
	atBank = false
	if afterVisit == "hide" then
		K.Events.Unregister(RESTORE_OWNER, "BANKFRAME_CLOSED")
		afterVisit = nil
		return
	end
	if BlizzardBankShown() then
		AfterVisit("restore")
		ns.Log("Blizzard's bank returns when this bank visit ends")
	else
		K.Safe.RestoreBlizzard(BankFrame)
	end
end

function Bank.SettingsChanged(key)
	if key == "replaceBank" then
		K.Print(L["The bank change takes effect after you type /reload."])
		local prompt = Widgets.ReloadPrompt
		if type(prompt) == "function" then
			K.Call(prompt, L["The bank window changes after a reload."])
		end
		return
	end
	local window = Bank.window
	if window and open then
		window:Refresh(true)
	elseif window then
		window:Layout(true)
	end
end
