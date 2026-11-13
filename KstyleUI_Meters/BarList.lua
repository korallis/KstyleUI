-- BarList.lua: the meter card the damage and threat meters share: a section cap with the title and an aside or a fight switch, full-width rows (the threat meter's over a flat 4-unit class pill, the damage card's as full-height bars with the name inside the fill and the amount and share at the right), and a split that opens under a hovered row, inside the card.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Logic = ns.Logic
local max, min, floor, abs = math.max, math.min, math.floor, math.abs

local VALUE_EMS = 3.4
local PERCENT_EMS = 2.6
local FILL_ALPHA = 0.5
local LIT_ALPHA, SHADE_ALPHA = 0.6, 0.45
local PILL_HEIGHT = 4
local PILL_GAP = 3
local TEXT_AIR = 2
local ICON_CROP = 0.08
local MORE_GLYPH = 10
local ESTIMATE_EM = 0.5
local CAP_RESERVE = 44
local CAP_GAP = "gapMedium"
local SWITCH_GAP = "  "
local SPLIT_LEVEL = 3
local BLOCK_PAD = 16
local BLOCK_CAP_LEFT = 12
local BLOCK_CAP_TOP = 14.5
local BLOCK_TOP = 35.5
local BLOCK_TEXT_INSET = 7
local BLOCK_SWITCH_REACH = 120
local BLOCK_ICON_GAP = 2
local DOT = "\194\183"
local DOT_GAP_EM = 5 / 21
local BEARING_DEFAULT = 0.025
local DOT_BEARING_DEFAULT = 0.033
local OWN_FONTS = "interface\\addons\\kstyleui\\media\\fonts\\"

local BarList = {}
ns.BarList = BarList

local function EndChar(text, last)
	if Logic.IsSecret(text) or type(text) ~= "string" or text == "" then
		return nil
	end
	if not last then
		local b = text:byte(1)
		local n = 1
		if b >= 240 then
			n = 4
		elseif b >= 224 then
			n = 3
		elseif b >= 192 then
			n = 2
		end
		return text:sub(1, n)
	end
	local i = #text
	while i > 1 do
		local b = text:byte(i)
		if b < 128 or b >= 192 then
			break
		end
		i = i - 1
	end
	return text:sub(i)
end

function BarList.DotGap(fontSize, pixel)
	local step = Logic.Plain(pixel)
	if not step or step <= 0 then
		step = K.Scale.Pixel(1)
	end
	return K.Widgets.DotGap(fontSize, step, DOT_GAP_EM)
end

function BarList.Bearings(path)
	if Logic.IsSecret(path) or type(path) ~= "string" then
		return nil
	end
	local file = path:lower():gsub("/", "\\")
	if file:sub(1, #OWN_FONTS) ~= OWN_FONTS then
		return nil
	end
	return ns.BEARINGS[file:sub(#OWN_FONTS + 1)]
end

function BarList.JoinOffsets(lastChar, firstChar, fontSize, pixel, path)
	local size = Logic.Plain(fontSize) or 0
	local step = Logic.Plain(pixel)
	if not step or step <= 0 then
		step = K.Scale.Pixel(1)
	end
	local gap = BarList.DotGap(fontSize, step)
	local face = BarList.Bearings(path == nil and Tokens.Font("number") or path)
	local lsb, rsb = face and face.lsb or {}, face and face.rsb or {}
	local dotLsb, dotRsb = lsb[DOT] or DOT_BEARING_DEFAULT, rsb[DOT] or DOT_BEARING_DEFAULT
	return ((lastChar and rsb[lastChar]) or BEARING_DEFAULT) * size + dotLsb * size - gap, ((firstChar and lsb[firstChar]) or BEARING_DEFAULT) * size + dotRsb * size - gap
end
BarList.DOT_GAP_EM = DOT_GAP_EM
ns.FILL_ALPHA = FILL_ALPHA
BarList.PILL_HEIGHT = PILL_HEIGHT
BarList.PILL_GAP = PILL_GAP
BarList.LIT_ALPHA, BarList.SHADE_ALPHA = LIT_ALPHA, SHADE_ALPHA

local List = {}

local function Plain(value)
	return type(value) == "number" and not (issecretvalue and issecretvalue(value)) and value == value
end

local function Inward(frame)
	local x, root = frame:GetCenter(), K.Scale.Root()
	local middle = root:GetCenter()
	local own, scale = frame:GetEffectiveScale(), root:GetEffectiveScale()
	if Plain(x) and Plain(middle) and Plain(own) and Plain(scale) and x * own > middle * scale then
		return "ANCHOR_LEFT"
	end
	return "ANCHOR_RIGHT"
end

local function Size(frame, fallbackWidth, fallbackHeight)
	local w, h = frame:GetWidth(), frame:GetHeight()
	return Logic.Plain(w) or fallbackWidth, Logic.Plain(h) or fallbackHeight
end

local function Text(parent, justify)
	local text = Widgets.FontString(parent, "OVERLAY")
	text:SetJustifyH(justify)
	text:SetWordWrap(false)
	return text
end

local RowEnter, RowLeave, StyleRow, PlaceBlockRow, FillRow, SetIcon

local function NewRow(list, index, parent, passive)
	local section = list.section
	local width = list.barWidth or Tokens.Size("buffBarWidth")
	local frame = CreateFrame("Frame", nil, parent or list.panel)
	local bar = Widgets.StatusBar(frame, {
		texture = ns.Get(section .. ".texture"),
		background = "buttonFill",
		smooth = true,
		min = 0,
		max = 1,
		value = 0,
		width = width,
		height = list.block and list.rowHeight or PILL_HEIGHT,
	})
	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	icon:Hide()
	local back
	if list.block then
		back = frame:CreateTexture(nil, "BACKGROUND")
		back:SetColorTexture(Tokens.Color("black"))
		back:Hide()
	end
	local ink = frame
	if list.block then
		bar.keyline:Hide()
		bar:SetLitShade(LIT_ALPHA, SHADE_ALPHA)
		ink = CreateFrame("Frame", nil, frame)
		ink:SetAllPoints(frame)
		ink:SetFrameLevel(bar:GetFrameLevel() + 1)
	end
	local row = {
		index = index,
		frame = frame,
		bar = bar,
		icon = icon,
		back = back,
		name = Text(ink, "LEFT"),
		value = Text(ink, "RIGHT"),
		percent = Text(ink, "RIGHT"),
	}
	if list.onRowClick and not passive then
		frame:EnableMouse(true)
		frame:SetScript("OnMouseUp", function(_, button)
			list.onRowClick(list, row.index, button)
		end)
	end
	if list.rowSplits and not passive then
		local more = frame:CreateTexture(nil, "OVERLAY")
		more:SetTexture((Tokens.Texture("glyphChevron")))
		more:Hide()
		row.more = more
	end
	if (list.rowSplit or list.rowTooltip or list.tooltip) and not passive then
		frame:HookScript("OnEnter", function()
			RowEnter(list, row)
		end)
		frame:HookScript("OnLeave", function()
			RowLeave(list, row)
		end)
	end
	row.name:SetTextColor(Tokens.Color("textEmphasis"))
	row.value:SetTextColor(Tokens.Color("textEmphasis"))
	row.percent:SetTextColor(Tokens.Color(list.block and "textEmphasis" or "text"))
	if list.block then
		row.dot = Text(ink, "RIGHT")
		row.dot:SetText(DOT)
		row.dot:SetTextColor(Tokens.Color("textEmphasis"))
		row.dot:Hide()
	end
	return row
end

local function Spacing(list)
	return list.spacing or Widgets.Snap(list.panel, ns.Get(list.section .. ".spacing"))
end

local function Room(list)
	local _, height = Size(list.holder, list.width, list.height)
	return height - Widgets.Snap(list.panel, list:Top()) - list.pad
end

local Split = {}
Split.__index = Split

function Split:Clear()
	self.used = 0
	self.noted = false
	for _, line in ipairs(self.lines) do
		line.frame:Hide()
	end
	self.note:Hide()
end

function Split:AddRow(name, value, maxValue, valueText, percentText, icon, schoolToken)
	local n = self.used + 1
	local list = self.list
	local line = self.lines[n]
	if not line then
		line = NewRow(list, n, self.frame, true)
		self.lines[n] = line
	end
	self.used = n
	SetIcon(list, line, icon)
	FillRow(list, line, name, nil, "friendly", value, maxValue, valueText, percentText, schoolToken)
end

function Split:SetNote(text)
	Widgets.SetText(self.note, text)
	self.noted = true
	self.note:Show()
end

local function NewSplit(list)
	local frame = CreateFrame("Frame", nil, list.panel)
	frame:SetFrameLevel(list.panel:GetFrameLevel() + SPLIT_LEVEL)
	frame:Hide()
	local split = setmetatable({ list = list, frame = frame, lines = {}, used = 0, hidden = {} }, Split)
	split.note = Text(frame, "LEFT")
	split.note:SetTextColor(Tokens.Color("muted"))
	split.note:Hide()
	list.split = split
	return split
end

local function SplitStyle(list, split)
	for _, line in ipairs(split.lines) do
		StyleRow(list, line)
	end
	ns.ApplyFont(split.note, list.section)
end

local function LayoutSplit(list, split, shown, note)
	local frame = split.frame
	local spacing = Spacing(list)
	local pitch = list.rowHeight + spacing
	local y = 0
	for i = 1, split.used do
		local entry = split.lines[i]
		if i <= shown then
			PlaceBlockRow(list, entry, y, frame, 0)
			entry.frame:Show()
			y = y + pitch
		else
			entry.frame:Hide()
		end
	end
	split.note:SetShown(note)
	if note then
		local slot = list.blockIcons and list.rowHeight + Widgets.Snap(list.panel, BLOCK_ICON_GAP) or 0
		local inset = Widgets.Snap(list.panel, BLOCK_TEXT_INSET)
		split.note:ClearAllPoints()
		split.note:SetPoint("TOPLEFT", frame, "TOPLEFT", slot + inset, -y)
		split.note:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -y)
		split.note:SetHeight(list.rowHeight)
		y = y + pitch
	end
	return max(list.rowHeight, y - spacing)
end

local function Pitches(space, pitch)
	if not space or pitch <= 0 then
		return 0
	end
	return max(0, floor(space / pitch + 0.001))
end

local function PlaceSplit(list, split, row)
	local panel = list.panel
	local gap = Spacing(list)
	local pitch = list.rowHeight + gap
	local shown, note = split.used, split.noted
	local height = LayoutSplit(list, split, shown, note)
	local need = pitch > 0 and max(1, math.ceil((height + gap) / pitch)) or 1
	local rowBottom, rowTop = Logic.Plain(row.frame:GetBottom()), Logic.Plain(row.frame:GetTop())
	local panelBottom, panelTop = Logic.Plain(panel:GetBottom()), Logic.Plain(panel:GetTop())
	local holderBottom, panelHeight = Logic.Plain(list.holder:GetBottom()), Logic.Plain(panel:GetHeight())
	local below = true
	if rowBottom and rowTop and panelBottom and panelTop then
		local floorAt = panelBottom + list.pad
		local roomBelow = Pitches(rowBottom - floorAt, pitch)
		local roomGrown = holderBottom and Pitches(rowBottom - (holderBottom + list.pad), pitch) or roomBelow
		local roomAbove = Pitches(panelTop - Widgets.Snap(panel, list:Top()) - rowTop, pitch)
		if need <= roomBelow then
			below = true
		elseif need <= roomGrown then
			below = true
			panel:SetHeight(panelHeight + (floorAt - (rowBottom - need * pitch)))
			split.grew = true
		elseif need <= roomAbove then
			below = false
		else
			below = roomGrown >= roomAbove
			local room = max(1, below and roomGrown or roomAbove)
			if below and roomGrown > roomBelow then
				panel:SetHeight(panelHeight + (floorAt - (rowBottom - room * pitch)))
				split.grew = true
			end
			while (note or shown > 1) and math.ceil((height + gap) / pitch) > room do
				if note then
					note = false
				else
					shown = shown - 1
				end
				height = LayoutSplit(list, split, shown, note)
			end
			need = min(room, max(1, math.ceil((height + gap) / pitch)))
		end
	end
	local frame = split.frame
	frame:SetHeight(need * pitch - gap)
	frame:ClearAllPoints()
	if below then
		frame:SetPoint("TOPLEFT", row.frame, "BOTTOMLEFT", 0, -gap)
		frame:SetPoint("TOPRIGHT", row.frame, "BOTTOMRIGHT", 0, -gap)
	else
		frame:SetPoint("BOTTOMLEFT", row.frame, "TOPLEFT", 0, gap)
		frame:SetPoint("BOTTOMRIGHT", row.frame, "TOPRIGHT", 0, gap)
	end
	local hidden = split.hidden
	for n = 1, need do
		local other = list.rows[below and row.index + n or row.index - n]
		if other and other.frame:IsShown() then
			other.frame:Hide()
			hidden[#hidden + 1] = other
		end
	end
end

local function Uncover(list, split)
	local hidden = split.hidden
	for n = #hidden, 1, -1 do
		local row = hidden[n]
		if row.index <= (list.count or 0) then
			row.frame:Show()
		end
		hidden[n] = nil
	end
end

local HideSplit

local function ShowSplit(list, row)
	local split = list.split or NewSplit(list)
	split:Clear()
	if list.rowSplit(split, list, row.index) ~= true then
		split.frame:Hide()
		return false
	end
	SplitStyle(list, split)
	Uncover(list, split)
	PlaceSplit(list, split, row)
	split.row = row
	split.frame:Show()
	return true
end

local function Reopen(list, row)
	if row.index <= (list.count or 0) and row.index <= (list.capacity or 0) and row.frame:IsShown() then
		ShowSplit(list, row)
	else
		HideSplit(list)
	end
end

function HideSplit(list)
	local split = list.split
	if split then
		split.frame:Hide()
		Uncover(list, split)
		if split.grew then
			split.grew = false
			list:Fit()
		end
	end
end

function RowEnter(list, row)
	local frame = row.frame
	local splits = list.rowSplits ~= nil and list.rowSplits(list, row.index) == true
	if row.more then
		row.more:SetShown(splits)
	end
	if splits and list.rowSplit and ShowSplit(list, row) then
		return
	end
	local content = list.rowTooltip or list.tooltip
	if not content then
		return
	end
	local tip = Widgets.Tooltip()
	tip:SetOwner(frame, Inward(frame))
	local filled
	if list.rowTooltip then
		filled = list.rowTooltip(tip, list, row.index)
	else
		filled = content(tip, frame)
	end
	if filled == false then
		tip:Hide()
		return
	end
	tip:Show()
end

function RowLeave(list, row)
	if row.more then
		row.more:Hide()
	end
	HideSplit(list)
	local tip = Widgets.Tooltip()
	if tip:IsOwned(row.frame) then
		tip:Hide()
	end
end

local function RowUnits(list)
	local section = list.section
	local em = ns.Get(section .. ".fontSize") * K.Theme.FontScale()
	local text = em + TEXT_AIR
	if not list.block then
		text = text + PILL_GAP + PILL_HEIGHT
	end
	return max(ns.Get(section .. ".rowHeight"), text)
end

function List:MinRow()
	return Widgets.Snap(self.panel, RowUnits(self))
end

local function HeightUnits(list)
	local _, height = Size(list.holder, list.width, list.height)
	local settings = list.key and K.Layout and K.Layout.Get and K.Layout.Get(list.key)
	local units = settings and Logic.Plain(settings.height)
	local half = K.Scale.Pixel(1) / Widgets.ScaleFactor(list.holder) / 2
	if units and abs(units - height) <= half + 1e-6 then
		return units
	end
	return height
end

function List:Capacity()
	local pad = self.block and BLOCK_PAD or self.panel.chrome:InsetUnits()
	return Logic.FitRows(HeightUnits(self) - self:Top(pad) - pad, RowUnits(self), ns.Get(self.section .. ".spacing"))
end

function List:Top(pad)
	pad = pad or self.pad
	if not ns.Get(self.section .. ".title") then
		return pad
	end
	if self.block then
		return BLOCK_TOP
	end
	return pad + Widgets.SECTION_CAP_HEIGHT + Tokens.Size(CAP_GAP)
end

local function Recolor(list, row)
	local r, g, b = ns.BarColor(list.section, row.class, row.reaction, row.school, list.block)
	if row.r ~= r or row.g ~= g or row.b ~= b then
		row.r, row.g, row.b = r, g, b
		row.bar:SetBarColor(r, g, b, 1)
	end
end

function StyleRow(list, row)
	local section = list.section
	local figures = list.block and "number" or nil
	ns.ApplyFont(row.name, section)
	ns.ApplyFont(row.value, section, nil, figures)
	ns.ApplyFont(row.percent, section, nil, figures)
	if row.dot then
		ns.ApplyFont(row.dot, section, nil, figures)
	end
	local texture, reverse = ns.Get(section .. ".texture"), ns.Get(section .. ".fill") == "right"
	row.bar:SetBarTexture(texture)
	row.bar:SetReverseFill(reverse)
end

local function PlaceMore(list, row)
	local more = row.more
	if not more then
		return
	end
	local panel = list.panel
	local glyph = Widgets.Snap(panel, MORE_GLYPH)
	local reach = Widgets.TextWidth(row.name, 0)
	local room = Logic.Plain(row.name:GetWidth())
	if room and room > 0 then
		reach = math.min(reach, room)
	end
	more:ClearAllPoints()
	more:SetSize(glyph, glyph)
	more:SetPoint("LEFT", row.name, "LEFT", reach + list.gap, 0)
	Widgets.Tint(more, "muted")
end

local function FontSize(text, section)
	local _, size = text:GetFont()
	if not Logic.Plain(size) then
		return ns.Get(section .. ".fontSize") * K.Theme.FontScale()
	end
	return size
end

local function PlaceBlockText(list, row)
	local frame = row.frame
	local inset, gap = Widgets.Snap(list.panel, BLOCK_TEXT_INSET), list.gap
	local rowHeight = list.rowHeight
	local joined = list.percentWidth > 0 and row.joined == true
	row.percent:ClearAllPoints()
	Widgets.Point(row.percent, "RIGHT", frame, "RIGHT", -inset, 0)
	row.percent:SetHeight(rowHeight)
	row.percent:SetWidth(0)
	row.percent:SetShown(joined)
	row.value:ClearAllPoints()
	row.value:SetHeight(rowHeight)
	row.value:SetWidth(0)
	row.value:SetShown(list.valueWidth > 0)
	local dot = row.dot
	if dot then
		dot:Hide()
		dot:ClearAllPoints()
	end
	if joined and dot and list.valueWidth > 0 then
		local size = FontSize(row.value, list.section)
		local last = EndChar(row.amount, true)
		local first = EndChar(row.share, false)
		local step = K.Scale.Pixel(1) / Widgets.ScaleFactor(list.panel)
		local x, y = BarList.JoinOffsets(last, first, size, step, (row.value:GetFont()))
		dot:SetText(DOT)
		dot:SetWidth(0)
		dot:SetHeight(rowHeight)
		dot:SetPoint("RIGHT", row.percent, "LEFT", y, 0)
		dot:Show()
		row.value:SetPoint("RIGHT", dot, "LEFT", x, 0)
	else
		Widgets.Point(row.value, "RIGHT", frame, "RIGHT", -inset, 0)
	end
	row.name:ClearAllPoints()
	Widgets.Point(row.name, "LEFT", row.bar, "LEFT", inset, 0)
	if list.valueWidth > 0 then
		row.name:SetPoint("RIGHT", row.value, "LEFT", -gap, 0)
	else
		row.name:SetPoint("RIGHT", frame, "RIGHT", -inset, 0)
	end
	row.name:SetHeight(rowHeight)
end

function PlaceBlockRow(list, row, y, parent, x)
	local panel, frame, bar = list.panel, row.frame, row.bar
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", parent or panel, "TOPLEFT", x or list.pad, -y)
	frame:SetSize(max(1, list.barWidth), list.rowHeight)
	local slot = list.blockIcons and list.rowHeight or 0
	local reach = slot > 0 and slot + Widgets.Snap(panel, BLOCK_ICON_GAP) or 0
	bar.opts.width = max(1, list.barWidth - reach)
	bar.opts.height = list.rowHeight
	bar:Restyle()
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", reach, 0)
	bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
	local back, icon = row.back, row.icon
	back:ClearAllPoints()
	back:SetPoint("TOPLEFT", frame, "TOPLEFT")
	back:SetSize(max(1, slot), max(1, slot))
	back:SetShown(slot > 0)
	local edge = K.Scale.Pixel(1) / Widgets.ScaleFactor(panel)
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", back, "TOPLEFT", edge, -edge)
	icon:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -edge, edge)
	icon:SetShown(slot > 0 and row.iconSet == true)
	PlaceBlockText(list, row)
	PlaceMore(list, row)
end

local function PlaceRow(list, row, i)
	local rowHeight = list.rowHeight
	local spacing = Spacing(list)
	local pad, gap = list.pad, list.gap
	local panel = list.panel
	local y = Widgets.Snap(panel, list:Top()) + (i - 1) * (rowHeight + spacing)
	if list.block then
		PlaceBlockRow(list, row, y)
		return
	end
	local frame, bar = row.frame, row.bar
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -y)
	frame:SetSize(max(1, list.barWidth), rowHeight)
	local pill = Widgets.Snap(panel, PILL_HEIGHT)
	bar.opts.width = max(1, list.barWidth)
	bar.opts.height = pill
	bar:Restyle()
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
	local line = rowHeight - pill - Widgets.Snap(panel, PILL_GAP)
	row.percent:ClearAllPoints()
	row.percent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	row.percent:SetSize(list.percentWidth, line)
	row.value:ClearAllPoints()
	if list.percentWidth > 0 then
		row.value:SetPoint("RIGHT", row.percent, "LEFT", -gap, 0)
	else
		row.value:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	end
	row.value:SetSize(list.valueWidth, line)
	row.value:SetShown(list.valueWidth > 0)
	row.percent:SetShown(list.percentWidth > 0)
	local stop = list.valueWidth > 0 and row.value or list.percentWidth > 0 and row.percent or nil
	row.name:ClearAllPoints()
	row.icon:ClearAllPoints()
	if list.icons then
		row.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		row.icon:SetSize(line, line)
		row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", gap, 0)
	else
		row.icon:Hide()
		row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	end
	row.name:SetHeight(line)
	if stop then
		row.name:SetPoint("RIGHT", stop, "LEFT", -gap, 0)
	else
		row.name:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	end
	PlaceMore(list, row)
end

local function Floor(list, units)
	local snapped = Widgets.Snap(list.panel, units)
	if snapped > units then
		snapped = snapped - K.Scale.Pixel(1) / Widgets.ScaleFactor(list.panel)
	end
	return snapped
end

local function Pitch(list, capacity)
	local room, row = Room(list), list:MinRow()
	local spacing = Widgets.Snap(list.panel, ns.Get(list.section .. ".spacing"))
	if capacity < 1 then
		return row, spacing
	end
	if capacity > 1 and capacity * row + (capacity - 1) * spacing > room then
		local least = min(spacing, K.Scale.Pixel(1) / Widgets.ScaleFactor(list.panel))
		spacing = max(least, min(spacing, Floor(list, (room - capacity * row) / (capacity - 1))))
	end
	if capacity * row + (capacity - 1) * spacing > room then
		row = Floor(list, (room - (capacity - 1) * spacing) / capacity)
	end
	if not list.block then
		row = max(row, Floor(list, (room + spacing) / capacity - spacing))
	end
	return max(1, row), spacing
end

local function TextWidth(text)
	local width = Logic.Plain(text:GetStringWidth())
	if width and width > 0 then
		return width
	end
	local value = text:GetText()
	if Logic.IsSecret(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	local plain = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	local _, size = text:GetFont()
	size = Logic.Plain(size) or Tokens.Size("body")
	return #plain * size * ESTIMATE_EM
end

local function Fits(list)
	local aside = TextWidth(list.column)
	if not aside then
		return true
	end
	local room = list.barWidth or 0
	if ns.Get(list.section .. ".title") then
		local title = TextWidth(list.title)
		return not title or title + aside <= room - CAP_RESERVE
	end
	return aside <= room
end

local function HoldTitle(list)
	local title = list.title
	title:SetWidth(0)
	title:SetShown(true)
	if Fits(list) or not ns.Get(list.section .. ".title") then
		return
	end
	local aside = TextWidth(list.column) or 0
	local room = (list.barWidth or 0) - CAP_RESERVE - aside
	if room > 0 then
		title:SetWidth(room)
	else
		title:SetShown(false)
	end
end

function List:Restyle()
	local section = self.section
	self.pad = self.block and Widgets.Snap(self.panel, BLOCK_PAD) or self.panel.chrome:Inset()
	self.gap = Widgets.Snap(self.panel, Tokens.Size("gapSmall"))
	local width = Size(self.holder, self.width, self.height)
	local em = ns.Get(section .. ".fontSize") * K.Theme.FontScale()
	local columns = self.columns()
	self.blockIcons = self.block and self.iconsOn ~= nil and self.iconsOn() == true
	self.valueWidth = columns.value and Widgets.Snap(self.panel, em * VALUE_EMS) or 0
	self.percentWidth = columns.percent and Widgets.Snap(self.panel, em * PERCENT_EMS) or 0
	self.barWidth = Widgets.Snap(self.panel, width - 2 * self.pad)

	local titled = ns.Get(section .. ".title")
	local cap = self.cap
	cap.frame:SetShown(titled)
	cap.frame:ClearAllPoints()
	local capLeft = self.block and Widgets.Snap(self.panel, BLOCK_CAP_LEFT) or self.pad
	local capTop = self.block and Widgets.Snap(self.panel, BLOCK_CAP_TOP) or self.pad
	cap.frame:SetPoint("TOPLEFT", self.panel, "TOPLEFT", capLeft, -capTop)
	cap.frame:SetPoint("TOPRIGHT", self.panel, "TOPRIGHT", -self.pad, -capTop)
	cap:Restyle()
	if self.block then
		Widgets.TextColor(self.title, "capsGold")
	end
	if self.switchWords then
		self:SetSwitch(self.switchWords, self.switchSelected, self.switchShort)
	elseif cap.frame.counted then
		HoldTitle(self)
	end
	ns.ApplyFont(self.note, section)

	local open = self.split and self.split.frame:IsShown() and self.split.row or nil
	HideSplit(self)
	local capacity = self:Capacity()
	self.rowHeight, self.spacing = Pitch(self, capacity)
	for i = 1, #self.rows do
		local row = self.rows[i]
		StyleRow(self, row)
		PlaceRow(self, row, i)
		if i > capacity then
			row.frame:Hide()
		end
	end
	self.capacity = capacity
	self:Fit()
	self:Paint()
	if open then
		Reopen(self, open)
	end
end

function List:Fit()
	local _, holderHeight = Size(self.holder, self.width, self.height)
	local capacity, count = self.capacity or 0, self.count or 0
	local height = holderHeight
	if not self.block and (capacity < 1 or count < capacity) then
		local rows, spacing = max(1, min(count, capacity)), Spacing(self)
		height = Widgets.Snap(self.panel, self:Top()) + rows * (self.rowHeight + spacing) - spacing + self.pad
	end
	self.panel:SetHeight(max(1, min(height, holderHeight)))
end

function List:Row(i)
	local row = self.rows[i]
	if not row then
		row = NewRow(self, i)
		self.rows[i] = row
		StyleRow(self, row)
		PlaceRow(self, row, i)
	end
	return row
end

function FillRow(list, row, name, classFile, reaction, value, maxValue, valueText, percentText, schoolToken)
	row.frame:Show()
	row.bar:SetBarRange(0, maxValue)
	row.bar:SetBarValue(value)
	row.name:SetText(name)
	PlaceMore(list, row)
	row.value:SetText(valueText)
	if list.block then
		row.joined = percentText ~= ""
		row.amount = valueText
		row.share = percentText
		row.percent:SetText(percentText)
		if row.dot then
			row.dot:SetText(DOT)
		end
		PlaceBlockText(list, row)
	else
		row.percent:SetText(percentText)
		row.value:SetShown(list.valueWidth > 0)
		row.percent:SetShown(list.percentWidth > 0)
	end
	row.class, row.reaction, row.school = classFile, reaction, schoolToken
	Recolor(list, row)
end

function List:SetRow(i, name, classFile, reaction, value, maxValue, valueText, percentText, icon, schoolToken)
	local row = self:Row(i)
	if self.icons then
		row.icon:SetTexture(icon)
		row.icon:SetShown(Logic.IsSecret(icon) or icon ~= nil)
	end
	FillRow(self, row, name, classFile, reaction, value, maxValue, valueText, percentText, schoolToken)
end

function List:Finish(count, note)
	for i = count + 1, #self.rows do
		self.rows[i].frame:Hide()
	end
	self.count = count
	if count == 0 then
		self:SetRest(nil)
	end
	if note then
		self.note:SetText(note)
		self.note:Show()
	else
		self.note:Hide()
	end
	self:Fit()
	local split = self.split
	if split and split.frame:IsShown() and split.row then
		Reopen(self, split.row)
	end
end

function SetIcon(list, row, texture, atlas, left, right, top, bottom)
	local icon = row.icon
	local set = atlas ~= nil or Logic.IsSecret(texture) or texture ~= nil
	if atlas then
		if row.iconAtlas ~= atlas then
			icon:SetAtlas(atlas)
		end
	elseif set then
		icon:SetTexture(texture)
		if left then
			icon:SetTexCoord(left, right, top, bottom)
		else
			icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
		end
	end
	row.iconAtlas = atlas
	row.iconSet = set
	icon:SetShown(set and list.blockIcons == true)
end

function List:SetRowIcon(i, texture, atlas, left, right, top, bottom)
	SetIcon(self, self:Row(i), texture, atlas, left, right, top, bottom)
end

function List:SetIcons(shown)
	shown = shown == true
	if self.block or self.icons == shown then
		return
	end
	self.icons = shown
	for i = 1, #self.rows do
		PlaceRow(self, self.rows[i], i)
	end
end

local function SetAside(list, text)
	if Logic.IsSecret(text) then
		list.cap:SetAside(" ")
		list.column:SetText(text)
		return
	end
	list.cap:SetAside(text)
end

function List:SetTitle(text)
	self.titleText = nil
	self.switchFirst = nil
	self.cap:SetTitle(text)
end

function List:SetColumn(text, short)
	self.switchWords = nil
	self.title:SetWidth(0)
	SetAside(self, text)
	if short and short ~= text and ns.Get(self.section .. ".title") and not Fits(self) then
		SetAside(self, short)
	end
	HoldTitle(self)
end

local function Hex(name)
	local r, g, b = Widgets.Rgba(name)
	return string.format("|cff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local function SwitchText(words, selected, only)
	local parts = {}
	for i, word in ipairs(words) do
		if not only or i == selected then
			parts[#parts + 1] = Hex(i == selected and "giltLit" or "muted") .. word .. "|r"
		end
	end
	return table.concat(parts, SWITCH_GAP)
end

function List:PaintTitleSwitch()
	local first, second, selected = self.switchFirst, self.switchSecond, self.switchPick
	local hot = self.hot == true
	if not first or (self.titleText and first == self.paintFirst and second == self.paintSecond and selected == self.paintPick and hot == self.paintHot) then
		return
	end
	self.paintFirst, self.paintSecond, self.paintPick, self.paintHot = first, second, selected, hot
	local Upper = K.Locale.Upper
	local text
	if hot then
		text = Hex("capsGold") .. Upper(selected == 2 and second or first) .. "|r"
	else
		text = Hex(selected == 1 and "capsGold" or "muted") .. Upper(first) .. "|r" .. SWITCH_GAP .. Hex(selected == 2 and "capsGold" or "muted") .. Upper(second) .. "|r"
	end
	if text ~= self.titleText then
		self.titleText = text
		self.title:SetText(text)
	end
end

function List:SetTitleSwitch(first, second, selected)
	self.switchFirst, self.switchSecond, self.switchPick = first, second, selected
	self:PaintTitleSwitch()
end

function List:ShowRest()
	if self.hasRest then
		SetAside(self, self.rest)
	else
		SetAside(self, "")
	end
end

function List:SetSwitch(words, selected, short)
	local switch = self.switch
	if not switch then
		return
	end
	switch:SetShown(ns.Get(self.section .. ".title"))
	self.switchWords, self.switchSelected, self.switchShort = words, selected, short
	self.title:SetWidth(0)
	self.title:SetShown(true)
	if self.block and not self.hot then
		self:ShowRest()
		HoldTitle(self)
		return
	end
	self.cap:SetAside(SwitchText(words, selected))
	if Fits(self) then
		return
	end
	if short and short[selected] then
		local narrow = {}
		for i, word in ipairs(words) do
			narrow[i] = short[i] or word
		end
		self.cap:SetAside(SwitchText(narrow, selected))
		if Fits(self) then
			return
		end
		words = narrow
	end
	self.cap:SetAside(SwitchText(words, selected, true))
	HoldTitle(self)
end

function List:ShowSwitch()
	self:PaintTitleSwitch()
	if self.switchWords then
		self:SetSwitch(self.switchWords, self.switchSelected, self.switchShort)
	end
end

function List:SetRest(text)
	self.rest = text
	self.hasRest = type(text) == "string"
	if self.block and self.switchWords and not self.hot then
		self:ShowRest()
		HoldTitle(self)
	end
end

function List:Paint()
	local level = self.warning or Logic.NO_WARNING
	if level == Logic.DANGER then
		Widgets.TextColor(self.column, "hostile")
	elseif level == Logic.WARNING then
		Widgets.TextColor(self.column, "neutral")
	else
		Widgets.TextColor(self.column, "textEmphasis")
	end
	for i = 1, #self.rows do
		Recolor(self, self.rows[i])
	end
end

function List:SetWarning(level)
	if self.warning == level then
		return
	end
	self.warning = level
	self:Paint()
end

function BarList.New(parent, section, opts)
	local list = setmetatable({}, { __index = List })
	list.section = section
	list.width, list.height = opts.width, opts.height
	list.columns = opts.columns
	list.onRowClick = opts.onRowClick
	list.tooltip = opts.tooltip
	list.rowTooltip = opts.rowTooltip
	list.rowSplits = opts.rowSplits
	list.rowSplit = opts.rowSplit
	list.block = opts.block == true
	list.iconsOn = opts.icons
	list.key = opts.key
	list.icons = false
	list.rows = {}
	list.count = 0
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(opts.width, opts.height)
	list.holder = holder
	local panel = Widgets.Panel(holder, {})
	panel:SetPoint("TOPLEFT", holder, "TOPLEFT")
	panel:SetPoint("TOPRIGHT", holder, "TOPRIGHT")
	panel:SetHeight(opts.height)
	list.panel = panel
	list.cap = Widgets.RailCap(panel, {})
	list.title, list.column = list.cap.title, list.cap.aside
	list.title:SetWordWrap(false)
	list.note = Text(panel, "CENTER")
	list.note:SetTextColor(Tokens.Color("textDisabled"))
	list.note:SetPoint("CENTER", panel, "CENTER", 0, -floor(Tokens.Size("gapMedium") / 2))
	list.note:Hide()
	if opts.onClick then
		panel:EnableMouse(true)
		panel:HookScript("OnMouseUp", function(_, button)
			opts.onClick(list, button)
		end)
	end
	if opts.tooltip then
		Widgets.AttachTooltip(panel, opts.tooltip, Inward)
	end
	if opts.onTitle then
		local hit = CreateFrame("Frame", nil, panel)
		hit:SetFrameLevel(panel:GetFrameLevel() + 2)
		hit:SetAllPoints(list.title)
		hit:EnableMouse(true)
		hit:SetScript("OnMouseUp", function(_, button)
			opts.onTitle(list, button)
		end)
		if opts.titleTooltip then
			Widgets.AttachTooltip(hit, opts.titleTooltip, Inward)
		end
		list.titleHit = hit
	end
	if opts.onWheel then
		panel:EnableMouseWheel(true)
		panel:SetScript("OnMouseWheel", function(_, delta)
			opts.onWheel(list, delta)
		end)
	end
	if opts.onSwitch then
		local switch = CreateFrame("Frame", nil, panel)
		switch:SetFrameLevel(panel:GetFrameLevel() + 2)
		if list.block then
			switch:SetPoint("TOPRIGHT", list.cap.frame, "TOPRIGHT")
			switch:SetPoint("BOTTOMRIGHT", list.cap.frame, "BOTTOMRIGHT")
			if list.titleHit then
				switch:SetPoint("LEFT", list.titleHit, "RIGHT")
			else
				switch:SetWidth(BLOCK_SWITCH_REACH)
			end
			switch:HookScript("OnEnter", function()
				list.hot = true
				list:ShowSwitch()
			end)
			switch:HookScript("OnLeave", function()
				list.hot = false
				list:ShowSwitch()
			end)
		else
			switch:SetAllPoints(list.column)
		end
		switch:EnableMouse(true)
		switch:SetScript("OnMouseUp", function(_, button)
			opts.onSwitch(list, button)
		end)
		if opts.switchTooltip then
			list.switchTooltip = opts.switchTooltip
			Widgets.AttachTooltip(switch, opts.switchTooltip, Inward)
		end
		list.switch = switch
	end
	holder:HookScript("OnSizeChanged", function()
		list:Restyle()
	end)
	Widgets.Track(list)
	list:Restyle()
	return list
end
