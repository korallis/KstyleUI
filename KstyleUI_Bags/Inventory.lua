-- Inventory.lua: the bag window: the backpack, bags and reagent bag in one grid, the keyring under them, opened and closed with Blizzard's bags and, when asked, the character window.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local Data, Settings, Blizzard, Junk, Slot, L = ns.Data, ns.Settings, ns.Blizzard, ns.Junk, ns.Slot, ns.L
local max = math.max

local Inventory = {}
ns.Inventory = Inventory

Inventory.KEY = "bags.inventory"
Inventory.POSITION = { anchor = "BOTTOMRIGHT", x = -16, y = 134 }

local NONE = {}
local PICKER_WIDTH = 132

local open, opened = false, false
local owner
local heldBags
local keyringBags, mainBags, reagentBags = {}, {}, {}

local function HeldBags()
	heldBags = heldBags or Data.HeldBags()
	if not Settings.ReagentApart() then
		return heldBags
	end
	local reagent = Data.ReagentBag()
	for i = #mainBags, 1, -1 do
		mainBags[i] = nil
	end
	for _, bag in ipairs(heldBags) do
		if bag ~= reagent then
			mainBags[#mainBags + 1] = bag
		end
	end
	return mainBags
end

local function ReagentBags()
	if not Settings.ReagentApart() then
		return NONE
	end
	reagentBags[1] = Data.ReagentBag()
	return reagentBags
end

local function BagInventoryID(bag)
	local container = C_Container
	local id = container and type(container.ContainerIDToInventoryID) == "function" and container.ContainerIDToInventoryID(bag)
	return Data.Plain(id, "number")
end

local function SwapBag(button)
	local id = BagInventoryID(button:GetID())
	if not id or InCombatLockdown() then
		return
	end
	if Data.CursorItem() and type(PutItemInBag) == "function" then
		PutItemInBag(id)
	elseif type(PickupBagFromSlot) == "function" then
		PickupBagFromSlot(id)
	end
end

local function BagTooltip(button)
	local tooltip, id = GameTooltip, BagInventoryID(button:GetID())
	if not tooltip or type(tooltip.SetOwner) ~= "function" or not id then
		return
	end
	tooltip:SetOwner(button, "ANCHOR_RIGHT")
	if type(tooltip.SetInventoryItem) ~= "function" or not tooltip:SetInventoryItem("player", id) then
		tooltip:SetText(L["Empty bag slot"])
	end
	tooltip:Show()
end

local function BagStrip(win, content, top, width)
	local strip = win.bagStrip
	if not Settings.Get("bagSlots") or win:Browsing() then
		if strip then
			strip.frame:Hide()
		end
		return top
	end
	if not strip then
		strip = { frame = CreateFrame("Frame", nil, win.panel), slots = {} }
		win.bagStrip = strip
	end
	local size = Widgets.Snap(win.panel, K.Tokens.Size("rowHeight"))
	local gap = Widgets.Snap(win.panel, K.Tokens.Size("gapSmall"))
	strip.frame:ClearAllPoints()
	strip.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
	strip.frame:SetSize(max(1, width), size)
	strip.frame:Show()
	local x, index = 0, 0
	for _, bag in ipairs(heldBags or Data.HeldBags()) do
		local id = bag ~= BACKPACK_CONTAINER and BagInventoryID(bag)
		if id then
			index = index + 1
			local slot = strip.slots[index]
			if not slot then
				slot = Slot.New(strip.frame, bag)
				slot.button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				slot.button:RegisterForDrag("LeftButton")
				slot.button:SetScript("OnClick", SwapBag)
				slot.button:SetScript("OnDragStart", SwapBag)
				slot.button:SetScript("OnReceiveDrag", SwapBag)
				slot.button:HookScript("OnEnter", BagTooltip)
				slot.button:HookScript("OnLeave", function()
					if type(GameTooltip_Hide) == "function" then
						GameTooltip_Hide()
					end
				end)
				strip.slots[index] = slot
			end
			local icon = type(GetInventoryItemTexture) == "function" and GetInventoryItemTexture("player", id)
			local quality = type(GetInventoryItemQuality) == "function" and GetInventoryItemQuality("player", id)
			local record = slot.record
			record.icon = Data.Plain(icon, "number") or Data.Plain(icon, "string")
			record.empty, record.quality = record.icon == nil, Data.Plain(quality, "number")
			Slot.Layout(slot, size)
			slot.button:ClearAllPoints()
			slot.button:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", x, 0)
			Slot.Update(slot, record, nil, true)
			x = x + size + gap
		end
	end
	return top + size + Widgets.Snap(win.panel, K.Tokens.Size("gapMedium"))
end

local function KeyringBags()
	if not Settings.Get("showKeyring") then
		return NONE
	end
	local keyring = Data.KeyringBag()
	if keyring and Data.NumSlots(keyring) > 0 then
		keyringBags[1] = keyring
		return keyringBags
	end
	return NONE
end

function Inventory.Sort()
	if InCombatLockdown() then
		K.Print(L["Sorting waits until combat ends."])
	end
	K.Combat.Queue(function()
		local container = C_Container
		if not container or type(container.SortBags) ~= "function" then
			ns.Log("C_Container.SortBags is missing; Sort does nothing")
			return
		end
		if type(container.SetSortBagsRightToLeft) == "function" then
			container.SetSortBagsRightToLeft(Settings.Get("sortDirection") == "RIGHT")
		end
		container.SortBags()
	end)
end

local function Closed()
	open, opened, owner = false, false, nil
	Blizzard.Release()
end

local function Characters()
	local alts = ns.Alts
	if not alts or type(alts.Characters) ~= "function" then
		return NONE
	end
	return alts.Characters()
end

local function PickerOptions()
	local options = {}
	for _, character in ipairs(Characters()) do
		options[#options + 1] = { value = character.key, label = character.own and L["This character"] or character.name }
	end
	return options
end

local function OwnKey()
	for _, character in ipairs(Characters()) do
		if character.own then
			return character.key
		end
	end
	return nil
end

local function Refreshed(win)
	local atMerchant = Junk.AtMerchant()
	local hasJunk = atMerchant and Junk.Count() > 0
	win.junkButton:SetShown(win:Browsing() == nil and atMerchant and (not Settings.Get("compactBags") or hasJunk))
	win.junkButton:SetEnabled(hasJunk)
	local recent = win.sections[1].groups.recent
	win.clearButton:SetShown(win:Browsing() == nil and Settings.Get("recentClear") and recent ~= nil and recent.total > 0)
	local picker = win.picker
	if picker then
		local characters = Characters()
		picker:SetShown(#characters > 1)
		picker:SetValue(win:Browsing() or OwnKey(), true)
	end
end

function Inventory.Build()
	if Inventory.window then
		return Inventory.window
	end
	Inventory.window = ns.Window.New({
		key = Inventory.KEY,
		label = L["Bag window"],
		title = L["Bags"],
		position = Inventory.POSITION,
		sections = {
			{ bags = HeldBags, free = true, categories = true },
			{ bags = KeyringBags, caption = L["Keyring"] },
			{ bags = ReagentBags, free = true, caption = L["Reagent bag"], lazy = true },
		},
		recent = true,
		currencies = true,
		below = BagStrip,
		sort = Inventory.Sort,
		onClosed = Closed,
		refresh = Refreshed,
	})
	local win = Inventory.window
	win.junkButton = win:AddButton(Widgets.Button(win.panel, {
		text = L["Sell junk"],
		onClick = function()
			Junk.Sell()
		end,
	}))
	win.junkButton:Hide()
	win.clearButton = win:AddButton(Widgets.Button(win.panel, {
		text = L["Clear recent"],
		onClick = function()
			win:ClearNew()
			win:Refresh()
		end,
	}))
	win.clearButton:Hide()
	win.picker = win:AddButton(Widgets.Dropdown(win.panel, {
		width = PICKER_WIDTH,
		height = K.Tokens.Size("rowHeight") + K.Tokens.Size("gapSmall"),
		options = PickerOptions,
		tooltip = L["Browse another character's saved bags and bank, read-only."],
		onChange = function(value)
			if value == OwnKey() then
				win:Browse(nil)
			elseif not win:Browse(value) then
				win.picker:SetValue(OwnKey(), true)
			end
		end,
	}))
	win.picker:Hide()
	return win
end

function Inventory.Slot(bag, slot)
	local window = Inventory.window
	return window and window:Slot(bag, slot)
end

function Inventory.IsOpen()
	return open
end

function Inventory.Open()
	local window = Inventory.window
	if not window then
		return
	end
	open = true
	window:Open()
end

function Inventory.Close()
	local window = Inventory.window
	if window and open then
		window:Close()
	end
	open, opened = false, false
end

function Inventory.Toggle()
	if open then
		Inventory.Close()
	elseif Blizzard.MayOpen() then
		Inventory.Open()
	end
end

local function Refresh()
	local window = Inventory.window
	if window and open then
		window:Refresh()
	end
end

local function Prepare()
	local window = Inventory.window
	if not window then
		return
	end
	if open then
		window:Refresh()
	elseif not InCombatLockdown() then
		window:Prepare()
	end
end

local function InfoArrived()
	local window = Inventory.window
	if window and open then
		window:RefreshSoon()
	end
end

Junk.onChange = function()
	local window = Inventory.window
	if not window then
		return
	end
	if open then
		window:Refresh()
	else
		Refreshed(window)
	end
end

Blizzard.OnAction("toggle", function()
	Inventory.Toggle()
end)
local SOURCES = { merchant = { "MerchantFrame" }, mail = { "MailFrame" }, auction = { "AuctionHouseFrame", "AuctionFrame" } }

local function Auto(source)
	if type(source) ~= "table" then
		return "both"
	end
	for kind, names in pairs(SOURCES) do
		for _, name in ipairs(names) do
			if source == _G[name] then
				return Settings.Get(Settings.AUTO[kind])
			end
		end
	end
	return "both"
end

Blizzard.OnAction("open", function(blizzardOpen, source)
	if blizzardOpen and not open and Auto(source) ~= "none" then
		Inventory.Open()
	end
end)
Blizzard.OnAction("close", function(blizzardOpen, source)
	if not blizzardOpen and open and Auto(source) == "both" then
		Inventory.Close()
	end
end)

local SHOWN = { MERCHANT_SHOW = "merchant", MAIL_SHOW = "mail", TRADE_SHOW = "trade", AUCTION_HOUSE_SHOW = "auction", BANKFRAME_OPENED = "bank", LOOT_OPENED = "loot", QUEST_DETAIL = "quest", QUEST_PROGRESS = "quest", QUEST_COMPLETE = "quest", QUEST_GREETING = "quest" }
local CLOSED = { MERCHANT_CLOSED = "merchant", MAIL_CLOSED = "mail", TRADE_CLOSED = "trade", AUCTION_HOUSE_CLOSED = "auction", BANKFRAME_CLOSED = "bank", LOOT_CLOSED = "loot", QUEST_FINISHED = "quest" }
local OURS = { trade = true, loot = true, quest = true }
local BUSY = { merchant = true, mail = true, trade = true, auction = true, bank = true }
local busy = {}

function ns.Busy()
	return next(busy) ~= nil or (ns.Bank ~= nil and ns.Bank.IsAtBank())
end

local function BusyChanged(kind, on)
	if BUSY[kind] and busy[kind] ~= on then
		busy[kind] = on
		local window = Inventory.window
		if window and open and Settings.Get("mergeStacks") then
			window:Refresh()
		end
	end
end

for event, kind in pairs(SHOWN) do
	ns.On(event, function()
		if OURS[kind] and not open and Blizzard.IsActive() and Settings.Get(Settings.AUTO[kind]) ~= "none" and Blizzard.MayOpen() then
			Inventory.Open()
			owner = kind
		end
		BusyChanged(kind, true)
	end)
end
for event, kind in pairs(CLOSED) do
	ns.On(event, function()
		if owner == kind then
			owner = nil
			if open and Settings.Get(Settings.AUTO[kind]) == "both" then
				Inventory.Close()
			end
		end
		BusyChanged(kind, nil)
	end)
end

ns.On("BAG_UPDATE_DELAYED", Refresh)
ns.On("BAG_NEW_ITEMS_UPDATED", Refresh)
ns.On("BAG_CONTAINER_UPDATE", Prepare)
ns.On("GET_ITEM_INFO_RECEIVED", InfoArrived)
ns.On("PLAYER_MONEY", function()
	local window = Inventory.window
	if window then
		window:UpdateMoney()
	end
end)
ns.On("ITEM_LOCK_CHANGED", function(_, bag, slot)
	local window = Inventory.window
	if window and open and bag and slot then
		window:UpdateLock(bag, slot)
	end
end)
ns.On("BAG_UPDATE_COOLDOWN", function()
	local window = Inventory.window
	if window and open then
		window:UpdateCooldowns()
	end
end)
ns.On("CURRENCY_DISPLAY_UPDATE", function()
	local window = Inventory.window
	if window and open then
		window:UpdateCurrencies()
	end
end)
ns.On("EQUIPMENT_SETS_CHANGED", function()
	Data.SetsChanged()
	if Settings.Get("setNames") or Settings.Get("splitSets") then
		Refresh()
	end
end)

local watching = false

local function WatchCharacter()
	local on, frame = Settings.Get("characterBags"), CharacterFrame
	opened = opened and on
	if watching or not on or type(frame) ~= "table" or type(frame.HookScript) ~= "function" then
		return
	end
	watching = true
	frame:HookScript("OnShow", function()
		if not open and Blizzard.IsActive() and Settings.Get("characterBags") and Blizzard.MayOpen() then
			opened = true
			Inventory.Open()
		end
	end)
	frame:HookScript("OnHide", function()
		if opened then Inventory.Close() end
	end)
end

function Inventory.Enable()
	WatchCharacter()
	local window = Inventory.Build()
	if not InCombatLockdown() then
		window:Prepare()
	end
	window:Layout(true)
end

function Inventory.Disable()
	open, opened, owner = false, false, nil
	for kind in pairs(busy) do
		busy[kind] = nil
	end
	local window = Inventory.window
	if window then
		window:Hide()
	end
end

function Inventory.SettingsChanged(key)
	WatchCharacter()
	local window = Inventory.window
	if not window or not K.Modules.IsRunning(Settings.MODULE) then
		return
	end
	if key == "nearestCorner" and Settings.Get("nearestCorner") then
		window:SavePosition()
	end
	if open then
		window:Refresh(true)
	else
		Prepare()
		window:Layout(true)
	end
end
