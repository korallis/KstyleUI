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

local function Place(row, section)
	local list = row.rail
	local inset = Widgets.Snap(list, Tokens.Size("gapLarge"))
	if section then
		inset = inset + Widgets.Snap(list, SECTION_INSET)
	end
	row.label:ClearAllPoints()
	row.label:SetPoint("LEFT", row, "LEFT", inset, 0)
	row.label:SetPoint("RIGHT", row, "RIGHT", -Widgets.Snap(list, Tokens.Size("gapSmall")), 0)
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
	Place(row, false)
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
	return row
end

local function UpdateRow(row, entry)
	row.entry = entry
	row.page = not IsSection(entry) and entry or nil
	Place(row, IsSection(entry))
	Widgets.SetText(row.label, entry.label)
	Paint(row)
end

local function HeightOf(entry)
	if IsSection(entry) then
		return Rail.SECTION_HEIGHT
	end
	return Rail.ROW_HEIGHT
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
