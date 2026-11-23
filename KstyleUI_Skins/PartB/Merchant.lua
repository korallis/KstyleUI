-- Merchant.lua: the merchant skin: the vendor and buyback pages, item rows on glass tiles with quality-rimmed icons, repair and junk buttons, and the page arrows.
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

local function NameSize()
	local _, size = K.Tokens.NoteFont()
	return size * ns.Style.Setting("text", "size")
end

local function PriceText(frame)
	if type(frame.GetObjectType) == "function" and frame:GetObjectType() == "FontString" then
		ns.Style.Text(frame, "caption")
		ns.Style.MetricText(frame)
	elseif type(frame.GetRegions) == "function" then
		for _, text in ipairs({ frame:GetRegions() }) do
			if type(text.GetObjectType) == "function" and text:GetObjectType() == "FontString" then
				ns.Style.Text(text, "caption")
				ns.Style.MetricText(text)
			end
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			PriceText(child)
		end
	end
end

local function Prices(slot)
	local name = type(slot.GetName) == "function" and slot:GetName()
	if issecretvalue and issecretvalue(name) then
		name = nil
	end
	local money = slot.MoneyFrame or type(name) == "string" and _G[name .. "MoneyFrame"]
	for _, key in ipairs({ "MoneyFrame", "AltCurrencyFrame" }) do
		local frame = slot[key] or type(name) == "string" and _G[name .. key]
		if type(frame) == "table" and K.Widgets.MayMove(frame) then
			local gold = money and money:IsShown()
			local beside = key == "AltCurrencyFrame" and not (issecretvalue and issecretvalue(gold)) and gold == true
			local want = beside and { "LEFT", money, "RIGHT", -12, 0 } or { "BOTTOMLEFT", slot, "BOTTOMLEFT", K.Widgets.Snap(frame, 46), 0 }
			local point, relative, relativePoint, x, y = frame:GetPoint(1)
			local W = K.Widgets
			local secret = W.IsSecret(point) or W.IsSecret(relative) or W.IsSecret(relativePoint) or W.IsSecret(x) or W.IsSecret(y)
			if secret or frame:GetNumPoints() ~= 1 or point ~= want[1] or relative ~= want[2] or relativePoint ~= want[3] or x ~= want[4] or y ~= want[5] then
				frame:ClearAllPoints()
				frame:SetPoint(unpack(want))
			end
			PriceText(frame)
		end
	end
end

local function Slot(slot)
	Skin.Strip(slot)
	Skin.Backdrop(slot, { shape = "tile", fill = "surface", shadow = false })
	Item(slot.ItemButton)
	if ns.Style.MetricsEnabled() then Prices(slot) end
	local name = slot.Name
	if type(name) ~= "table" or type(name.GetNumPoints) ~= "function" then
		return
	end
	ns.Style.Text(name, "body", nil, NameSize)
	for i = 1, name:GetNumPoints() do
		local point, _, _, _, y = name:GetPoint(i)
		local vertical = type(point) == "string" and point:match("^(%u*)LEFT$")
		if vertical and type(y) == "number" then
			name:SetPoint(vertical .. "RIGHT", slot, vertical .. "RIGHT", -K.Tokens.Size("gapMedium"), y)
			name:SetWordWrap(false)
			return
		end
	end
end

local function Title()
	local frame = MerchantFrame
	local tab = frame.selectedTab
	if not (issecretvalue and issecretvalue(tab)) and tab == 2 then
		Kit.Title(frame)
	else
		Kit.Title(frame, "names")
	end
end

local function Updated()
	Title()
	if ns.Style.MetricsEnabled() then
		for i = 1, MAX_ITEMS do
			local slot = _G["MerchantItem" .. i]
			if slot then Prices(slot) end
		end
		if MerchantBuyBackItem then Prices(MerchantBuyBackItem) end
	end
end

local function Apply()
	local frame = MerchantFrame
	if not Kit.Have(frame, "MerchantFrame") then
		return false
	end
	Kit.Window(frame)
	Title()
	for _, update in ipairs({ "MerchantFrame_UpdateMerchantInfo", "MerchantFrame_UpdateBuybackInfo" }) do
		if type(_G[update]) == "function" then
			hooksecurefunc(update, Updated)
		end
	end
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
	metrics = true,
	Apply = Apply,
})
