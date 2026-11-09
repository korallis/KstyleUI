-- ScrollList.lua: the virtualised list, with recycled rows of one height or each its own, eased scrolling, a short bounce at either end and staggered row fades.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale, Motion = ns.Tokens, ns.Scale, ns.Motion
local ceil, floor, max, min = math.ceil, math.floor, math.max, math.min

local WHEEL_ROWS = 3
local BAR_WIDTH = 3
local BAR_GAP = 2
local THUMB_MIN = 16
local THUMB_ALPHA, THUMB_HOVER_ALPHA = 0.35, 1

local List = {}

local function RowHeight(self)
	return self.opts.rowHeight or Tokens.Size("rowHeight")
end

local function ViewHeight(self)
	local height = self:GetHeight()
	if type(height) ~= "number" or height <= 0 then
		return 0
	end
	return height
end

function List:GetViewWidth()
	local width = self:GetWidth()
	if type(width) ~= "number" or width <= 0 then
		return 0
	end
	return max(0, width - Widgets.Snap(self, BAR_WIDTH + 2 * BAR_GAP))
end

local function Measure(self)
	local heightOf = self.opts.heightOf
	if not heightOf then
		self.tops, self.shortest = nil, nil
		return
	end
	local tops, width, fallback = self.tops or {}, self:GetViewWidth(), RowHeight(self)
	local y, shortest = 0, nil
	for i, item in ipairs(self.items) do
		tops[i] = y
		local ok, h = ns.Call(heightOf, item, i, self, width)
		h = ok and type(h) == "number" and h > 0 and Widgets.Snap(self, h) or fallback
		shortest = shortest and min(shortest, h) or h
		y = y + h
	end
	local n = #self.items
	tops[n + 1] = y
	for i = #tops, n + 2, -1 do
		tops[i] = nil
	end
	self.tops, self.shortest, self.measuredWidth = tops, shortest or fallback, width
end

local function ContentHeight(self)
	local tops = self.tops
	if tops then
		return tops[#self.items + 1] or 0
	end
	return #self.items * RowHeight(self)
end

local function ItemTop(self, index)
	local tops = self.tops
	if tops then
		return tops[index] or 0
	end
	return (index - 1) * RowHeight(self)
end

local function ItemHeight(self, index)
	local tops = self.tops
	if tops then
		return (tops[index + 1] or 0) - (tops[index] or 0)
	end
	return RowHeight(self)
end

local function FirstIndex(self, offset)
	local tops = self.tops
	if not tops then
		return max(0, floor(offset / RowHeight(self))) + 1
	end
	local low, high = 1, #self.items
	while low < high do
		local mid = floor((low + high + 1) / 2)
		if tops[mid] <= offset then
			low = mid
		else
			high = mid - 1
		end
	end
	return max(1, low)
end

local function ItemLabel(item)
	if type(item) == "table" then
		return item.label
	end
	return item
end

local function DefaultUpdate(row, item)
	Widgets.SetText(row.label, ItemLabel(item))
end

local function RowClick(row)
	local list = row.list
	local onClick = list.opts.onClick
	if onClick and row.index then
		ns.Call(onClick, list.items[row.index], row.index, list)
	end
end

local function RowPaint(row)
	if row.label then
		row.label:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, row.hoverT or 0))
	end
	if row.highlight then
		row.highlight:SetVertexColor(Widgets.Rgba("white", 0.05 * (row.hoverT or 0)))
	end
end

local function DefaultRow(list)
	local row = CreateFrame("Button", nil, list.view)
	row.label = Widgets.Text(row, "body", "text")
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.label:SetPoint("LEFT", row, "LEFT", Widgets.Snap(list, Tokens.Size("gapMedium")), 0)
	row.label:SetPoint("RIGHT", row, "RIGHT", -Widgets.Snap(list, Tokens.Size("gapMedium")), 0)
	row.highlight = row:CreateTexture(nil, "BACKGROUND")
	row.highlight:SetColorTexture(Tokens.Color("white"))
	row.highlight:SetAllPoints(row)
	row.Paint = RowPaint
	row.onClick = RowClick
	Widgets.HookPointer(row)
	RowPaint(row)
	return row
end

local function MakeRow(self)
	local create = self.opts.createRow
	local row = create and create(self) or DefaultRow(self)
	row.list = self
	row:SetHeight(Widgets.Snap(self, RowHeight(self)))
	return row
end

local function EnsureRows(self)
	local needed = ceil(ViewHeight(self) / (self.shortest or RowHeight(self))) + 1
	for i = #self.rows + 1, needed do
		self.rows[i] = MakeRow(self)
	end
end

function List:GetMaxOffset()
	return max(0, ContentHeight(self) - ViewHeight(self))
end

function List:GetOffset()
	return self.offset
end

function List:GetData()
	return self.items
end

function List:Refresh(force)
	local offset = self.offset
	local first = FirstIndex(self, offset) - 1
	local update = self.opts.updateRow or DefaultUpdate
	local sized = self.tops ~= nil
	local bottom = offset + ViewHeight(self)
	for i, row in ipairs(self.rows) do
		local index = first + i
		local item = self.items[index]
		if sized and item ~= nil and ItemTop(self, index) >= bottom then
			item = nil
		end
		if item ~= nil then
			local y = Widgets.Snap(self, offset - ItemTop(self, index))
			row:SetPoint("TOPLEFT", self.view, "TOPLEFT", 0, y)
			row:SetPoint("TOPRIGHT", self.view, "TOPRIGHT", 0, y)
			if force or row.index ~= index then
				row.index = index
				if sized then
					row:SetHeight(ItemHeight(self, index))
				end
				ns.Call(update, row, item, index, self)
			end
			row:Show()
		else
			row.index = nil
			row:Hide()
		end
	end
	self:PaintBar()
end

function List:SetOffset(offset)
	self.offset = offset
	self:Refresh()
end

function List:PaintBar()
	local view = ViewHeight(self)
	local content = ContentHeight(self)
	local overflow = content > view and view > 0
	self.bar:SetShown(overflow)
	if not overflow then
		return
	end
	local thumb = max(Widgets.Snap(self, THUMB_MIN), Widgets.Snap(self, view * view / content))
	local travel = view - thumb
	local maxOffset = self:GetMaxOffset()
	local share = maxOffset > 0 and min(1, max(0, self.offset / maxOffset)) or 0
	self.thumbHeight = thumb
	self.thumbTop = Widgets.Snap(self, travel * share)
	self.thumb:SetHeight(thumb)
	self.thumb:SetPoint("TOP", self.bar, "TOP", 0, -self.thumbTop)
	self.thumb:SetVertexColor(Widgets.MixTokens("text", THUMB_ALPHA, "accent", THUMB_HOVER_ALPHA, self.hoverT or 0))
end

function List:Paint()
	self:PaintBar()
end

local function BounceBack(self)
	Motion.Tween(self, "SetOffset", self.offset, self.bounceTo, Tokens.Duration("hover"), "outQuad")
end

function List:ScrollTo(offset, instant)
	local target = min(self:GetMaxOffset(), max(0, offset))
	self.target = target
	if instant then
		Motion.Tween(self, "SetOffset", target, target, 0)
	else
		Motion.Tween(self, "SetOffset", self.offset, target, Tokens.Duration("fade"), Tokens.Easing("hover"))
	end
end

function List:ScrollToIndex(index, instant, align)
	local rowHeight = ItemHeight(self, index)
	local top = ItemTop(self, index)
	local view = ViewHeight(self)
	local offset = self.target or self.offset
	if align == "TOP" then
		self:ScrollTo(top, instant)
	elseif top < offset then
		self:ScrollTo(top, instant)
	elseif top + rowHeight > offset + view then
		self:ScrollTo(top + rowHeight - view, instant)
	end
end

function List:Scroll(delta)
	local maxOffset = self:GetMaxOffset()
	if maxOffset <= 0 then
		return
	end
	local step = RowHeight(self) * WHEEL_ROWS * (delta > 0 and -1 or 1)
	local current = self.target or self.offset
	local target = current + step
	if (target < 0 and current <= 0) or (target > maxOffset and current >= maxOffset) then
		if Motion.ReducedMotion() then
			return
		end
		local edge = target < 0 and 0 or maxOffset
		self.bounceTo = edge
		self.target = edge
		local reach = Tokens.Size("gapMedium") * (target < 0 and -1 or 1)
		Motion.Tween(self, "SetOffset", self.offset, edge + reach, Tokens.Duration("hover"), "outQuad", BounceBack)
		return
	end
	self:ScrollTo(target)
end

local function Reveal(self, t)
	local stagger = Tokens.Duration("listStagger")
	local fade = Tokens.Duration("fade")
	for i, row in ipairs(self.rows) do
		row:SetAlpha(min(1, max(0, (t - (i - 1) * stagger) / fade)))
	end
end

function List:SetData(items, keepOffset)
	self.items = items or {}
	Measure(self)
	EnsureRows(self)
	for _, row in ipairs(self.rows) do
		row.index = nil
	end
	local offset = keepOffset and min(self.offset, self:GetMaxOffset()) or 0
	self.target = nil
	Motion.Tween(self, "SetOffset", offset, offset, 0)
	if not keepOffset and self.opts.stagger ~= false then
		local total = (#self.rows - 1) * Tokens.Duration("listStagger") + Tokens.Duration("fade")
		Motion.Tween(self, Reveal, 0, total, total, "linear")
	end
end

function List:Restyle()
	local opts = self.opts
	if opts.width and opts.height then
		Widgets.Size(self, opts.width, opts.height)
	end
	local barSpace = Widgets.Snap(self, BAR_WIDTH + 2 * BAR_GAP)
	self.view:ClearAllPoints()
	self.view:SetPoint("TOPLEFT", self, "TOPLEFT")
	self.view:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -barSpace, 0)
	self.bar:ClearAllPoints()
	self.bar:SetPoint("TOPRIGHT", self, "TOPRIGHT", -Widgets.Snap(self, BAR_GAP), 0)
	self.bar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -Widgets.Snap(self, BAR_GAP), 0)
	self.bar:SetWidth(Widgets.Snap(self, BAR_WIDTH))
	self.thumb:SetWidth(Widgets.Snap(self, BAR_WIDTH))
	self.track:SetVertexColor(Widgets.Rgba("track"))
	Measure(self)
	EnsureRows(self)
	if not self.tops then
		for _, row in ipairs(self.rows) do
			row:SetHeight(Widgets.Snap(self, RowHeight(self)))
		end
	end
	self:Refresh(true)
end

local function CursorInBar(bar)
	local top, scale = bar:GetTop(), bar:GetEffectiveScale()
	local _, y = GetCursorPosition()
	if type(top) ~= "number" or type(scale) ~= "number" or scale <= 0 or type(y) ~= "number" then
		return nil
	end
	return top - y / scale
end

local function ThumbDrag(bar)
	local self = bar.list
	local depth, height = CursorInBar(bar), bar:GetHeight()
	local travel = type(height) == "number" and height - (self.thumbHeight or 0) or 0
	if not depth or travel <= 0 then
		return
	end
	local share = min(1, max(0, (depth - self.grab) / travel))
	self:ScrollTo(share * self:GetMaxOffset(), true)
end

local function ThumbGrab(bar)
	local self = bar.list
	local depth = CursorInBar(bar)
	if not depth then
		return
	end
	local thumbTop = self.thumbTop or 0
	local thumbHeight = self.thumbHeight or 0
	if depth >= thumbTop and depth <= thumbTop + thumbHeight then
		self.grab = depth - thumbTop
	else
		self.grab = thumbHeight / 2
	end
	bar:SetScript("OnUpdate", ThumbDrag)
	ThumbDrag(bar)
end

function Widgets.ScrollList(parent, opts)
	opts = opts or {}
	local list = CreateFrame("Frame", opts.name, parent or Scale.Root())
	for k, fn in pairs(List) do
		list[k] = fn
	end
	list.opts = opts
	list.items = {}
	list.rows = {}
	list.offset = 0
	list.view = CreateFrame("Frame", nil, list)
	list.view:SetClipsChildren(true)
	list.bar = CreateFrame("Button", nil, list)
	list.bar.list = list
	list.track = list.bar:CreateTexture(nil, "BACKGROUND")
	list.track:SetColorTexture(Tokens.Color("white"))
	list.track:SetAllPoints(list.bar)
	list.thumb = list.bar:CreateTexture(nil, "ARTWORK")
	list.thumb:SetColorTexture(Tokens.Color("white"))
	list.bar:SetScript("OnMouseDown", ThumbGrab)
	list.bar:SetScript("OnMouseUp", function(bar)
		bar:SetScript("OnUpdate", nil)
	end)
	list.bar:SetScript("OnHide", function(bar)
		bar:SetScript("OnUpdate", nil)
	end)
	list.bar:SetScript("OnEnter", function()
		Widgets.Hover(list, true)
	end)
	list.bar:SetScript("OnLeave", function()
		Widgets.Hover(list, false)
	end)
	list:SetScript("OnSizeChanged", function(self)
		if self.tops and self:GetViewWidth() ~= self.measuredWidth then
			Measure(self)
		end
		EnsureRows(self)
		local maxOffset = self:GetMaxOffset()
		if self.offset > maxOffset or (self.target and self.target > maxOffset) then
			self.target = nil
			Motion.Tween(self, "SetOffset", maxOffset, maxOffset, 0)
		end
		self:Refresh(true)
	end)
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(self, delta)
		self:Scroll(delta)
	end)
	list:Restyle()
	return Widgets.Track(list)
end
