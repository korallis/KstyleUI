-- Inventory.lua: the bag window: the backpack, bags and reagent bag in one grid, the keyring under them, opened and closed with Blizzard's bags.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local Data, Settings, Blizzard, Junk, L = ns.Data, ns.Settings, ns.Blizzard, ns.Junk, ns.L

local Inventory = {}
ns.Inventory = Inventory

Inventory.KEY = "bags.inventory"
Inventory.POSITION = { anchor = "BOTTOMRIGHT", x = -16, y = 134 }

local NONE = {}

local open = false
local heldBags
local keyringBags = {}

local function HeldBags()
	heldBags = heldBags or Data.HeldBags()
	return heldBags
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
	open = false
	Blizzard.Release()
end

local function Refreshed(win)
	win.junkButton:SetShown(Junk.AtMerchant() and Junk.Count() > 0)
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
			{ bags = HeldBags, free = true },
			{ bags = KeyringBags, caption = L["Keyring"] },
		},
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
	open = false
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
Blizzard.OnAction("open", function(blizzardOpen)
	if blizzardOpen and not open then
		Inventory.Open()
	end
end)
Blizzard.OnAction("close", function(blizzardOpen)
	if not blizzardOpen and open then
		Inventory.Close()
	end
end)

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

function Inventory.Enable()
	local window = Inventory.Build()
	if not InCombatLockdown() then
		window:Prepare()
	end
	window:Layout(true)
end

function Inventory.Disable()
	open = false
	local window = Inventory.window
	if window then
		window:Hide()
	end
end

function Inventory.SettingsChanged()
	local window = Inventory.window
	if not window or not K.Modules.IsRunning(Settings.MODULE) then
		return
	end
	if open then
		window:Refresh(true)
	else
		Prepare()
		window:Layout(true)
	end
end
