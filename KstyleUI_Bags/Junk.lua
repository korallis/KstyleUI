-- Junk.lua: sells junk at a merchant, by the bag window's button or by itself, only out of combat through Combat.Queue.
local _, ns = ...

local K = KstyleUI
local Data, Settings, L = ns.Data, ns.Settings, ns.L

local Junk = {}
ns.Junk = Junk

Junk.BATCH = 10
Junk.BATCH_DELAY = 0.25

local EXCLUDE_FLAG_FALLBACK = 64

local atMerchant = false
local selling = false
local visit = 0
local probe = {}

local function Flag(value)
	return not Data.IsSecret(value) and value == true
end

local function Excluded(bag)
	local container = C_Container
	if not container then
		return false
	end
	if bag == 0 then
		local disabled = container.GetBackpackSellJunkDisabled
		return type(disabled) == "function" and Flag(disabled())
	end
	local getFlag = container.GetBagSlotFlag
	if type(getFlag) ~= "function" then
		return false
	end
	local flags = Enum and Enum.BagSlotFlags
	local ok, set = pcall(getFlag, bag, (flags and flags.ExcludeJunkSell) or EXCLUDE_FLAG_FALLBACK)
	return ok and Flag(set)
end

function Junk.Each(fn)
	local keyring = Data.KeyringBag()
	for _, bag in ipairs(Data.HeldBags()) do
		if bag ~= keyring and not Excluded(bag) then
			for slot = 1, Data.NumSlots(bag) do
				local record = Data.Read(bag, slot, probe)
				if record.junk and not record.locked then
					if fn(bag, slot) == false then
						return
					end
				end
			end
		end
	end
end

function Junk.Count()
	local merchant = C_MerchantFrame
	if merchant and type(merchant.GetNumJunkItems) == "function" then
		local count = Data.Plain(merchant.GetNumJunkItems(), "number")
		if count then
			return count
		end
	end
	local count = 0
	Junk.Each(function()
		count = count + 1
	end)
	return count
end

function Junk.AtMerchant()
	return atMerchant
end

local function ServerSell()
	local merchant = C_MerchantFrame
	if not merchant or type(merchant.SellAllJunkItems) ~= "function" then
		return false
	end
	if type(merchant.IsSellAllJunkEnabled) == "function" and not Flag(merchant.IsSellAllJunkEnabled()) then
		return false
	end
	merchant.SellAllJunkItems()
	ns.Log("sold junk with C_MerchantFrame.SellAllJunkItems")
	return true
end

local SellBatch

local function Current(id)
	return atMerchant and id == visit
end

local function NextBatch(id)
	K.Combat.Queue(function()
		SellBatch(id)
	end)
end

function SellBatch(id)
	if not Current(id) then
		return
	end
	if InCombatLockdown() then
		NextBatch(id)
		return
	end
	local container = C_Container
	if not container or type(container.UseContainerItem) ~= "function" then
		selling = false
		return
	end
	local sold, more = 0, false
	Junk.Each(function(bag, slot)
		if sold >= Junk.BATCH then
			more = true
			return false
		end
		container.UseContainerItem(bag, slot)
		sold = sold + 1
	end)
	if more then
		C_Timer.After(Junk.BATCH_DELAY, function()
			NextBatch(id)
		end)
	else
		selling = false
	end
end

function Junk.Sell()
	if not atMerchant then
		return false
	end
	if InCombatLockdown() then
		K.Print(L["Junk sells when combat ends."])
	end
	local id = visit
	K.Combat.Queue(function()
		if not Current(id) or selling then
			return
		end
		if ServerSell() then
			return
		end
		ns.Log("C_MerchantFrame.SellAllJunkItems is missing or off; selling junk item by item")
		selling = true
		SellBatch(id)
	end)
	return true
end

local function NewVisit(shown)
	visit = visit + 1
	atMerchant = shown
	selling = false
end

ns.On("MERCHANT_SHOW", function()
	NewVisit(true)
	if Settings.Get("autoSellJunk") then
		Junk.Sell()
	end
	if Junk.onChange then
		Junk.onChange()
	end
end)

ns.On("MERCHANT_CLOSED", function()
	NewVisit(false)
	if Junk.onChange then
		Junk.onChange()
	end
end)

function Junk.Enable()
	local frame = MerchantFrame
	local shown = frame and frame:IsShown()
	NewVisit(not Data.IsSecret(shown) and shown == true)
end

function Junk.Disable()
	NewVisit(false)
end
