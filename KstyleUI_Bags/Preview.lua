-- Preview.lua: the settings window's live preview: sample slots drawn with the module's own slot code and current settings, under the card heading every bag section wears.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Data, Slot, Settings, L = ns.Data, ns.Slot, ns.Settings, ns.L
local floor, max, min = math.floor, math.max, math.min

local Preview = {}
ns.Preview = Preview

local build
function Preview.Build(...)
	if build then return build(...) end
	local PREVIEW_COLUMNS = 4
	local PREVIEW_ROWS = 2
	local QUALITY_POOR, QUALITY_COMMON, QUALITY_UNCOMMON, QUALITY_RARE, QUALITY_EPIC = 0, 1, 2, 3, 4

	local SAMPLES = {
		{ icon = 134829, count = 5, quality = QUALITY_COMMON, name = L["Healing potion"] },
		{ icon = 135274, quality = QUALITY_UNCOMMON, level = 24, name = L["Short sword"], bind = true },
		{ icon = 133074, quality = QUALITY_EPIC, level = 66, isNew = true, name = L["Night cowl"], set = L["Tank"] },
		{ icon = 133344, quality = QUALITY_RARE, level = 41, name = L["Band of thorns"] },
		{ icon = 133723, count = 3, quality = QUALITY_POOR, junk = true, name = L["Broken fang"] },
		{ icon = 132905, count = 20, quality = QUALITY_COMMON, name = L["Silk cloth"], reagent = true },
		{ icon = 134414, quality = QUALITY_COMMON, name = L["Hearthstone"] },
		{},
	}
	local LIST_ROWS = 4
	local SAMPLE_VALUE = 24500
	local BAG = { icon = 133633, quality = QUALITY_COMMON }
	local BAGS = 4
	local CURRENCIES = "|T463448:0|t 1250   |T133784:0|t 80"
	local extra = {}

	local function Record(sample)
		return {
			empty = sample.icon == nil,
			icon = sample.icon,
			count = sample.count,
			quality = sample.quality,
			junk = sample.junk == true,
			isNew = sample.isNew == true,
			locked = false,
			name = sample.name,
		}
	end

	local function Refresh(frame)
		local size = min(Settings.Get("slotSize"), floor(Tokens.Size("actionButton") * 1.4))
		local spacing = Settings.Get("spacing")
		local growth = Settings.Get("growth")
		local list = Settings.Get("listView")
		local count = list and LIST_ROWS or #frame.slots
		local rowWidth, rowHeight = Data.Size(PREVIEW_COLUMNS, 1, size, spacing), Settings.Get("listRowHeight")
		local cellWidth = list and rowWidth - Settings.Get("listLeft") - Settings.Get("listRight") or size
		local cols, rows = Data.Grid(count, list and 1 or PREVIEW_COLUMNS)
		local width, height = Data.Size(cols, rows, cellWidth, spacing, list and rowHeight or nil)
		width = list and rowWidth or width
		frame.grid:SetSize(max(1, width), max(1, height))
		frame.title.opts.width = max(1, width)
		frame.title:Restyle()
		local capSize = Settings.Get("capSize")
		if capSize ~= Settings.defaults.capSize then
			Widgets.CapsSize(frame.title.label, nil, capSize / Settings.defaults.capSize)
		end
		local value = Settings.Get("sectionValue") and (#SAMPLES - 1) .. "  " .. ns.Window.MoneyText(SAMPLE_VALUE) or nil
		if value or frame.title.counted then
			frame.title:SetCount(value)
		end
		frame.title:ClearAllPoints()
		Widgets.Point(frame.title, "TOP", frame, "TOP", 0, -Tokens.Size("gapLarge"))
		local bags = Settings.Get("bagSlots")
		local strip = bags and Tokens.Size("rowHeight") + Tokens.Size("gapMedium") or 0
		frame.grid:ClearAllPoints()
		frame.grid:SetPoint("TOP", frame.title, "BOTTOM", 0, -Tokens.Size("gapLarge") - strip)
		if bags and not frame.bags then
			frame.bags = { frame = CreateFrame("Frame", nil, frame), slots = {} }
			for i = 1, BAGS do
				frame.bags.slots[i] = Slot.New(frame.bags.frame, i)
			end
		end
		if frame.bags then
			frame.bags.frame:SetShown(bags)
			for _, slot in ipairs(frame.bags.slots) do
				Slot.Update(slot, BAG, nil, true)
			end
			if bags then
				Slot.Row(frame, frame.bags.frame, frame.bags.slots, frame.grid, -strip, width)
			end
		end
		local currencies = Settings.Get("currencies")
		if currencies and not frame.currency then
			frame.currency = Widgets.Text(frame, "body", "text")
			frame.currency:SetJustifyH("LEFT")
			frame.currency:SetWordWrap(false)
			frame.currency:SetPoint("TOPLEFT", frame.grid, "BOTTOMLEFT", 0, -Tokens.Size("gapMedium"))
			frame.currency:SetPoint("TOPRIGHT", frame.grid, "BOTTOMRIGHT", 0, -Tokens.Size("gapMedium"))
			frame.currency:SetHeight(Tokens.Size("rowHeight"))
		end
		if frame.currency then
			frame.currency:SetShown(currencies)
			local picked = Settings.Get("currency1") + Settings.Get("currency2") + Settings.Get("currency3") > 0
			frame.currency:SetText(picked and Data.CurrencyText() or CURRENCIES)
		end
		local bottom = Settings.Get("sortBottom")
		for i, slot in ipairs(frame.slots) do
			local shown = i <= count
			slot.button:SetShown(shown)
			if shown then
				local x, y = Data.Cell(i, cols, rows, cellWidth, spacing, growth, list and rowHeight or nil)
				slot.button:ClearAllPoints()
				slot.button:SetPoint("TOPLEFT", frame.grid, "TOPLEFT", x + (list and Settings.Get("listLeft") or 0), y)
				Slot.Style(slot)
				Slot.Layout(slot, cellWidth, true, list and rowHeight or nil)
				Slot.SetStripe(slot, list and Settings.Get("listStripes") and i % 2 == 0)
				local sample = SAMPLES[bottom and (i == 1 and #SAMPLES or i - 1) or i]
				extra.bind = sample.bind and Settings.Get("bindText") and L["BoE"] or nil
				extra.set = sample.set and Settings.Get("setNames") and sample.set or nil
				extra.mark = sample.reagent and Settings.Get("reagentMark") and not Settings.ReagentApart()
				Slot.Update(slot, Record(sample), sample.level, true, nil, extra)
			end
		end
	end

	build = function(parent)
		local frame = CreateFrame("Frame", nil, parent)
		frame.title = Widgets.SectionCap(frame, { text = L["Bags"] })
		frame.grid = CreateFrame("Frame", nil, frame)
		frame.slots = {}
		for i = 1, PREVIEW_COLUMNS * PREVIEW_ROWS do
			frame.slots[i] = Slot.New(frame.grid, i)
		end
		frame.Refresh = Refresh
		Refresh(frame)
		return frame
	end
	return build(...)
end
