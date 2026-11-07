-- Preview.lua: the settings window's live preview: sample slots drawn with the module's own slot code and current settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Data, Slot, Settings, L = ns.Data, ns.Slot, ns.Settings, ns.L
local floor, max, min = math.floor, math.max, math.min

local Preview = {}
ns.Preview = Preview

local PREVIEW_COLUMNS = 4
local PREVIEW_ROWS = 2
local QUALITY_POOR, QUALITY_COMMON, QUALITY_UNCOMMON, QUALITY_RARE, QUALITY_EPIC = 0, 1, 2, 3, 4

local SAMPLES = {
	{ icon = 134829, count = 5, quality = QUALITY_COMMON },
	{ icon = 135274, quality = QUALITY_UNCOMMON, level = 24 },
	{ icon = 133074, quality = QUALITY_EPIC, level = 66, isNew = true },
	{ icon = 133344, quality = QUALITY_RARE, level = 41 },
	{ icon = 133723, count = 3, quality = QUALITY_POOR, junk = true },
	{ icon = 132905, count = 20, quality = QUALITY_COMMON },
	{ icon = 134414, quality = QUALITY_COMMON },
	{},
}

local function Record(sample)
	return {
		empty = sample.icon == nil,
		icon = sample.icon,
		count = sample.count,
		quality = sample.quality,
		junk = sample.junk == true,
		isNew = sample.isNew == true,
		locked = false,
	}
end

local function Refresh(frame)
	local size = min(Settings.Get("slotSize"), floor(Tokens.Size("actionButton") * 1.4))
	local spacing = Settings.Get("spacing")
	local growth = Settings.Get("growth")
	local cols, rows = Data.Grid(#frame.slots, PREVIEW_COLUMNS)
	local width, height = Data.Size(cols, rows, size, spacing)
	frame.grid:SetSize(max(1, width), max(1, height))
	for i, slot in ipairs(frame.slots) do
		local x, y = Data.Cell(i, cols, rows, size, spacing, growth)
		slot.button:ClearAllPoints()
		slot.button:SetPoint("TOPLEFT", frame.grid, "TOPLEFT", x, y)
		Slot.Style(slot)
		Slot.Layout(slot, size, true)
		local sample = SAMPLES[i]
		Slot.Update(slot, Record(sample), sample.level, true)
	end
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	local title = Widgets.Text(frame, "heading", "textEmphasis")
	title:SetPoint("TOP", frame, "TOP", 0, -Tokens.Size("gapLarge"))
	Widgets.SetText(title, L["Bags"])
	frame.title = title
	frame.grid = CreateFrame("Frame", nil, frame)
	frame.grid:SetPoint("TOP", title, "BOTTOM", 0, -Tokens.Size("gapLarge"))
	frame.slots = {}
	for i = 1, PREVIEW_COLUMNS * PREVIEW_ROWS do
		frame.slots[i] = Slot.New(frame.grid, i)
	end
	frame.Refresh = Refresh
	Refresh(frame)
	return frame
end
