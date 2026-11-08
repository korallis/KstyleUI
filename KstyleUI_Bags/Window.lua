-- Window.lua: a KstyleUI bag window: a glass panel with search, sort, slot grids per section and a footer with free slots and money.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Scale = K.Widgets, K.Tokens, K.Scale
local Data, Slot, Settings, L = ns.Data, ns.Slot, ns.Settings, ns.L
local floor, max, min = math.floor, math.max, math.min

local Window = {}
Window.__index = Window
ns.Window = Window

local MIN_CONTENT_WIDTH = 240
local MIN_SEARCH_WIDTH = 120
local SORT_WIDTH = 64
local REFRESH_DELAY = 0.2
local FOOTER_HEIGHT = 20
local STRATA = "MEDIUM"
local ANCHOR_FRACTIONS = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local function Snap(win, units)
	return Widgets.Snap(win.panel, units)
end

local function Plain(value)
	return Data.Plain(value, "number")
end

local function NewSection(win, spec)
	local panel = win.panel
	local view = CreateFrame("Frame", nil, panel)
	local grid = CreateFrame("Frame", nil, view)
	local section = { spec = spec, view = view, grid = grid, bagFrames = {}, order = {}, scroll = 0, rows = 0, visibleRows = 0 }
	view:SetScript("OnMouseWheel", function(_, delta)
		win:Scroll(section, delta)
	end)
	if spec.caption then
		section.caption = Widgets.Text(panel, "caption", "text")
		Widgets.SetText(section.caption, spec.caption)
	end
	return section
end

function Window.New(spec)
	local win = setmetatable({ spec = spec, sections = {}, slots = {}, query = nil, shownBags = {}, buttons = {} }, Window)
	local panel = Widgets.Panel(Scale.Root(), {
		title = spec.title,
		close = true,
		escape = true,
		hidden = true,
		movable = true,
		strata = STRATA,
		onMoved = function()
			win:SavePosition()
		end,
		onClose = function()
			win:Closed()
		end,
	})
	panel:SetToplevel(true)
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	win.panel = panel
	win.search = Widgets.EditBox(panel, {
		placeholder = L["Search..."],
		onChange = function(text)
			win:SetQuery(text)
		end,
	})
	win.sortButton = Widgets.Button(panel, {
		text = L["Sort"],
		width = SORT_WIDTH,
		onClick = function()
			if spec.sort then
				spec.sort(win)
			end
		end,
	})
	for i, sectionSpec in ipairs(spec.sections) do
		win.sections[i] = NewSection(win, sectionSpec)
	end
	win.footerLine = panel:CreateTexture(nil, "ARTWORK")
	win.footerLine:SetTexture((Tokens.Texture("divider")))
	win.free = Widgets.Text(panel, "caption", "text")
	win.free:SetJustifyH("LEFT")
	win.money = Widgets.Text(panel, "body", "textEmphasis")
	win.money:SetJustifyH("RIGHT")
	local restyle = panel.Restyle
	panel.Restyle = function(self)
		restyle(self)
		if win.built then
			win:Layout(true)
		end
	end
	Widgets.Place(panel, spec.key, spec.position, { label = spec.label, module = Settings.MODULE, scalable = true })
	win.scale = panel:GetScale()
	win.built = true
	return win
end

function Window:Slot(bag, slot)
	local bagSlots = self.slots[bag]
	return bagSlots and bagSlots[slot]
end

function Window:IsShown()
	return self.panel:IsShown() == true
end

function Window:BagFrame(section, bag)
	local frame = section.bagFrames[bag]
	if not frame then
		frame = CreateFrame("Frame", nil, section.grid)
		frame:SetAllPoints(section.grid)
		frame:SetID(bag)
		section.bagFrames[bag] = frame
	end
	return frame
end

function Window:QueueCreate()
	if self.createQueued then
		return
	end
	self.createQueued = true
	ns.Log("item buttons wait for the end of combat: one made in lockdown cannot use items")
	K.Combat.Queue(function()
		self.createQueued = false
		self:Refresh()
	end)
end

function Window:Ensure(section)
	local order = section.order
	for i = #order, 1, -1 do
		order[i] = nil
	end
	local shownBags = self.shownBags
	for bag in pairs(shownBags) do
		shownBags[bag] = nil
	end
	for _, bag in ipairs(section.spec.bags()) do
		shownBags[bag] = true
		local size = Data.NumSlots(bag)
		local bagSlots = self.slots[bag]
		if not bagSlots then
			bagSlots = {}
			self.slots[bag] = bagSlots
		end
		local frame = self:BagFrame(section, bag)
		frame:Show()
		for slotID = 1, size do
			local slot = bagSlots[slotID]
			if not slot then
				if InCombatLockdown() then
					self:QueueCreate()
				else
					slot = Slot.New(frame, slotID, { secure = true, bag = bag })
					bagSlots[slotID] = slot
				end
			end
			if slot then
				order[#order + 1] = slot
			end
		end
		for slotID, slot in pairs(bagSlots) do
			if slotID > size then
				slot.button:Hide()
			end
		end
	end
	for bag, frame in pairs(section.bagFrames) do
		if not shownBags[bag] then
			frame:Hide()
		end
	end
	return order
end

function Window:Scroll(section, delta)
	local maxScroll = max(0, section.rows - section.visibleRows)
	local scroll = min(maxScroll, max(0, section.scroll - (Plain(delta) or 0)))
	if scroll ~= section.scroll then
		section.scroll = scroll
		self:PlaceSlots(section)
	end
end

function Window:PlaceSlots(section)
	local geometry = self.geometry
	if not geometry then
		return
	end
	local size, spacing, growth = geometry.size, geometry.spacing, geometry.growth
	local step = size + spacing
	local cols, rows = section.cols, section.rows
	section.grid:ClearAllPoints()
	section.grid:SetPoint("TOPLEFT", section.view, "TOPLEFT", 0, section.scroll * step)
	section.grid:SetSize(max(1, section.width), max(1, rows * step))
	local first, last = section.scroll, section.scroll + section.visibleRows - 1
	for i, slot in ipairs(section.order) do
		local button = slot.button
		if Widgets.MayMove(button) then
			local x, y = Data.Cell(i, cols, rows, size, spacing, growth)
			local row = floor(-y / step + 0.5)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", section.grid, "TOPLEFT", x, y)
			button:SetShown(row >= first and row <= last)
		end
	end
end

function Window:Layout(force)
	local panel = self.panel
	if not Widgets.MayMove(panel) then
		return
	end
	local columns = Settings.Get(self.spec.columns or "columns")
	local rowsLimit = Settings.Get("rows")
	local size, spacing = Snap(self, Settings.Get("slotSize")), Snap(self, Settings.Get("spacing"))
	self.geometry = { size = size, spacing = spacing, growth = Settings.Get("growth") }
	local pad = Widgets.WindowInset(panel)
	local gap = Snap(self, Tokens.Size("gapMedium"))
	local rowHeight = Snap(self, Tokens.Size("rowHeight") + Tokens.Size("gapSmall"))
	local sortWidth = Snap(self, SORT_WIDTH)
	local buttonsWidth = 0
	for _, button in ipairs(self.buttons) do
		if button:IsShown() then
			buttonsWidth = buttonsWidth + (Plain(button:GetWidth()) or SORT_WIDTH) + gap
		end
	end
	local contentWidth = max(Snap(self, MIN_CONTENT_WIDTH), Snap(self, MIN_SEARCH_WIDTH) + gap + sortWidth + buttonsWidth)
	for _, section in ipairs(self.sections) do
		local count = #section.order
		section.cols, section.rows = Data.Grid(count, columns)
		section.visibleRows = rowsLimit > 0 and min(section.rows, rowsLimit) or section.rows
		section.scroll = min(section.scroll, max(0, section.rows - section.visibleRows))
		section.width, section.height = Data.Size(section.cols, section.visibleRows, size, spacing)
		contentWidth = max(contentWidth, section.width)
		for _, slot in ipairs(section.order) do
			Slot.Layout(slot, size, force)
		end
	end
	local content = panel.content
	local top = 0
	if self.spec.above then
		top = self.spec.above(self, content, top, contentWidth)
	end
	local searchWidth = max(1, contentWidth - sortWidth - gap - buttonsWidth)
	if force or self.search.opts.width ~= searchWidth or self.search.opts.height ~= rowHeight then
		self.search.opts.width, self.search.opts.height = searchWidth, rowHeight
		self.search:Restyle()
	end
	self.search:ClearAllPoints()
	self.search:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
	self.sortButton:ClearAllPoints()
	self.sortButton:SetPoint("TOPRIGHT", content, "TOPLEFT", contentWidth, -top)
	local anchor = self.sortButton
	for _, button in ipairs(self.buttons) do
		if button:IsShown() then
			button:ClearAllPoints()
			button:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -gap, 0)
			anchor = button
		end
	end
	top = top + rowHeight + gap
	if self.spec.below then
		top = self.spec.below(self, content, top, contentWidth)
	end
	for _, section in ipairs(self.sections) do
		local shown = #section.order > 0
		section.view:SetShown(shown)
		section.view:SetClipsChildren(rowsLimit > 0)
		section.view:EnableMouseWheel(rowsLimit > 0)
		if section.caption then
			section.caption:SetShown(shown)
		end
		if shown then
			if section.caption then
				section.caption:ClearAllPoints()
				section.caption:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
				top = top + Snap(self, Widgets.TextHeight(section.caption, Tokens.Size("caption"))) + Snap(self, Tokens.Size("gapSmall"))
			end
			section.view:ClearAllPoints()
			section.view:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
			section.view:SetSize(max(1, section.width), max(1, section.height))
			self:PlaceSlots(section)
			top = top + section.height + gap
		end
	end
	local border = Widgets.Border(panel)
	self.footerLine:ClearAllPoints()
	self.footerLine:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
	self.footerLine:SetSize(contentWidth, border)
	top = top + border + Snap(self, Tokens.Size("gapSmall"))
	local footer = Snap(self, FOOTER_HEIGHT)
	self.free:ClearAllPoints()
	self.free:SetPoint("LEFT", content, "TOPLEFT", 0, -(top + footer / 2))
	self.money:ClearAllPoints()
	self.money:SetPoint("RIGHT", content, "TOPLEFT", contentWidth, -(top + footer / 2))
	top = top + footer
	local _, _, _, _, offsetY = content:GetPoint(1)
	local contentTop = -(Plain(offsetY) or 0)
	Widgets.Size(panel, contentWidth + 2 * pad, contentTop + top + pad)
	self:Paint(force)
end

function Window:Paint(force)
	local r, g, b = Settings.Accent()
	self.footerLine:SetVertexColor(Widgets.Rgba("edgeFaint"))
	local path, size, flags = Settings.Font()
	local key = table.concat({ tostring(path), tostring(size), tostring(flags), tostring(r), tostring(g), tostring(b) }, ":")
	if not force and key == self.styleKey then
		return
	end
	self.styleKey = key
	for _, bagSlots in pairs(self.slots) do
		for _, slot in pairs(bagSlots) do
			Slot.Style(slot)
			Slot.Paint(slot)
		end
	end
end

function Window:UpdateSlot(slot)
	local record = Data.Read(slot.bag, slot.id, slot.record)
	local level = not record.empty and Settings.Get("showItemLevel") and Data.ItemLevel(record) or nil
	Slot.Update(slot, record, level, Data.Matches(record, self.query))
	local container = C_Container
	if not record.empty and container and container.GetContainerItemCooldown then
		Slot.SetCooldown(slot, container.GetContainerItemCooldown(slot.bag, slot.id))
	else
		Slot.SetCooldown(slot)
	end
end

function Window:UpdateLock(bag, slotID)
	local slot = self:Slot(bag, slotID)
	if slot then
		local record = Data.Read(bag, slotID, slot.record)
		Slot.SetLocked(slot, record.locked)
	end
end

function Window:UpdateCooldowns()
	local container = C_Container
	if not container or not container.GetContainerItemCooldown then
		return
	end
	for _, section in ipairs(self.sections) do
		for _, slot in ipairs(section.order) do
			if not slot.state.empty then
				Slot.SetCooldown(slot, container.GetContainerItemCooldown(slot.bag, slot.id))
			end
		end
	end
end

function Window:UpdateFooter()
	local free, total = 0, 0
	for _, section in ipairs(self.sections) do
		if section.spec.free then
			for _, slot in ipairs(section.order) do
				total = total + 1
				if slot.state.empty then
					free = free + 1
				end
			end
		end
	end
	Widgets.SetText(self.free, string.format(L["%d/%d free"], free, total))
	self:UpdateMoney()
end

function Window:UpdateMoney()
	local money = type(GetMoney) == "function" and Plain(GetMoney()) or nil
	if not money then
		self.money:SetText("")
		return
	end
	if type(GetMoneyString) == "function" then
		self.money:SetText(GetMoneyString(money, true))
	else
		self.money:SetText(tostring(money))
	end
end

function Window:Refresh(force)
	for _, section in ipairs(self.sections) do
		self:Ensure(section)
	end
	if self.spec.refresh then
		self.spec.refresh(self)
	end
	self:Layout(force)
	for _, section in ipairs(self.sections) do
		for _, slot in ipairs(section.order) do
			self:UpdateSlot(slot)
		end
	end
	self:UpdateFooter()
end

function Window:RefreshSoon()
	if self.refreshQueued then
		return
	end
	self.refreshQueued = true
	C_Timer.After(REFRESH_DELAY, function()
		self.refreshQueued = false
		if self.open then
			self:Refresh()
		end
	end)
end

function Window:AddButton(button)
	self.buttons[#self.buttons + 1] = button
	return button
end

function Window:Prepare()
	for _, section in ipairs(self.sections) do
		self:Ensure(section)
	end
end

function Window:SetQuery(text)
	local query = Data.Query(text)
	if query == self.query then
		return
	end
	self.query = query
	for _, section in ipairs(self.sections) do
		for _, slot in ipairs(section.order) do
			Slot.SetMatch(slot, Data.Matches(slot.record, query))
		end
	end
end

function Window:Open()
	if self.open then
		self:Refresh()
		return
	end
	self.open = true
	self:Refresh()
	self.panel:Open()
end

function Window:Close()
	if not self.open then
		return
	end
	self.panel:Close()
end

function Window:Hide()
	self.open = false
	self.panel:Hide()
end

function Window:Closed()
	self.open = false
	if self.search:HasFocus() then
		self.search:ClearFocus()
	end
	local newItems = C_NewItems
	for _, section in ipairs(self.sections) do
		for _, slot in ipairs(section.order) do
			if slot.state.isNew then
				Slot.Unmark(slot)
				if newItems and newItems.RemoveNewItem then
					newItems.RemoveNewItem(slot.bag, slot.id)
				end
			end
		end
	end
	if self.spec.onClosed then
		K.Call(self.spec.onClosed, self)
	end
end

function Window:ScaleChanged()
	local scale = Plain(self.panel:GetScale())
	if scale and scale ~= self.scale then
		self.scale = scale
		Widgets.RestyleAll()
	end
end

function Window:SavePosition()
	local layout = K.Layout
	if type(layout) ~= "table" or type(layout.Update) ~= "function" or type(layout.Get) ~= "function" then
		return
	end
	local settings = layout.Get(self.spec.key)
	local fraction = settings and ANCHOR_FRACTIONS[settings.anchor]
	if not fraction then
		return
	end
	local panel, root = self.panel, Scale.Root()
	local left, bottom, width, height = Plain(panel:GetLeft()), Plain(panel:GetBottom()), Plain(panel:GetWidth()), Plain(panel:GetHeight())
	local rootLeft, rootBottom, rootWidth, rootHeight = Plain(root:GetLeft()) or 0, Plain(root:GetBottom()) or 0, Plain(root:GetWidth()), Plain(root:GetHeight())
	local scale, rootScale = Plain(panel:GetEffectiveScale()), Plain(root:GetEffectiveScale())
	if not (left and bottom and width and height and rootWidth and rootHeight and scale and rootScale) or rootScale <= 0 then
		return
	end
	local f = scale / rootScale
	local x = (left + width * fraction[1]) * f - (rootLeft + rootWidth * fraction[1])
	local y = (bottom + height * fraction[2]) * f - (rootBottom + rootHeight * fraction[2])
	K.Call(layout.Update, self.spec.key, { x = floor(x + 0.5), y = floor(y + 0.5) })
end
