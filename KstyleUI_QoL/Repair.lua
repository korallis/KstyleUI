-- Repair.lua: auto repair at a repair merchant, from guild funds first when the player asks and the guild covers the whole bill, then from the player's money, with the cost in chat.
local _, ns = ...

local K, L = ns.K, ns.L
local format, min = string.format, math.min

local UNLIMITED = -1

local function Money(copper)
	if type(GetMoneyString) == "function" then
		return GetMoneyString(copper, true)
	end
	local currency = C_CurrencyInfo
	if currency and type(currency.GetCoinTextureString) == "function" then
		return currency.GetCoinTextureString(copper)
	end
	return tostring(copper)
end

local function GuildCovers(cost)
	if not ns.Get("guildRepair") or not ns.True(IsInGuild()) or not ns.True(CanGuildBankRepair()) then
		return false
	end
	local limit, bank = ns.Number(GetGuildBankWithdrawMoney()), ns.Number(GetGuildBankMoney())
	if not limit or not bank then
		return false
	end
	if limit == UNLIMITED then
		limit = bank
	else
		limit = min(limit, bank)
	end
	return limit >= cost
end

local function OnMerchant()
	if not ns.Get("autoRepair") or not ns.True(CanMerchantRepair()) then
		return
	end
	local cost, canRepair = GetRepairAllCost()
	cost = ns.Number(cost)
	if not cost or cost <= 0 or not ns.True(canRepair) then
		return
	end
	if GuildCovers(cost) then
		RepairAllItems(true)
		K.Print(format(L["Repaired for %s from guild funds."], Money(cost)))
		return
	end
	local money = ns.Number(GetMoney())
	if money and money >= cost then
		RepairAllItems()
		K.Print(format(L["Repaired for %s."], Money(cost)))
	else
		K.Print(format(L["Repairs cost %s, more than you have."], Money(cost)))
	end
end

ns.AddPart({
	name = "repair",
	events = { MERCHANT_SHOW = OnMerchant },
})
