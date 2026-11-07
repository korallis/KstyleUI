-- Preview.lua: the settings window's live preview of the skinned look: a small window with a title, quality-rimmed slots and a bar.
local _, ns = ...

local K = KstyleUI
local Tokens, Theme, Widgets, L = K.Tokens, K.Theme, K.Widgets, K.L
local Style, Parts = ns.Style, ns.Parts

local Preview = {}
ns.Preview = Preview

local WIDTH, HEIGHT = 248, 214
local SLOT = 34
local SLOT_QUALITIES = { 2, 3, 4 }
local SLOT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ICON_CROP = 0.07
local BAR_HEIGHT = 12
local BAR_VALUE = 0.62
local STANDING_FRIENDLY = 5

local function Refresh(frame)
	for _, text in ipairs(frame.texts) do
		Style.Text(text)
	end
	frame.line:Restyle()
	for i, slot in ipairs(frame.slots) do
		slot.rim:SetRimColor(Theme.QualityColor(SLOT_QUALITIES[i]))
	end
	local bar = frame.bar
	bar:SetBarTexture(Style.BarTexture())
	bar:SetReverseFill(Style.ReverseFill())
	bar:SetBarColor(Style.BarColor(Theme.ReactionColor(STANDING_FRIENDLY)))
	for _, extra in ipairs(frame.extras) do
		if type(extra.Refresh) == "function" then
			K.Call(extra.Refresh, extra)
		end
	end
end

local function Extras(frame, anchor)
	local below = anchor
	for _, builder in ipairs(ns.previewParts or {}) do
		local ok, extra = K.Call(builder, frame, below)
		if ok and type(extra) == "table" then
			frame.extras[#frame.extras + 1] = extra
			below = extra
		end
	end
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	local gap, pad = Tokens.Size("gapMedium"), Tokens.Size("gapLarge")
	local panel = Widgets.Panel(frame, { width = WIDTH, height = HEIGHT })
	panel:SetPoint("TOP", frame, "TOP", 0, -gap)
	local title = Style.Text(panel:CreateFontString(nil, "OVERLAY"), "heading", "textEmphasis")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -pad)
	Widgets.SetText(title, L["Character"])
	local tab = CreateFrame("Frame", nil, panel)
	tab:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -gap)
	tab:SetSize(WIDTH / 3, Tokens.Size("rowHeight"))
	local tabText = Style.Text(tab:CreateFontString(nil, "OVERLAY"), "caption", "textEmphasis")
	tabText:SetPoint("CENTER", tab, "CENTER")
	tabText:SetText(L["Reputation"]:upper())
	frame.line = Parts.AccentLine(tab, { edge = "BOTTOM" })
	frame.slots = {}
	local previous
	for i = 1, #SLOT_QUALITIES do
		local slot = CreateFrame("Frame", nil, panel)
		slot:SetSize(SLOT, SLOT)
		if previous then
			slot:SetPoint("LEFT", previous, "RIGHT", gap, 0)
		else
			slot:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", Tokens.Size("gapTiny"), -pad)
		end
		local icon = slot:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints(slot)
		icon:SetTexture(SLOT_ICON)
		icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
		slot.rim = Parts.Rim(slot, { outset = Tokens.Size("gapTiny") })
		frame.slots[i] = slot
		previous = slot
	end
	local name = Style.Text(panel:CreateFontString(nil, "OVERLAY"), "body", "text")
	name:SetPoint("TOPLEFT", frame.slots[1], "BOTTOMLEFT", -Tokens.Size("gapTiny"), -pad)
	Widgets.SetText(name, L["Stormwind"])
	local bar = Widgets.StatusBar(panel, { width = WIDTH - 2 * pad, height = BAR_HEIGHT, border = true })
	bar:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -gap)
	bar:SetBarRange(0, 1)
	bar:SetBarValue(BAR_VALUE)
	local standing = Style.Text(bar:CreateFontString(nil, "OVERLAY"), "caption", "textEmphasis")
	standing:SetPoint("CENTER", bar, "CENTER")
	standing:SetText(L["Friendly"]:upper())
	frame.bar = bar
	frame.texts = { title, tabText, name, standing }
	frame.extras = {}
	Extras(frame, panel)
	frame.Refresh = Refresh
	Refresh(frame)
	return frame
end
