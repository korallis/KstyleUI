-- Popups.lua: the popup skin: StaticPopup1 to 4 on glass panels, with restyled buttons, edit, money and dropdown boxes, and a colour-rimmed item.
local _, ns = ...

local K = KstyleUI
local Skin, L = K.Skin, K.L
local Parts, Skins, Kit = ns.Parts, ns.Skins, ns.PartC

local KEY = "popups"
local POPUP_COUNT = 4
local BUTTONS = { "ButtonContainer.Button1", "ButtonContainer.Button2", "ButtonContainer.Button3", "ButtonContainer.Button4", "ExtraButton" }
local COINS = { "gold", "silver", "copper" }
local KEEP = { "AlertIcon", "Separator", "ProgressBarBorder", "ProgressBarFill", "ProgressBarSpacer" }

local function SkinItem(item)
	Parts.Hush(item.NameFrame)
	local rim = Kit.Item(item.Item)
	local text = item.Text
	if not rim or type(text) ~= "table" or type(text.GetTextColor) ~= "function" then
		Kit.LogOnce(KEY, "ItemFrame.Text is missing; popup items have no colour rim")
		return
	end
	Kit.ColorRim(rim, text:GetTextColor())
	hooksecurefunc(text, "SetTextColor", function(_, r, g, b)
		Kit.ColorRim(rim, r, g, b)
	end)
end

local function SkinPopup(popup)
	local keep = {}
	for _, key in ipairs(KEEP) do
		if Parts.IsTexture(popup[key]) then
			keep[popup[key]] = true
		end
	end
	Skin.Strip(popup, { keep = keep, children = { "NineSlice", "BG", "Bg" } })
	Skin.Backdrop(popup, { shape = "panel", fill = "surface", shadow = true })
	if type(popup.CloseButton) == "table" then
		Skin.CloseButton(popup.CloseButton)
	end
	Kit.Each(KEY, popup, BUTTONS, function(button)
		Skin.Button(button)
		Kit.Accent(button)
	end)
	if type(popup.EditBox) == "table" then
		Kit.EditBox(popup.EditBox)
	end
	if type(popup.Dropdown) == "table" then
		Parts.Dropdown(popup.Dropdown)
	end
	local money = popup.MoneyInputFrame
	if type(money) == "table" then
		for _, coin in ipairs(COINS) do
			Kit.EditBox(money[coin], { "texture" })
		end
	end
	if type(popup.ItemFrame) == "table" then
		SkinItem(popup.ItemFrame)
	end
end

local function Apply()
	for i = 1, POPUP_COUNT do
		local popup = Kit.Frame(KEY, "StaticPopup" .. i)
		if popup then
			SkinPopup(popup)
		end
	end
end

Skins.Add({
	key = KEY,
	label = L["Popups"],
	help = L["Restyles the game's confirmation popups and their buttons."],
	frame = "StaticPopup1",
	Apply = Apply,
})
