-- BarList.lua: the glass meter panel the damage and threat meters share: a title over a rule, a column heading, and full-width rows that carry a name, a value and a share on a dimmed fill with a class-colour edge.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Logic = ns.Logic
local max, min, floor = math.max, math.min, math.floor

local VALUE_EMS = 3.4
local PERCENT_EMS = 2.6
local MARK_WIDTH = 24
local MARK_HEIGHT = 2
local FILL_ALPHA = 0.5
local EDGE_HEIGHT = 2
local TEXT_AIR = 2

local BarList = {}
ns.BarList = BarList
ns.FILL_ALPHA = FILL_ALPHA

local List = {}

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

local function NewRow(list)
	local section = list.section
	local width = list.barWidth or Tokens.Size("buffBarWidth")
	local bar = Widgets.StatusBar(list.panel, {
		texture = ns.Get(section .. ".texture"),
		background = "buttonFill",
		smooth = true,
		min = 0,
		max = 1,
		value = 0,
		width = width,
		height = ns.Get(section .. ".rowHeight"),
	})
	local edge = Widgets.StatusBar(bar, {
		texture = ns.Get(section .. ".texture"),
		background = false,
		smooth = true,
		min = 0,
		max = 1,
		value = 0,
		width = width,
		height = EDGE_HEIGHT,
	})
	local row = {
		bar = bar,
		edge = edge,
		name = Text(edge, "LEFT"),
		value = Text(edge, "RIGHT"),
		percent = Text(edge, "RIGHT"),
	}
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

function List:MinRow()
	local section = self.section
	local em = ns.Get(section .. ".fontSize") * K.Theme.FontScale()
	local text = em + 2 * Widgets.Snap(self.panel, EDGE_HEIGHT) + TEXT_AIR
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
	return pad + ns.Get(self.section .. ".titleSize") * K.Theme.FontScale() + Tokens.Size("gapMedium")
end

local function Recolor(list, row)
	local r, g, b = ns.BarColor(list.section, row.class, row.reaction)
	if row.r ~= r or row.g ~= g or row.b ~= b then
		row.r, row.g, row.b = r, g, b
		row.bar:SetBarColor(r, g, b, FILL_ALPHA)
		row.edge:SetBarColor(r, g, b)
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
	row.edge:SetBarTexture(texture)
	row.edge:SetReverseFill(reverse)
end

local function PlaceRow(list, row, i)
	local rowHeight = list.rowHeight
	local spacing = Spacing(list)
	local pad, gap = list.pad, list.gap
	local y = Widgets.Snap(list.panel, list:Top()) + (i - 1) * (rowHeight + spacing)
	local bar, edge = row.bar, row.edge
	bar.opts.width = max(1, list.barWidth)
	bar.opts.height = rowHeight
	bar:Restyle()
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", list.panel, "TOPLEFT", pad, -y)
	edge.opts.width = max(1, list.barWidth)
	edge.opts.height = Widgets.Snap(list.panel, EDGE_HEIGHT)
	edge:Restyle()
	edge:ClearAllPoints()
	edge:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
	edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
	row.percent:ClearAllPoints()
	row.percent:SetPoint("RIGHT", bar, "RIGHT", -gap, 0)
	row.percent:SetWidth(list.percentWidth)
	row.value:ClearAllPoints()
	if list.percentWidth > 0 then
		row.value:SetPoint("RIGHT", row.percent, "LEFT", -gap, 0)
	else
		row.value:SetPoint("RIGHT", bar, "RIGHT", -gap, 0)
	end
	row.value:SetWidth(list.valueWidth)
	row.value:SetShown(list.valueWidth > 0)
	row.percent:SetShown(list.percentWidth > 0)
	local stop = list.valueWidth > 0 and row.value or list.percentWidth > 0 and row.percent or nil
	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", bar, "LEFT", gap, 0)
	if stop then
		row.name:SetPoint("RIGHT", stop, "LEFT", -gap, 0)
	else
		row.name:SetPoint("RIGHT", bar, "RIGHT", -gap, 0)
	end
end

local function FillHeight(list)
	local fill = Logic.FillRows(Room(list), list:MinRow(), Spacing(list))
	local snapped = Widgets.Snap(list.panel, fill)
	if snapped > fill then
		snapped = snapped - K.Scale.Pixel(1) / Widgets.ScaleFactor(list.panel)
	end
	return max(1, snapped)
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
	self.title:SetShown(titled)
	self.column:SetShown(titled)
	self.mark:SetShown(titled)
	self.rule:SetShown(titled)
	ns.ApplyFont(self.title, section, "titleSize")
	ns.ApplyFont(self.column, section, "titleSize")
	self.title:ClearAllPoints()
	self.title:SetPoint("TOPLEFT", self.panel, "TOPLEFT", self.pad, -self.pad)
	self.column:ClearAllPoints()
	self.column:SetPoint("TOPRIGHT", self.panel, "TOPRIGHT", -self.pad, -self.pad)
	self.mark:ClearAllPoints()
	self.mark:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -Widgets.Snap(self.panel, Tokens.Size("gapTiny")))
	Widgets.Size(self.mark, MARK_WIDTH, MARK_HEIGHT)
	self.mark:SetVertexColor(ns.Accent())
	self.rule:ClearAllPoints()
	self.rule:SetPoint("LEFT", self.mark, "LEFT")
	self.rule:SetSize(self.barWidth, Widgets.Border(self.panel))
	Widgets.Tint(self.rule, "edgeInner")
	ns.ApplyFont(self.note, section)

	self.rowHeight = FillHeight(self)
	local capacity = self:Capacity()
	for i = 1, #self.rows do
		local row = self.rows[i]
		StyleRow(self, row)
		PlaceRow(self, row, i)
		if i > capacity then
			row.bar:Hide()
			row.value:Hide()
			row.percent:Hide()
		end
	end
	self.capacity = capacity
	self:Fit()
	self:Paint()
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
		row = NewRow(self)
		self.rows[i] = row
		StyleRow(self, row)
		PlaceRow(self, row, i)
	end
	return row
end

function List:SetRow(i, name, classFile, reaction, value, maxValue, valueText, percentText)
	local row = self:Row(i)
	row.bar:Show()
	row.bar:SetBarRange(0, maxValue)
	row.bar:SetBarValue(value)
	row.edge:SetBarRange(0, maxValue)
	row.edge:SetBarValue(value)
	row.name:SetText(name)
	row.value:SetText(valueText)
	row.percent:SetText(percentText)
	row.value:SetShown(self.valueWidth > 0)
	row.percent:SetShown(self.percentWidth > 0)
	row.class, row.reaction = classFile, reaction
	Recolor(self, row)
end

function List:Finish(count, note)
	for i = count + 1, #self.rows do
		local row = self.rows[i]
		row.bar:Hide()
		row.value:Hide()
		row.percent:Hide()
	end
	self.count = count
	if note then
		self.note:SetText(note)
		self.note:Show()
	else
		self.note:Hide()
	end
	self:Fit()
end

function List:SetTitle(text)
	if not Logic.IsSecret(text) and type(text) == "string" then
		text = text:upper()
	end
	self.title:SetText(text)
end

function List:SetColumn(text)
	if not Logic.IsSecret(text) and type(text) == "string" then
		text = text:upper()
	end
	self.column:SetText(text)
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
	self.mark:SetVertexColor(ns.Accent())
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
	list.title = Text(panel, "LEFT")
	list.title:SetTextColor(Tokens.Color("textEmphasis"))
	list.column = Text(panel, "RIGHT")
	list.column:SetTextColor(Tokens.Color("text"))
	list.rule = panel:CreateTexture(nil, "ARTWORK")
	list.rule:SetTexture((Tokens.Texture("divider")))
	list.mark = panel:CreateTexture(nil, "ARTWORK", nil, 1)
	list.mark:SetTexture((Tokens.Texture("divider")))
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
		Widgets.AttachTooltip(panel, opts.tooltip)
	end
	holder:HookScript("OnSizeChanged", function()
		list:Restyle()
	end)
	Widgets.Track(list)
	list:Restyle()
	return list
end
