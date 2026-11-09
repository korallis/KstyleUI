-- BarList.lua: the Lumen meter card the damage and threat meters share: a section cap with the title and a muted aside or a fight switch, full-width rows that carry an optional icon, a name, a value and a share over a flat 4-unit class pill, and a split that opens under a hovered row, inside the card.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Logic = ns.Logic
local max, min, floor = math.max, math.min, math.floor

local VALUE_EMS = 3.4
local PERCENT_EMS = 2.6
local FILL_ALPHA = 0.5
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
local SPLIT_LINE_GAP = 2

local BarList = {}
ns.BarList = BarList
ns.FILL_ALPHA = FILL_ALPHA
BarList.PILL_HEIGHT = PILL_HEIGHT
BarList.PILL_GAP = PILL_GAP

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

local RowEnter, RowLeave

local function NewRow(list, index)
	local section = list.section
	local width = list.barWidth or Tokens.Size("buffBarWidth")
	local frame = CreateFrame("Frame", nil, list.panel)
	local bar = Widgets.StatusBar(frame, {
		texture = ns.Get(section .. ".texture"),
		background = "buttonFill",
		smooth = true,
		min = 0,
		max = 1,
		value = 0,
		width = width,
		height = PILL_HEIGHT,
	})
	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	icon:Hide()
	local row = {
		index = index,
		frame = frame,
		bar = bar,
		icon = icon,
		name = Text(frame, "LEFT"),
		value = Text(frame, "RIGHT"),
		percent = Text(frame, "RIGHT"),
	}
	if list.onRowClick then
		frame:EnableMouse(true)
		frame:SetScript("OnMouseUp", function(_, button)
			list.onRowClick(list, row.index, button)
		end)
	end
	if list.rowSplits then
		local more = frame:CreateTexture(nil, "OVERLAY")
		more:SetTexture((Tokens.Texture("glyphChevron")))
		more:Hide()
		row.more = more
	end
	if list.rowSplit or list.rowTooltip or list.tooltip then
		frame:HookScript("OnEnter", function()
			RowEnter(list, row)
		end)
		frame:HookScript("OnLeave", function()
			RowLeave(list, row)
		end)
	end
	row.name:SetTextColor(Tokens.Color("textEmphasis"))
	row.value:SetTextColor(Tokens.Color("textEmphasis"))
	row.percent:SetTextColor(Tokens.Color("text"))
	return row
end

local function Spacing(list)
	return Widgets.Snap(list.panel, ns.Get(list.section .. ".spacing"))
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

function Split:AddLine(left, right)
	local n = self.used + 1
	local line = self.lines[n]
	if not line then
		local frame = CreateFrame("Frame", nil, self.frame)
		line = { frame = frame, left = Text(frame, "LEFT"), right = Text(frame, "RIGHT") }
		line.left:SetTextColor(Tokens.Color("text"))
		line.right:SetTextColor(Tokens.Color("textEmphasis"))
		self.lines[n] = line
	end
	self.used = n
	Widgets.SetText(line.left, left)
	Widgets.SetText(line.right, right)
	line.frame:Show()
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
	local split = setmetatable({ frame = frame, lines = {}, used = 0, hidden = {} }, Split)
	split.chrome = Widgets.Chrome(frame, { shape = "panel", fill = "surface", shadow = true })
	split.note = Text(frame, "LEFT")
	split.note:SetTextColor(Tokens.Color("muted"))
	split.note:Hide()
	list.split = split
	return split
end

local function SplitStyle(list, split)
	local section = list.section
	for _, line in ipairs(split.lines) do
		ns.ApplyFont(line.left, section)
		ns.ApplyFont(line.right, section)
	end
	ns.ApplyFont(split.note, section)
end

local function LayoutSplit(list, split, shown, note)
	local panel = list.panel
	local pad = split.chrome:Inset()
	local gap = list.gap
	local em = ns.Get(list.section .. ".fontSize") * K.Theme.FontScale()
	local line = Widgets.Snap(panel, em + TEXT_AIR)
	local step = Widgets.Snap(panel, SPLIT_LINE_GAP)
	local y = pad
	local frame = split.frame
	for i = 1, split.used do
		local entry = split.lines[i]
		if i <= shown then
			entry.frame:ClearAllPoints()
			entry.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -y)
			entry.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -y)
			entry.frame:SetHeight(line)
			entry.right:ClearAllPoints()
			entry.right:SetPoint("TOPRIGHT", entry.frame, "TOPRIGHT", 0, 0)
			entry.right:SetHeight(line)
			entry.left:ClearAllPoints()
			entry.left:SetPoint("TOPLEFT", entry.frame, "TOPLEFT", 0, 0)
			entry.left:SetPoint("RIGHT", entry.right, "LEFT", -gap, 0)
			entry.left:SetHeight(line)
			entry.frame:Show()
			y = y + line + step
		else
			entry.frame:Hide()
		end
	end
	split.note:SetShown(note)
	if note then
		split.note:ClearAllPoints()
		split.note:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -y)
		split.note:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -y)
		split.note:SetHeight(line)
		y = y + line + step
	end
	return Widgets.Snap(panel, y - step + pad)
end

local function Pitches(space, pitch)
	if not space or pitch <= 0 then
		return 0
	end
	return max(0, floor(space / pitch + 0.001))
end

local function PlaceSplit(list, split, row)
	local panel = list.panel
	local gap = list.gap
	local pitch = list.rowHeight + Spacing(list)
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
	split.chrome:Restyle()
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

function List:MinRow()
	local section = self.section
	local em = ns.Get(section .. ".fontSize") * K.Theme.FontScale()
	local text = em + TEXT_AIR + PILL_GAP + PILL_HEIGHT
	return Widgets.Snap(self.panel, max(ns.Get(section .. ".rowHeight"), text))
end

function List:Capacity()
	return Logic.FitRows(Room(self), self:MinRow(), Spacing(self))
end

function List:Top()
	local pad = self.pad
	if not ns.Get(self.section .. ".title") then
		return pad
	end
	return pad + Widgets.SECTION_CAP_HEIGHT + Tokens.Size(CAP_GAP)
end

local function Recolor(list, row)
	local r, g, b = ns.BarColor(list.section, row.class, row.reaction)
	if row.r ~= r or row.g ~= g or row.b ~= b then
		row.r, row.g, row.b = r, g, b
		row.bar:SetBarColor(r, g, b, 1)
	end
end

local function StyleRow(list, row)
	local section = list.section
	ns.ApplyFont(row.name, section)
	ns.ApplyFont(row.value, section)
	ns.ApplyFont(row.percent, section)
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

local function PlaceRow(list, row, i)
	local rowHeight = list.rowHeight
	local spacing = Spacing(list)
	local pad, gap = list.pad, list.gap
	local panel = list.panel
	local y = Widgets.Snap(panel, list:Top()) + (i - 1) * (rowHeight + spacing)
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

local function FillHeight(list)
	local fill = Logic.FillRows(Room(list), list:MinRow(), Spacing(list))
	local snapped = Widgets.Snap(list.panel, fill)
	if snapped > fill then
		snapped = snapped - K.Scale.Pixel(1) / Widgets.ScaleFactor(list.panel)
	end
	return max(1, snapped)
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
	self.pad = self.panel.chrome:Inset()
	self.gap = Widgets.Snap(self.panel, Tokens.Size("gapSmall"))
	local width = Size(self.holder, self.width, self.height)
	local em = ns.Get(section .. ".fontSize") * K.Theme.FontScale()
	local columns = self.columns()
	self.valueWidth = columns.value and Widgets.Snap(self.panel, em * VALUE_EMS) or 0
	self.percentWidth = columns.percent and Widgets.Snap(self.panel, em * PERCENT_EMS) or 0
	self.barWidth = Widgets.Snap(self.panel, width - 2 * self.pad)

	local titled = ns.Get(section .. ".title")
	local cap = self.cap
	cap.frame:SetShown(titled)
	cap.frame:ClearAllPoints()
	cap.frame:SetPoint("TOPLEFT", self.panel, "TOPLEFT", self.pad, -self.pad)
	cap.frame:SetPoint("TOPRIGHT", self.panel, "TOPRIGHT", -self.pad, -self.pad)
	cap:Restyle()
	if self.switchWords then
		self:SetSwitch(self.switchWords, self.switchSelected, self.switchShort)
	elseif cap.frame.counted then
		HoldTitle(self)
	end
	ns.ApplyFont(self.note, section)

	local open = self.split and self.split.frame:IsShown() and self.split.row or nil
	HideSplit(self)
	self.rowHeight = FillHeight(self)
	local capacity = self:Capacity()
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
	if capacity < 1 or count < capacity then
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

function List:SetRow(i, name, classFile, reaction, value, maxValue, valueText, percentText, icon)
	local row = self:Row(i)
	if self.icons then
		row.icon:SetTexture(icon)
		row.icon:SetShown(Logic.IsSecret(icon) or icon ~= nil)
	end
	row.frame:Show()
	row.bar:SetBarRange(0, maxValue)
	row.bar:SetBarValue(value)
	row.name:SetText(name)
	PlaceMore(self, row)
	row.value:SetText(valueText)
	row.percent:SetText(percentText)
	row.value:SetShown(self.valueWidth > 0)
	row.percent:SetShown(self.percentWidth > 0)
	row.class, row.reaction = classFile, reaction
	Recolor(self, row)
end

function List:Finish(count, note)
	for i = count + 1, #self.rows do
		self.rows[i].frame:Hide()
	end
	self.count = count
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

function List:SetIcons(shown)
	shown = shown == true
	if self.icons == shown then
		return
	end
	self.icons = shown
	for i = 1, #self.rows do
		PlaceRow(self, self.rows[i], i)
	end
end

function List:SetTitle(text)
	self.cap:SetTitle(text)
end

function List:SetColumn(text, short)
	self.switchWords = nil
	self.title:SetWidth(0)
	self.cap:SetAside(text)
	if short and short ~= text and ns.Get(self.section .. ".title") and not Fits(self) then
		self.cap:SetAside(short)
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

function List:SetSwitch(words, selected, short)
	local switch = self.switch
	if not switch then
		return
	end
	switch:SetShown(ns.Get(self.section .. ".title"))
	self.switchWords, self.switchSelected, self.switchShort = words, selected, short
	self.title:SetWidth(0)
	self.title:SetShown(true)
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

function List:Paint()
	local level = self.warning or Logic.NO_WARNING
	local chrome = self.panel.chrome
	if level == Logic.DANGER then
		chrome:SetEdge("hostile")
	elseif level == Logic.WARNING then
		chrome:SetEdge("neutral")
	else
		chrome:SetEdge("edgeInner")
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
	if level == Logic.DANGER then
		if not self.glow then
			self.glow = Widgets.Glow(self.panel, { kind = "proc", color = "hostile" })
		end
		self.glow:Start()
	elseif self.glow then
		self.glow:Stop()
	end
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
	if opts.onSwitch then
		local switch = CreateFrame("Frame", nil, panel)
		switch:SetFrameLevel(panel:GetFrameLevel() + 2)
		switch:SetAllPoints(list.column)
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
