-- Rail.lua: the category rail, one entry per page with an accent bar and wash on the selected page, and under it the open page's sections, the current one marked.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens

local Rail = {}
ns.Rail = Rail

Rail.ROW_HEIGHT = 34
Rail.SECTION_HEIGHT = 26
local BAR_WIDTH = 2
local MARK_WIDTH = 2
local MARK_HEIGHT = 10
local SECTION_INSET = 12
local MAX_LINES = 2
local WASH_ALPHA = 0.18
local HOVER_ALPHA = 0.05

local lower = string.lower

local function IsSection(entry)
	return type(entry) == "table" and entry.section == true
end

local function PaintPage(row)
	local selected = row.entry.id == row.rail.selected
	local hover = row.hoverT or 0
	row.bar:SetShown(selected)
	Widgets.Tint(row.bar, "accent")
	local r, g, b = Widgets.Rgba("accent")
	if selected then
		if row.wash.SetGradient and CreateColor then
			row.wash:SetColorTexture(Tokens.Color("white"))
			row.wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, WASH_ALPHA), CreateColor(r, g, b, 0))
		else
			row.wash:SetColorTexture(r, g, b, WASH_ALPHA)
		end
		row.wash:Show()
		Widgets.TextColor(row.label, "textEmphasis")
	else
		row.wash:Hide()
		row.label:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, hover))
	end
end

local function PaintSection(row)
	local current = row.entry.index == row.rail.current
	local hover = row.hoverT or 0
	row.mark:SetShown(current)
	Widgets.Tint(row.mark, "accent")
	if current then
		Widgets.TextColor(row.label, "textEmphasis")
	else
		row.label:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, hover))
	end
end

local function Paint(row)
	local entry = row.entry
	if not entry then
		return
	end
	if IsSection(entry) then
		row.bar:Hide()
		row.wash:Hide()
		PaintSection(row)
	else
		row.mark:Hide()
		PaintPage(row)
	end
	row.hover:SetVertexColor(Widgets.Rgba("white", HOVER_ALPHA * (row.hoverT or 0)))
end

local function Column(list, section)
	local inset = Widgets.Snap(list, Tokens.Size("gapLarge"))
	if section then
		inset = inset + Widgets.Snap(list, SECTION_INSET)
	end
	local trail = Widgets.Snap(list, Tokens.Size("gapSmall"))
	local width = list.GetViewWidth and list:GetViewWidth()
	if type(width) ~= "number" or Widgets.IsSecret(width) or width <= 0 then
		width = nil
	end
	return inset, trail, width and math.max(1, width - inset - trail) or nil
end

local function Lines(list, entry)
	local _, _, column = Column(list, IsSection(entry))
	if not column then
		return 1
	end
	Widgets.SetText(list.gauge, entry.label)
	if Widgets.TextWidth(list.gauge, 0) > column then
		return MAX_LINES
	end
	return 1
end

local function Place(row, entry)
	local list = row.rail
	local section = IsSection(entry)
	local inset, trail, column = Column(list, section)
	local lines = Lines(list, entry)
	row.label:ClearAllPoints()
	row.label:SetPoint("LEFT", row, "LEFT", inset, 0)
	row.label:SetPoint("RIGHT", row, "RIGHT", -trail, 0)
	if column then
		row.label:SetWidth(column)
	end
	row.label:SetWordWrap(lines > 1)
	if row.label.SetMaxLines then
		row.label:SetMaxLines(lines)
	end
	row.mark:ClearAllPoints()
	row.mark:SetPoint("RIGHT", row.label, "LEFT", -Widgets.Snap(list, Tokens.Size("gapSmall")), 0)
	Widgets.Size(row.mark, MARK_WIDTH, MARK_HEIGHT)
end

local function CreateRow(list)
	local row = CreateFrame("Button", nil, list.view)
	row.rail = list
	row.wash = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.wash:SetAllPoints(row)
	row.hover = row:CreateTexture(nil, "BACKGROUND", nil, 0)
	row.hover:SetColorTexture(Tokens.Color("white"))
	row.hover:SetAllPoints(row)
	row.bar = row:CreateTexture(nil, "ARTWORK")
	row.bar:SetColorTexture(Tokens.Color("white"))
	row.bar:SetPoint("TOPLEFT", row, "TOPLEFT")
	row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
	row.bar:SetWidth(Widgets.Snap(list, BAR_WIDTH))
	row.mark = row:CreateTexture(nil, "ARTWORK")
	row.mark:SetColorTexture(Tokens.Color("white"))
	row.label = Widgets.Text(row, "body", "text")
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.Paint = Paint
	row.onClick = function(self)
		local entry = self.entry
		if not entry then
			return
		end
		if IsSection(entry) then
			if self.rail.onSection then
				K.Call(self.rail.onSection, entry)
			end
		elseif self.rail.onSelect then
			K.Call(self.rail.onSelect, entry.id)
		end
	end
	Widgets.HookPointer(row)
	ns.Rows.FullLabel(row, row.label, function(self)
		return self.entry and self.entry.label
	end)
	return row
end

local function UpdateRow(row, entry)
	row.entry = entry
	row.page = not IsSection(entry) and entry or nil
	Place(row, entry)
	Widgets.SetText(row.label, entry.label)
	Paint(row)
end

local function HeightOf(entry, _, list)
	local height = IsSection(entry) and Rail.SECTION_HEIGHT or Rail.ROW_HEIGHT
	if not (list and list.gauge) then
		return height
	end
	return height + (Lines(list, entry) - 1) * Widgets.LineHeight(list.gauge)
end

function Rail.Entries(pages, selected, sections)
	local out = {}
	for _, page in ipairs(pages) do
		out[#out + 1] = page
		if page.id == selected then
			local name = lower(tostring(page.label))
			for _, section in ipairs(sections or {}) do
				if lower(tostring(section.label)) ~= name then
					out[#out + 1] = { section = true, label = section.label, index = section.index, page = page.id }
				end
			end
		end
	end
	return out
end

local function PaintAll(self)
	for _, row in ipairs(self.rows) do
		if row.entry then
			Paint(row)
		end
	end
end

function Rail.Create(parent, onSelect, onSection)
	local rail = Widgets.ScrollList(parent, {
		rowHeight = Rail.ROW_HEIGHT,
		heightOf = HeightOf,
		createRow = CreateRow,
		updateRow = UpdateRow,
	})
	rail.gauge = Widgets.Text(rail, "body", "text")
	rail.gauge:Hide()
	rail.onSelect = onSelect
	rail.onSection = onSection
	rail.SetPages = function(self, pages, sections, keepOffset)
		self.pages = pages
		self:SetData(Rail.Entries(pages, self.selected, sections), keepOffset)
	end
	rail.Select = function(self, id, sections)
		self.selected = id
		self.current = nil
		self:SetData(Rail.Entries(self.pages or {}, id, sections), true)
		local data = self:GetData()
		for i, entry in ipairs(data) do
			if not IsSection(entry) and entry.id == id then
				local last = i
				while IsSection(data[last + 1]) do
					last = last + 1
				end
				self:ScrollToIndex(last, true)
				self:ScrollToIndex(i, true)
				break
			end
		end
	end
	rail.SetCurrent = function(self, index)
		if self.current == index then
			return
		end
		self.current = index
		PaintAll(self)
	end
	local restyle = rail.Restyle
	rail.Restyle = function(self)
		restyle(self)
		PaintAll(self)
	end
	return rail
end
