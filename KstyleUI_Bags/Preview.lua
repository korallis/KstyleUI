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
		{ icon = 134829, count = 5, quality = QUALITY_COMMON, name = L["Healing potion"], category = "consumables" },
		{ icon = 135274, quality = QUALITY_UNCOMMON, level = 24, name = L["Short sword"], bind = true, category = "equipment" },
		{ icon = 133074, quality = QUALITY_EPIC, level = 66, isNew = true, name = L["Night cowl"], set = L["Tank"], category = "equipment" },
		{ icon = 133344, quality = QUALITY_RARE, level = 41, name = L["Band of thorns"], category = "equipment" },
		{ icon = 133723, count = 3, quality = QUALITY_POOR, junk = true, name = L["Broken fang"], category = "junk" },
		{ icon = 132905, count = 20, quality = QUALITY_COMMON, name = L["Silk cloth"], reagent = true, category = "tradeGoods" },
		{ icon = 134414, quality = QUALITY_COMMON, name = L["Hearthstone"], category = "other" },
		{ category = "empty" },
	}
	local PINNED = 2
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

	local function ListItems(view, categories, pinned, order)
		local items, counts = {}, {}
		for _, option in ipairs(Settings.VIEWS) do
			items[#items + 1] = { kind = "view", value = option.value, label = option.label, selected = option.value == view }
		end
		if pinned then
			items[#items + 1] = { kind = "only", label = L["Pinned"], count = 1 }
		end
		if view == "bags" then
			items[#items + 1] = { kind = "only", label = Data.BagName(0), count = #order }
		end
		for _, i in ipairs(order) do
			counts[SAMPLES[i].category] = (counts[SAMPLES[i].category] or 0) + 1
		end
		for _, category in ipairs(categories and Data.CATEGORIES or {}) do
			if counts[category.key] or Settings.Get("sidebarEmpty") then
				items[#items + 1] = { kind = "only", label = category.label, count = counts[category.key] or 0 }
			end
		end
		if Settings.Get("sidebarAdd") then
			items[#items + 1] = { kind = "add", label = L["Add category"] }
		end
		return items
	end

	local function Refresh(frame)
		local size = min(Settings.Get("slotSize"), floor(Tokens.Size("actionButton") * 1.4))
		local spacing = Settings.Get("spacing")
		local growth = Settings.Get("growth")
		local list = Settings.Get("listView")
		local view = Settings.Get("openTo")
		local categories = view == "all" and Settings.Sections()
		local pinned = Settings.Get("pins") and (categories or Settings.Get("pinsInGrid"))
		local dim = pinned and not categories and Settings.Get("pinsDim")
		local order = {}
		for i = 1, #SAMPLES do
			if not (pinned and categories and Settings.Get("pinsOnly") and i == PINNED) then
				order[#order + 1] = i
			end
		end
		if Settings.Get("sortBottom") and not categories and not Data.GROWTH[growth][2] then
			table.insert(order, 1, table.remove(order))
		end
		local count = list and LIST_ROWS or #order
		local rowWidth, rowHeight = Data.Size(PREVIEW_COLUMNS, 1, size, spacing), Settings.Get("listRowHeight")
		local cellWidth = list and rowWidth - Settings.Get("listLeft") - Settings.Get("listRight") or size
		local cols, rows = Data.Grid(count, list and 1 or PREVIEW_COLUMNS)
		local width, height = Data.Size(cols, rows, cellWidth, spacing, list and rowHeight or nil)
		width = list and rowWidth or width
		frame.grid:SetSize(max(1, width), max(1, height))
		frame.title.opts.width = max(1, width)
		frame.title:SetText(view == "bags" and Data.BagName(0) or L["Bags"])
		frame.title:Restyle()
		local capSize = Settings.Get("capSize")
		if capSize ~= Settings.defaults.capSize then
			Widgets.CapsSize(frame.title.label, nil, capSize / Settings.defaults.capSize)
		end
		local value = Settings.Get("sectionValue") and (#SAMPLES - 1) .. "  " .. ns.Window.MoneyText(SAMPLE_VALUE) or nil
		if value or frame.title.counted then
			frame.title:SetCount(value)
		end
		if pinned and not frame.pin then
			frame.pinCap = Widgets.SectionCap(frame, { text = L["Pinned"] })
			frame.pin = Slot.New(frame, 1)
		end
		if frame.pin then
			frame.pinCap:SetShown(pinned)
			frame.pin.button:SetShown(pinned)
		end
		local head = 0
		if pinned then
			frame.pinCap.opts.width = max(1, width)
			frame.pinCap:Restyle()
			frame.pinCap:ClearAllPoints()
			Widgets.Point(frame.pinCap, "TOP", frame, "TOP", 0, -Tokens.Size("gapLarge"))
			frame.pin.button:ClearAllPoints()
			frame.pin.button:SetPoint("TOPLEFT", frame.pinCap, "BOTTOMLEFT", list and Settings.Get("listLeft") or 0, -Tokens.Size("gapSmall"))
			Slot.Style(frame.pin)
			Slot.Layout(frame.pin, cellWidth, true, list and rowHeight or nil)
			Slot.Update(frame.pin, Record(SAMPLES[PINNED]), SAMPLES[PINNED].level, true)
			head = Widgets.SECTION_CAP_HEIGHT + Tokens.Size("gapSmall") + (list and rowHeight or size) + Tokens.Size("gapLarge")
		end
		frame.title:ClearAllPoints()
		Widgets.Point(frame.title, "TOP", frame, "TOP", 0, -Tokens.Size("gapLarge") - head)
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
		local side = Settings.Get("sidebar")
		if side and not frame.list then
			frame.list = ns.List.New(frame)
		end
		if frame.list then
			frame.list:SetShown(side)
		end
		if side then
			local items = ListItems(view, categories, pinned, order)
			frame.list:ClearAllPoints()
			Widgets.Point(frame.list, "TOPLEFT", currencies and frame.currency or frame.grid, "BOTTOMLEFT", 0, -Tokens.Size("gapLarge"))
			frame.list:SetSize(ns.List.WIDTH, #items * ns.List.ROW)
			ns.List.Show(frame.list, items, false)
		end
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
				local sample = SAMPLES[order[i]]
				slot.button.sample = sample
				extra.bind = sample.bind and Settings.Get("bindText") and L["BoE"] or nil
				extra.set = sample.set and Settings.Get("setNames") and sample.set or nil
				extra.mark = sample.reagent and Settings.Get("reagentMark") and not Settings.ReagentApart()
				Slot.Update(slot, Record(sample), sample.level, not (dim and order[i] == PINNED), nil, extra)
			end
		end
	end

	local function Hint(button)
		local sample = button.sample
		if not (sample and sample.category == "equipment" and Settings.Get("quickActions")) then return end
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:SetText(sample.name)
		ns.Quick.Hint(ns.Quick.DISENCHANT)
	end

	build = function(parent)
		local frame = CreateFrame("Frame", nil, parent)
		frame.title = Widgets.SectionCap(frame, { text = L["Bags"] })
		frame.grid = CreateFrame("Frame", nil, frame)
		frame.slots = {}
		for i = 1, PREVIEW_COLUMNS * PREVIEW_ROWS do
			frame.slots[i] = Slot.New(frame.grid, i)
			frame.slots[i].button:HookScript("OnEnter", Hint)
			frame.slots[i].button:HookScript("OnLeave", function() if type(GameTooltip_Hide) == "function" then GameTooltip_Hide() end end)
		end
		frame.Refresh = Refresh
		Refresh(frame)
		return frame
	end
	return build(...)
end
