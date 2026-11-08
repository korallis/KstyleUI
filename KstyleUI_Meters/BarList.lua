-- BarList.lua: the glass meter panel the damage and threat meters share: a title, a column heading and rows of bars with a name, a value and a percentage.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Logic = ns.Logic
local max, floor = math.max, math.floor

local VALUE_EMS = 3.4
local PERCENT_EMS = 2.6
local MARK_WIDTH = 24
local MARK_HEIGHT = 2

local BarList = {}
ns.BarList = BarList

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
	local bar = Widgets.StatusBar(list.panel, {
		texture = ns.Get(section .. ".texture"),
		background = "buttonFill",
		smooth = true,
		min = 0,
		max = 1,
		value = 0,
		width = list.barWidth or Tokens.Size("buffBarWidth"),
		height = ns.Get(section .. ".rowHeight"),
	})
	local row = {
		bar = bar,
		name = Text(bar, "LEFT"),
		value = Text(list.panel, "RIGHT"),
		percent = Text(list.panel, "RIGHT"),
	}
	row.name:SetTextColor(Tokens.Color("textEmphasis"))
	row.value:SetTextColor(Tokens.Color("textEmphasis"))
	row.percent:SetTextColor(Tokens.Color("text"))
	return row
end

function List:Capacity()
	local section = self.section
	local _, height = Size(self.holder, self.width, self.height)
	return Logic.FitRows(height - self:Top() - self.pad, ns.Get(section .. ".rowHeight"), ns.Get(section .. ".spacing"))
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
		row.bar:SetBarColor(r, g, b)
	end
end

local function StyleRow(list, row)
	local section = list.section
	ns.ApplyFont(row.name, section)
	ns.ApplyFont(row.value, section)
	ns.ApplyFont(row.percent, section)
	row.bar:SetBarTexture(ns.Get(section .. ".texture"))
	row.bar:SetReverseFill(ns.Get(section .. ".fill") == "right")
end

local function PlaceRow(list, row, i)
	local section = list.section
	local rowHeight = Widgets.Snap(list.panel, ns.Get(section .. ".rowHeight"))
	local spacing = Widgets.Snap(list.panel, ns.Get(section .. ".spacing"))
	local pad, gap = list.pad, list.gap
	local y = Widgets.Snap(list.panel, list:Top()) + (i - 1) * (rowHeight + spacing)
	local bar = row.bar
	bar.opts.width = max(1, list.barWidth)
	bar.opts.height = rowHeight
	bar:Restyle()
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", list.panel, "TOPLEFT", pad, -y)
	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", bar, "LEFT", gap, 0)
	row.name:SetPoint("RIGHT", bar, "RIGHT", -gap, 0)
	row.percent:ClearAllPoints()
	row.percent:SetPoint("RIGHT", list.panel, "TOPRIGHT", -pad, -y - rowHeight / 2)
	row.percent:SetWidth(list.percentWidth)
	row.value:ClearAllPoints()
	if list.percentWidth > 0 then
		row.value:SetPoint("RIGHT", row.percent, "LEFT", -gap, 0)
	else
		row.value:SetPoint("RIGHT", list.panel, "TOPRIGHT", -pad, -y - rowHeight / 2)
	end
	row.value:SetWidth(list.valueWidth)
	row.value:SetShown(list.valueWidth > 0)
	row.percent:SetShown(list.percentWidth > 0)
end

function List:Restyle()
	local section = self.section
	self.pad = Widgets.Snap(self.panel, Tokens.Size("gapMedium"))
	self.gap = Widgets.Snap(self.panel, Tokens.Size("gapSmall"))
	local width = Size(self.holder, self.width, self.height)
	local em = ns.Get(section .. ".fontSize") * K.Theme.FontScale()
	local columns = self.columns()
	self.valueWidth = columns.value and Widgets.Snap(self.panel, em * VALUE_EMS) or 0
	self.percentWidth = columns.percent and Widgets.Snap(self.panel, em * PERCENT_EMS) or 0
	local used = 0
	if self.valueWidth > 0 then
		used = used + self.valueWidth + self.gap
	end
	if self.percentWidth > 0 then
		used = used + self.percentWidth + self.gap
	end
	self.barWidth = Widgets.Snap(self.panel, width - 2 * self.pad - used)

	local titled = ns.Get(section .. ".title")
	self.title:SetShown(titled)
	self.column:SetShown(titled)
	self.mark:SetShown(titled)
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
	ns.ApplyFont(self.note, section)

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
	self:Paint()
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
	panel:SetAllPoints(holder)
	list.panel = panel
	list.title = Text(panel, "LEFT")
	list.title:SetTextColor(Tokens.Color("textEmphasis"))
	list.column = Text(panel, "RIGHT")
	list.column:SetTextColor(Tokens.Color("text"))
	list.mark = panel:CreateTexture(nil, "ARTWORK")
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
