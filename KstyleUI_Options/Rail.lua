-- Rail.lua: the category rail, one entry per page, with an accent bar and wash on the selected page.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens

local Rail = {}
ns.Rail = Rail

Rail.ROW_HEIGHT = 34
local BAR_WIDTH = 2
local WASH_ALPHA = 0.18
local HOVER_ALPHA = 0.05

local function Paint(row)
	local selected = row.page ~= nil and row.page.id == row.rail.selected
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
	row.hover:SetVertexColor(Widgets.Rgba("white", HOVER_ALPHA * hover))
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
	row.label = Widgets.Text(row, "body", "text")
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.label:SetPoint("LEFT", row, "LEFT", Widgets.Snap(list, Tokens.Size("gapLarge")), 0)
	row.label:SetPoint("RIGHT", row, "RIGHT", -Widgets.Snap(list, Tokens.Size("gapSmall")), 0)
	row.Paint = Paint
	row.onClick = function(self)
		if self.page and self.rail.onSelect then
			K.Call(self.rail.onSelect, self.page.id)
		end
	end
	Widgets.HookPointer(row)
	return row
end

local function UpdateRow(row, page)
	row.page = page
	Widgets.SetText(row.label, page.label)
	Paint(row)
end

function Rail.Create(parent, onSelect)
	local rail = Widgets.ScrollList(parent, {
		rowHeight = Rail.ROW_HEIGHT,
		createRow = CreateRow,
		updateRow = UpdateRow,
	})
	rail.onSelect = onSelect
	rail.Select = function(self, id)
		self.selected = id
		for _, row in ipairs(self.rows) do
			if row.page then
				Paint(row)
			end
		end
		local data = self:GetData()
		for i, page in ipairs(data) do
			if page.id == id then
				self:ScrollToIndex(i, true)
				break
			end
		end
	end
	local restyle = rail.Restyle
	rail.Restyle = function(self)
		restyle(self)
		for _, row in ipairs(self.rows) do
			if row.page then
				Paint(row)
			end
		end
	end
	return rail
end
