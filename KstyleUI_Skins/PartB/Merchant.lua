-- Merchant.lua: the merchant skin: the vendor and buyback pages, item rows with quality tiles, repair and junk buttons, and the page arrows.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Kit = ns.PartBKit
local Skin = K.Skin

local WINDOW = "merchant"
local MAX_ITEMS = 12

local function Item(button)
	Kit.Item(button, { window = WINDOW })
end

local function Slot(slot)
	Skin.Strip(slot)
	Skin.Backdrop(slot, { shape = "tile", fill = "buttonFill", shadow = false })
	Item(slot.ItemButton)
end

local function Apply()
	local frame = MerchantFrame
	if not Kit.Have(frame, "MerchantFrame") then
		return false
	end
	Kit.Window(frame)
	for i = 1, MAX_ITEMS do
		local slot = _G["MerchantItem" .. i]
		if slot == nil then
			break
		end
		Slot(slot)
	end
	if MerchantBuyBackItem then
		Slot(MerchantBuyBackItem)
	end
	Item(MerchantSellAllJunkButton)
	Item(MerchantRepairAllButton)
	Item(MerchantRepairItemButton)
	Item(MerchantGuildBankRepairButton)
	Kit.Inset(MerchantExtraCurrencyInset)
	Skin.Strip(MerchantExtraCurrencyBg)
	Kit.Inset(MerchantMoneyInset)
	Skin.Strip(MerchantMoneyBg)
	Kit.Arrow(MerchantPrevPageButton, "left")
	Kit.Arrow(MerchantNextPageButton, "right")
	Kit.Dropdown(frame.FilterDropdown)
	return true
end

ns.Skins.Add({
	key = WINDOW,
	label = L["Merchant"],
	help = L["Restyles the vendor window and its buyback page."],
	addon = "Blizzard_UIPanels_Game",
	frame = "MerchantFrame",
	defaults = { qualityRims = true },
	rows = {
		{ type = "toggle", key = "qualityRims", label = L["Quality rims"], help = L["Rings each item in the item's quality colour."] },
	},
	Apply = Apply,
})
