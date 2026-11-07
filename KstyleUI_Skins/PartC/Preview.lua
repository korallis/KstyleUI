-- Preview.lua: part C's sample in the settings preview: a group loot roll with a quality-rimmed icon, the item name and its timer bar.
local _, ns = ...

local K = KstyleUI
local Tokens, Theme, Widgets, L = K.Tokens, K.Theme, K.Widgets, K.L
local Style, Parts, Kit = ns.Style, ns.Parts, ns.PartC

local WIDTH, HEIGHT = 248, 64
local ICON = 34
local ICON_FILE = "Interface\\Icons\\INV_Bracer_07"
local QUALITY_EPIC = 4
local BAR_HEIGHT = 6
local BAR_VALUE = 0.4

local function Refresh(card)
	Style.Text(card.name, "body")
	card.name:SetTextColor(Theme.QualityColor(QUALITY_EPIC))
	Style.Text(card.label, "caption", "text")
	card.rim:SetRimColor(Theme.QualityColor(QUALITY_EPIC))
	local bar = card.bar
	bar:SetBarTexture(Style.BarTexture())
	bar:SetReverseFill(Style.ReverseFill())
	bar:SetBarColor(Style.BarColor(Tokens.Color("neutral")))
end

local function Build(frame, anchor)
	local gap, pad = Tokens.Size("gapMedium"), Tokens.Size("gapLarge")
	local card = Widgets.Panel(frame, { width = WIDTH, height = HEIGHT })
	card:SetPoint("TOP", anchor, "BOTTOM", 0, -gap)
	local slot = CreateFrame("Frame", nil, card)
	slot:SetSize(ICON, ICON)
	slot:SetPoint("TOPLEFT", card, "TOPLEFT", pad, -gap)
	local icon = slot:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(slot)
	icon:SetTexture(ICON_FILE)
	Kit.Crop(icon)
	card.rim = Parts.Rim(slot, { outset = Tokens.Size("gapTiny") })
	card.name = card:CreateFontString(nil, "OVERLAY")
	card.name:SetPoint("TOPLEFT", slot, "TOPRIGHT", gap, 0)
	Widgets.SetText(card.name, L["Bracers of the Watch"])
	card.label = card:CreateFontString(nil, "OVERLAY")
	card.label:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -Tokens.Size("gapSmall"))
	card.label:SetText(L["Need or greed"]:upper())
	local bar = Widgets.StatusBar(card, { width = WIDTH - 2 * pad, height = BAR_HEIGHT, border = true })
	bar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", pad, gap)
	bar:SetBarRange(0, 1)
	bar:SetBarValue(BAR_VALUE)
	card.bar = bar
	card.Refresh = Refresh
	Refresh(card)
	return card
end

Kit.Preview(Build)
