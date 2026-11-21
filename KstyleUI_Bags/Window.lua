-- Window.lua: a KstyleUI bag window: a glass panel with search, sort, slot grids per section or per item category under Lumen section caps, and a footer with free slots and money.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Scale = K.Widgets, K.Tokens, K.Scale
local Data, Slot, Settings, L = ns.Data, ns.Slot, ns.Settings, ns.L
local floor, max, min = math.floor, math.max, math.min

local Window = {}
Window.__index = Window
ns.Window = Window

local MIN_CONTENT_WIDTH = 160
local MIN_SEARCH_WIDTH = 120
local SORT_WIDTH = 64
local REFRESH_DELAY = 0.2
local FOOTER_HEIGHT = 20
local SCREEN_MARGIN = 48
local CAP_ROOM = 20
local BIND_LABELS = { [2] = L["BoE"], [9] = L["WuE"] }
local COPPER_PER_SILVER, SILVER_PER_GOLD = 100, 100
local STRATA = "MEDIUM"
local windows = {}
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

local function NewCap(section, parent)
	section.cap = Widgets.SectionCap(parent, { text = section.spec.caption })
	local restyle = section.cap.Restyle
	section.cap.Restyle = function(self)
		restyle(self)
		local size = Settings.Get("capSize")
		if Settings.Get("readableHeaders") then
			local path, _, flags = Tokens.Font("caps")
			Widgets.ApplyFont(self.label, path, size * K.Theme.FontScale(), flags)
		elseif size ~= Settings.defaults.capSize then
			Widgets.CapsSize(self.label, nil, size / Settings.defaults.capSize)
		end
	end
end

local function NewSection(win, spec, group)
	local parent = group and win.stack or win.panel
	local view = CreateFrame("Frame", nil, parent)
	local grid = CreateFrame("Frame", nil, view)
	local section = { spec = spec, group = group, view = view, grid = grid, bagFrames = {}, order = {}, scroll = 0, rows = 0, visibleRows = 0, total = 0, value = 0 }
	if group then
		view:EnableMouse(true)
		view:SetScript("OnMouseUp", function(_, mouse)
			if mouse == "LeftButton" then
				win:Drop()
			end
		end)
		view:SetScript("OnReceiveDrag", function()
			win:Drop()
		end)
	end
	if not group then
		view:SetScript("OnMouseWheel", function(_, delta)
			win:Scroll(section, delta)
		end)
	end
	if spec.caption and not spec.lazy then
		NewCap(section, parent)
	end
	if spec.categories then
		section.groups = {}
	end
	return section
end

function Window:Grouped(section)
	local view = self.view
	return section.groups ~= nil and view ~= "grid" and (view == "bags" or Settings.Sections())
end

function Window:PinState()
	local main = self.sections[1]
	if not (self.spec.pins and Settings.Get("pins")) or self.remoteData then
		return false, false, false
	end
	local categories = self:Grouped(main) and self.view ~= "bags"
	local shown = categories or Settings.Get("pinsInGrid")
	return shown, categories and Settings.Get("pinsOnly"), shown and not categories and Settings.Get("pinsDim")
end

function Window:Match(slot, record)
	if not Data.Matches(record, self.query) then
		return false
	end
	return not (self.dimPins and not slot.pinned and record.itemID and self.dimPins[record.itemID])
end

local SLOT_RANK = {}
for i, loc in ipairs({
	"INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK", "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_BODY", "INVTYPE_TABARD",
	"INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_WEAPON",
	"INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE", "INVTYPE_RANGED",
	"INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC",
}) do
	SLOT_RANK[loc] = i
end

local function Join(a, b)
	return b and (a .. " \194\183 " .. b) or a
end

local function Global(name)
	return Data.Plain(_G[name], "string")
end

function Window.New(spec)
	local win = setmetatable({ spec = spec, sections = {}, slots = {}, query = nil, shownBags = {}, buttons = {}, gained = {}, opts = {} }, Window)
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
	win.originalHeader = panel.chrome.headerUnits
	win.viewport = CreateFrame("Frame", nil, panel)
	win.viewport:SetClipsChildren(true)
	win.viewport:EnableMouseWheel(true)
	win.viewport:SetScript("OnMouseWheel", function(_, delta)
		win:ScrollStack(delta)
	end)
	win.viewport:Hide()
	win.stack = CreateFrame("Frame", nil, win.viewport)
	win.stackScroll, win.stackHeight, win.viewportHeight = 0, 0, 0
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
			if spec.sort and not win.remoteData then
				spec.sort(win)
			end
		end,
	})
	win.placed = {}
	for i, sectionSpec in ipairs(spec.sections) do
		local section = NewSection(win, sectionSpec)
		section.key, section.clones = "section" .. i, sectionSpec.pins and {} or nil
		win.sections[i], win.pinSection = section, section.clones and section or win.pinSection
		table.insert(win.placed, sectionSpec.pins and 1 or #win.placed + 1, section)
	end
	if spec.pins then
		win.pin = function(slot)
			local record = Data.Read(slot.bag, slot.id, slot.record)
			if Settings.Get("pins") and record.itemID and not Data.CursorItem() then
				Data.TogglePin(record.itemID)
				win:Refresh()
			end
		end
	end
	win.footerLine = panel:CreateTexture(nil, "ARTWORK")
	win.footerLine:SetTexture((Tokens.Texture("divider")))
	win.free = Widgets.Text(panel, "caption", "text")
	win.free:SetJustifyH("LEFT")
	win.money = Widgets.Text(panel, "body", "textEmphasis")
	win.money:SetJustifyH("RIGHT")
	win.moneyHover = CreateFrame("Frame", nil, panel)
	win.moneyHover:SetAllPoints(win.money)
	win.moneyHover:SetScript("OnEnter", function(frame)
		win:GoldTooltip(frame)
	end)
	win.moneyHover:SetScript("OnLeave", function()
		if type(GameTooltip_Hide) == "function" then
			GameTooltip_Hide()
		end
	end)
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
	windows[#windows + 1] = win
	return win
end

function Window:Drop(preferredBag)
	if self.remoteData or not self.open or (self.spec.canDrop and not self.spec.canDrop()) then
		return
	end
	local itemID = Data.CursorItem()
	if not itemID then
		return
	end
	local bags = {}
	for _, section in ipairs(self.sections) do
		for _, bag in ipairs(section.spec.bags()) do
			bags[#bags + 1] = bag
		end
	end
	if Data.Drop(bags, itemID, preferredBag) then
		return
	end
	local message = Data.Plain(ERR_INV_FULL, "string")
	if message then
		if UIErrorsFrame and type(UIErrorsFrame.AddExternalErrorMessage) == "function" then
			UIErrorsFrame:AddExternalErrorMessage(message)
		else
			K.Print(message)
		end
	end
end

function Window:UpdateDropTargets()
	local held = not self.remoteData and Data.CursorItem() ~= nil
	for _, section in ipairs(self.sections) do
		for _, slot in ipairs(section.order) do
			Slot.SetDrop(slot, held and slot.state.empty and slot.packed ~= nil)
		end
	end
end

ns.On("CURSOR_CHANGED", function()
	for _, win in ipairs(windows) do
		if win.open then
			win:UpdateDropTargets()
		end
	end
end)

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

function Window:QueueCreate(reason)
	if self.createQueued then
		return
	end
	self.createQueued = true
	ns.Log(reason or "item buttons wait for the end of combat: one made in lockdown cannot use items")
	K.Combat.Queue(function()
		self.createQueued = false
		self:Refresh()
	end)
end

function Window:Group(section, key, label, rank)
	local group = section.groups[key]
	if not group then
		group = NewSection(self, { caption = label, bags = section.spec.bags, free = section.spec.free }, key)
		section.groups[key] = group
	elseif group.spec.caption ~= label then
		group.spec.caption = label
		group.cap:SetText(label)
	end
	group.rank, group.key = rank, key
	return group
end

local function BagName(bag)
	local container = C_Container
	local name = container and type(container.GetBagName) == "function" and Data.Plain(container.GetBagName(bag), "string")
	return name or string.format(L["Bag %d"], bag)
end

function Window:Key(record, o, ranks, labels)
	if o.byBag then
		return "bag" .. record.bag, BagName(record.bag), record.bag
	end
	local key = Data.Category(record)
	if o.recent and record.isNew and not (o.carried and o.carried[record.itemID]) then
		return "recent", L["Recent items"], 0
	end
	local label, rank = labels[key] or key, ranks[key] or 0
	if record.empty or not (o.sets or o.slot or o.types or o.nest) then
		return key, label, rank
	end
	local info = Data.Info(record)
	local sub, subRank = nil, 0
	if key == "equipment" then
		local set = o.sets and not (record.bound == false and BIND_LABELS[info.bind]) and Data.SetName(record.itemID)
		if set then
			key, label, rank = "set:" .. set, set, rank - 0.5
		elseif o.slot and SLOT_RANK[info.equipLoc] then
			sub, subRank = Global(info.equipLoc) or info.equipLoc, SLOT_RANK[info.equipLoc]
		elseif o.types then
			sub = info.subType
		end
	elseif key == "tradeGoods" and o.types then
		sub = info.subType
	end
	local expansion = o.nest and info.expansion
	if expansion then
		label = Join(label, Global("EXPANSION_NAME" .. expansion) or tostring(expansion))
		rank = rank + (99 - min(max(expansion, 0), 99)) / 100
	end
	if sub then
		label = Join(label, sub)
		rank = rank + subRank / 10000
	end
	if expansion or sub then
		key = key .. "|" .. tostring(expansion or "") .. "|" .. (sub or "")
	end
	return key, label, rank
end

function Window:Adopt(home, slot)
	local frame = self:BagFrame(home, slot.bag)
	frame:Show()
	local button = slot.button
	if button:GetParent() == frame then
		return
	end
	if Widgets.MayMove(button) then
		button:SetParent(frame)
	else
		self:QueueCreate("sorted slots wait for the end of combat to move between sections")
	end
end

function Window:Sort(section)
	local groups = section.groups
	for _, group in pairs(groups) do
		local order = group.order
		for i = #order, 1, -1 do
			order[i] = nil
		end
		group.total, group.value = 0, 0
	end
	if not self:Grouped(section) then
		for _, slot in ipairs(section.order) do
			slot.packed, slot.shownCount = nil, nil
			self:Adopt(section, slot)
		end
		return
	end
	local o = self.opts
	o.byBag = self.view == "bags"
	o.recent = self.spec.recent and Settings.Get("recentItems") and not o.byBag
	local busy = ns.Busy and ns.Busy() or o.byBag
	o.gained = Settings.Get("recentGained") and not busy
	o.sets, o.slot, o.types = Settings.Get("splitSets"), Settings.Get("gearBySlot"), Settings.Get("splitTypes")
	o.nest = Settings.Get(self.spec.nest or "nestExpansion")
	o.merge = Settings.Get("mergeStacks") and not busy
	local _, leave = self:PinState()
	local pinned = leave and Data.Pins()
	o.carried = nil
	if o.recent and Settings.Get("recentNewOnly") then
		o.carried = {}
		for _, slot in ipairs(section.order) do
			local record = Data.Read(slot.bag, slot.id, slot.record)
			if not record.isNew and record.itemID then
				o.carried[record.itemID] = true
			end
		end
	end
	o.value = Settings.Get("sectionValue")
	local ranks, labels = {}, {}
	for i, category in ipairs(Data.Categories()) do
		ranks[category.key], labels[category.key] = i, category.label
	end
	local packed = Settings.Get("emptySlots") == "packed"
	local families, stacks, merged, recent = {}, {}, {}, {}
	for _, slot in ipairs(section.order) do
		local record = Data.Read(slot.bag, slot.id, slot.record)
		slot.shownCount = nil
		local out = pinned and record.itemID and pinned[record.itemID]
		local key, label, rank = self:Key(record, o, ranks, labels)
		local group = self:Group(section, key, label, rank)
		group.total = group.total + (out and 0 or 1)
		local price = not out and o.value and not record.empty and not record.noValue and Data.Info(record).price
		if price then
			group.value = group.value + price * (record.count or 1)
		end
		local family = key == "empty" and packed and (families[slot.bag] or Data.BagFamily(slot.bag)) or nil
		if family then
			families[slot.bag] = family
		end
		local stack = family and stacks[family]
		local into = not record.empty and record.itemID and (key == "recent" and o.gained or key ~= "recent" and o.merge and Data.BuiltinCategory(record) ~= "equipment") and (key .. "#" .. record.itemID) or nil
		local first = into and merged[into]
		if out or stack or first then
			if out then
				slot.packed = nil
			elseif stack then
				stack.packed = stack.packed + 1
			elseif key ~= "recent" then
				first.shownCount = (first.shownCount or first.record.count or 1) + (record.count or 1)
			end
			if Widgets.MayMove(slot.button) then
				slot.button:Hide()
			end
		else
			if family then
				stacks[family] = slot
				slot.packed = 1
			else
				slot.packed = nil
			end
			if into then
				merged[into] = slot
				if key == "recent" then
					recent[record.itemID] = slot
				end
			end
			group.order[#group.order + 1] = slot
			self:Adopt(group, slot)
		end
	end
	if o.recent then
		self:TrackRecent(section, recent)
	end
	local shownBags = self.shownBags
	for _, group in pairs(groups) do
		for bag, frame in pairs(group.bagFrames) do
			if not shownBags[bag] then
				frame:Hide()
			end
		end
	end
end

function Window:TrackRecent(section, recent)
	local counts, new = {}, {}
	for _, slot in ipairs(section.order) do
		local record, id = slot.record, slot.record.itemID
		if not record.empty and id then
			counts[id] = (counts[id] or 0) + (record.count or 1)
			if record.isNew then
				new[id] = true
			end
		end
	end
	local before, gained = self.counts, self.gained
	for id in pairs(new) do
		gained[id] = before and (gained[id] or 0) + max(0, counts[id] - (before[id] or 0)) or gained[id] or counts[id]
	end
	self.counts = counts
	for id, slot in pairs(recent) do
		slot.shownCount = gained[id]
	end
end

function Window:Panels()
	local list, only, listed = {}, self.only, self.listed or {}
	for key in pairs(listed) do
		listed[key] = nil
	end
	self.listed = listed
	for _, section in ipairs(self.sections) do
		if self:Grouped(section) then
			local shown = {}
			for _, group in pairs(section.groups) do
				if group.total > 0 then
					listed[group.key] = group
				end
				if group.total > 0 and (not only or only == group.key) then
					shown[#shown + 1] = group
				else
					group.view:Hide()
					group.cap:Hide()
				end
			end
			table.sort(shown, ns.List.ByRank)
			for _, group in ipairs(shown) do
				list[#list + 1] = group
			end
			section.view:Hide()
			if section.cap then
				section.cap:Hide()
			end
		else
			for _, group in pairs(section.groups or {}) do
				group.view:Hide()
				group.cap:Hide()
			end
			list[#list + 1] = section
		end
	end
	if only and not listed[only] and not Settings.Get("sidebarEmpty") then
		local plain = self.sections[tonumber(only:match("^section(%d+)$") or 0)]
		if not (plain and #plain.order > 0) then
			self.only = nil
			return self:Panels()
		end
	end
	return list
end

function Window:EnsurePins(section)
	local order, probe = section.order, {}
	for i = #order, 1, -1 do
		order[i] = nil
	end
	local shown = self:PinState()
	local pins = shown and Data.Pins()
	for _, frame in pairs(section.bagFrames) do
		frame:Hide()
	end
	for _, bag in ipairs(pins and next(pins) and section.spec.bags() or {}) do
		local frame = self:BagFrame(section, bag)
		frame:Show()
		local clones = section.clones[bag] or {}
		section.clones[bag] = clones
		for slotID = 1, Data.NumSlots(bag) do
			local record = Data.Read(bag, slotID, probe)
			local slot = clones[slotID]
			if record.itemID and pins[record.itemID] then
				if not slot and InCombatLockdown() then
					self:QueueCreate()
				elseif not slot then
					slot = Slot.New(frame, slotID, { secure = true, bag = bag, pin = self.pin })
					slot.pinned, clones[slotID] = true, slot
				end
				order[#order + 1] = slot
			elseif slot and Widgets.MayMove(slot.button) then
				slot.button:Hide()
			end
		end
	end
	return order
end

local function Bottom(order)
	local items, n = {}, 0
	for _, slot in ipairs(order) do
		if Data.Read(slot.bag, slot.id, slot.record).empty then
			n = n + 1
			order[n] = slot
		else
			items[#items + 1] = slot
		end
	end
	for _, slot in ipairs(items) do
		n = n + 1
		order[n] = slot
	end
end

function Window:Ensure(section)
	if section.clones then
		return self:EnsurePins(section)
	end
	local order = section.order
	for i = #order, 1, -1 do
		order[i] = nil
	end
	local shownBags, groups = self.shownBags, section.groups
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
					slot = Slot.New(frame, slotID, { secure = true, bag = bag, pin = self.pin, drop = function(targetBag) self:Drop(targetBag) end })
					bagSlots[slotID] = slot
				end
			end
			if slot then
				order[#order + 1] = slot
				if not groups then
					slot.shownCount, slot.packed = nil, nil
					if slot.button:GetParent() ~= frame then
						self:Adopt(section, slot)
					end
				end
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
	if Settings.Get("sortBottom") and not self.remoteData and (self.view == "bags" or not self:Grouped(section)) then
		Bottom(order)
	end
	if groups then
		self:Sort(section)
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
	local size, spacing, growth, height = geometry.size, geometry.spacing, geometry.growth, geometry.height
	local list, stripes = geometry.list, geometry.stripes
	local step = height + spacing
	local cols, rows = section.cols, section.rows
	section.grid:ClearAllPoints()
	section.grid:SetPoint("TOPLEFT", section.view, "TOPLEFT", geometry.x, section.scroll * step)
	section.grid:SetSize(max(1, section.width - geometry.x), max(1, rows * step))
	local first, last = section.scroll, section.scroll + section.visibleRows - 1
	for i, slot in ipairs(section.order) do
		local button = slot.button
		if Widgets.MayMove(button) then
			local x, y = Data.Cell(i, cols, rows, size, spacing, growth, height)
			local row = floor(-y / step + 0.5)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", section.grid, "TOPLEFT", x, y)
			button:SetShown(row >= first and row <= last)
		end
		if list then
			Slot.SetStripe(slot, stripes and i % 2 == 0)
		end
	end
end

function Window:Extent(cols, rows)
	local g = self.geometry
	local width, height = Data.Size(cols, rows, g.size, g.spacing, g.height)
	if g.list and rows > 0 then
		width = g.full
	end
	return width, height
end

function Window:Layout(force)
	local panel = self.panel
	if not Widgets.MayMove(panel) then
		return
	end
	if Settings.Get("readableHeaders") then
		local path, _, flags = Tokens.Font("caps")
		Widgets.ApplyFont(panel.titleText, path, 14 * K.Theme.FontScale(), flags)
	else
		Widgets.StyleText(panel.titleText, "caps")
		Widgets.CapsSize(panel.titleText)
	end
	local columns = Settings.Get(self.spec.columns or "columns")
	local rowsLimit = Settings.Get("rows")
	local size, spacing = Snap(self, Settings.Get("slotSize")), Snap(self, Settings.Get("spacing"))
	local remote = self.remoteData
	local list = Settings.Get("listView") and not remote
	local width, height, left, full = size, size, 0, nil
	if list then
		full = Data.Size(columns, 1, size, spacing)
		left = Snap(self, Settings.Get("listLeft"))
		width = max(size, full - left - Snap(self, Settings.Get("listRight")))
		height = Snap(self, Settings.Get("listRowHeight"))
	end
	self.geometry = { size = width, height = height, spacing = spacing, growth = Settings.Get("growth"), x = left, list = list, full = full, stripes = list and Settings.Get("listStripes") }
	self.opts.bind, self.opts.sets = Settings.Get("bindText"), Settings.Get("setNames")
	self.opts.mark = Settings.Get("reagentMark") and not Settings.ReagentApart()
	self.opts.labels = self.opts.bind or self.opts.sets or self.opts.mark
	local _, _, dim = self:PinState()
	self.dimPins = dim and Data.Pins() or nil
	local gold = Settings.Get("goldTooltip")
	if self.goldHover ~= gold then
		self.goldHover = gold
		self.moneyHover:EnableMouse(gold)
	end
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
	local controls = sortWidth + buttonsWidth
	local oneRow = Snap(self, MIN_SEARCH_WIDTH) + gap + controls
	local contentWidth = max(Snap(self, MIN_CONTENT_WIDTH), Snap(self, MIN_SEARCH_WIDTH), controls)
	for _, section in ipairs(self.sections) do
		for _, slot in ipairs(section.order) do
			Slot.Layout(slot, width, force, list and height or nil)
		end
	end
	local panels = self:Panels()
	local step = height + spacing
	local capBlock = Snap(self, Widgets.SECTION_CAP_HEIGHT) + Snap(self, Tokens.Size("gapSmall"))
	if remote then
		for _, section in ipairs(panels) do
			section.view:Hide()
			if section.cap then
				section.cap:Hide()
			end
		end
		panels = {}
		self.remote = self.remote or ns.Remote.New(self)
		contentWidth = max(contentWidth, (Data.Size(self.remote:Columns(remote, columns), 1, size, spacing)))
	elseif self.remote then
		self.remote:Hide()
	end
	if type(self.sortButton.SetEnabled) == "function" then
		self.sortButton:SetEnabled(remote == nil)
	end
	local side = Settings.Get("compactGroups") and not list
	for _, section in ipairs(panels) do
		local count = #section.order
		section.cols, section.rows = Data.Grid(count, list and 1 or columns)
		local limit = section.group == nil and rowsLimit or 0
		section.visibleRows = limit > 0 and min(section.rows, limit) or section.rows
		section.width = self:Extent(section.cols, section.visibleRows)
		contentWidth = max(contentWidth, section.width)
		if section.group and side then
			contentWidth = max(contentWidth, (Data.Size(columns, 1, size, spacing)))
		end
	end
	local hold = self.open and not Settings.Get("shrink") and self.held
	if hold then
		contentWidth = max(contentWidth, hold[1])
	end
	local content = panel.content
	local _, _, _, _, offsetY = content:GetPoint(1)
	local contentTop = -(Plain(offsetY) or 0)
	local top = 0
	if self.spec.above then
		top = self.spec.above(self, content, top, contentWidth)
	end
	local stacked = contentWidth < oneRow
	local searchWidth = stacked and contentWidth or max(1, contentWidth - gap - controls)
	if force or self.search.opts.width ~= searchWidth or self.search.opts.height ~= rowHeight then
		self.search.opts.width, self.search.opts.height = searchWidth, rowHeight
		self.search:Restyle()
	end
	self.search:ClearAllPoints()
	self.search:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
	if stacked then
		top = top + rowHeight + gap
	end
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
	local border = Widgets.Border(panel)
	local footer = Snap(self, FOOTER_HEIGHT)
	local currencies = self.spec.currencies and Settings.Get("currencies") and not remote
	local footerBlock = border + Snap(self, Tokens.Size("gapSmall")) + footer * (currencies and 2 or 1)
	local screen = self:ScreenHeight()
	local tallest = screen and min(screen - Snap(self, SCREEN_MARGIN), screen * Settings.Get("maxHeight") / 100 - gap)
	local budget = tallest and (tallest - contentTop - top - footerBlock - pad) or nil
	local plainHeight = 0
	for _, section in ipairs(panels) do
		if not section.group and #section.order > 0 and (not self.only or self.only == section.key) then
			section.height = select(2, self:Extent(section.cols, section.visibleRows))
			plainHeight = plainHeight + (section.spec.caption and capBlock or 0) + section.height + gap
		end
	end
	local placedStack = false
	local used = 0
	if remote then
		self.geometry.columns, self.geometry.rows = columns, rowsLimit
		top = self.remote:Layout(remote, content, top, contentWidth, self.geometry, capBlock, gap, budget and max(step, budget) or nil)
	end
	for _, section in ipairs(remote and {} or self.placed) do
		if self:Grouped(section) then
			if not placedStack then
				placedStack = true
				local groups = {}
				for _, group in ipairs(panels) do
					if group.group then
						groups[#groups + 1] = group
					end
				end
				local room = budget and max(step, budget - used - plainHeight) or nil
				if #groups > 0 then
					local placed = self:PlaceStack(groups, content, top, contentWidth, room, rowsLimit, capBlock, gap)
					used, top = used + placed - top, placed
				else
					placedStack = false
				end
			end
		elseif #section.order > 0 and (not self.only or self.only == section.key) then
			local reserved = (section.spec.caption and capBlock or 0) + section.height + gap
			plainHeight = plainHeight - reserved
			local room = budget and max(step, budget - used - plainHeight) or nil
			local placed = self:PlaceSection(section, content, top, contentWidth, room, rowsLimit, capBlock, gap)
			used, top = used + placed - top, placed
		else
			section.view:Hide()
			if section.cap then
				section.cap:Hide()
			end
		end
	end
	if not placedStack then
		self.viewport:Hide()
	end
	if hold then
		top = max(top, hold[2] - contentTop - footerBlock - pad)
	end
	local room, tall = ns.List.Update(self, pad, contentTop)
	top = max(top, tall - footerBlock)
	if room > 0 or self.room then
		self.room = room > 0 and room or nil
		content:ClearAllPoints()
		content:SetPoint("TOPLEFT", panel, "TOPLEFT", pad + room, -contentTop)
		content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -pad, pad)
	end
	self.footerLine:ClearAllPoints()
	self.footerLine:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
	self.footerLine:SetSize(contentWidth, border)
	top = top + border + Snap(self, Tokens.Size("gapSmall"))
	self.free:ClearAllPoints()
	self.free:SetPoint("LEFT", content, "TOPLEFT", 0, -(top + footer / 2))
	self.money:ClearAllPoints()
	self.money:SetPoint("RIGHT", content, "TOPLEFT", contentWidth, -(top + footer / 2))
	top = top + footer
	if currencies and not self.currency then
		self.currency = Widgets.Text(panel, "body", "text")
		self.currency:SetJustifyH("LEFT")
		self.currency:SetWordWrap(false)
	end
	if self.currency then
		self.currency:SetShown(currencies)
		self.currency:ClearAllPoints()
		self.currency:SetPoint("LEFT", content, "TOPLEFT", 0, -(top + footer / 2))
		self.currency:SetWidth(contentWidth)
		if currencies then
			top = top + footer
		end
	end
	Widgets.Size(panel, contentWidth + 2 * pad + room, contentTop + top + pad)
	panel.chrome:SetHeader(Settings.Get("readableHeaders") and panel.titleBar:GetHeight() or self.originalHeader)
	if self.open then
		self.held = self.held or {}
		self.held[1], self.held[2] = contentWidth, contentTop + top + pad
	end
	self:Paint(force)
end

function Window:ScreenHeight()
	local root = Scale.Root()
	local height = Plain(root:GetHeight())
	local rootScale, scale = Plain(root:GetEffectiveScale()), Plain(self.panel:GetEffectiveScale())
	if not height or not rootScale or not scale or scale <= 0 then
		return nil
	end
	return height * rootScale / scale
end

function Window:PlaceSection(section, parent, top, width, room, rowsLimit, capBlock, gap, x)
	x = x or 0
	local geometry = self.geometry
	local step = geometry.height + geometry.spacing
	local shown = #section.order > 0
	section.view:SetShown(shown)
	if section.cap then
		section.cap:SetShown(shown)
	end
	if not shown then
		return top
	end
	if section.spec.caption and not section.cap then
		NewCap(section, section.view:GetParent())
	end
	if section.cap then
		local cap = section.cap
		cap.opts.width = width
		cap:Restyle()
		if section.group then
			cap:SetCount(self:CapCount(section))
		end
		cap:ClearAllPoints()
		cap:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -top)
		top = top + capBlock
		if room then
			room = room - capBlock
		end
	end
	if room and not section.group then
		local fit = max(1, floor((room + geometry.spacing) / step))
		section.visibleRows = min(section.visibleRows, fit)
	end
	local scrolls = not section.group and section.visibleRows < section.rows
	section.scroll = min(section.scroll, max(0, section.rows - section.visibleRows))
	section.width, section.height = self:Extent(section.cols, section.visibleRows)
	section.view:SetClipsChildren(scrolls)
	section.view:EnableMouseWheel(scrolls)
	section.view:ClearAllPoints()
	section.view:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -top)
	section.view:SetSize(max(1, section.group and width or section.width), max(1, section.height))
	self:PlaceSlots(section)
	return top + section.height + gap
end

function Window:CapCount(section)
	local value = self.opts.value and section.value > 0 and Window.MoneyText(section.value) or nil
	return value and (section.total .. "  " .. value) or tostring(section.total)
end

function Window:PlaceStack(groups, content, top, width, room, rowsLimit, capBlock, gap)
	local g = self.geometry
	local step = g.height + g.spacing
	local side = Settings.Get("compactGroups") and not g.list
	local half = floor((width - gap) / 2)
	local stackTop, x, bottom = 0, 0, 0
	for _, group in ipairs(groups) do
		local need, cap = width, group.cap
		if side and group.width <= half then
			cap:SetCount(self:CapCount(group))
			if Widgets.CapColumn(cap) + Snap(self, CAP_ROOM) + Widgets.TextWidth(cap.label, 0) + Widgets.TextWidth(cap.count, 0) <= half then
				need = half
			end
		end
		if x == 0 or x + need > width then
			stackTop, x = bottom, 0
		end
		bottom = max(bottom, self:PlaceSection(group, self.stack, stackTop, need, nil, 0, capBlock, gap, x))
		x = side and x + need + gap or width
	end
	local stackHeight = max(1, bottom - gap)
	local height = stackHeight
	if rowsLimit > 0 then
		height = min(height, rowsLimit * step + capBlock)
	end
	if room then
		height = min(height, room)
	end
	height = max(step, height)
	self.stackHeight, self.viewportHeight = stackHeight, height
	self.stackScroll = min(self.stackScroll, max(0, stackHeight - height))
	self.stack:SetSize(max(1, width), stackHeight)
	self.viewport:ClearAllPoints()
	self.viewport:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
	self.viewport:SetSize(max(1, width), height)
	self.viewport:Show()
	self:PlaceStackOffset()
	return top + height + gap
end

function Window:PlaceStackOffset()
	self.stack:ClearAllPoints()
	self.stack:SetPoint("TOPLEFT", self.viewport, "TOPLEFT", 0, self.stackScroll)
end

function Window:ScrollStack(delta)
	local geometry = self.geometry
	if not geometry then
		return
	end
	local step = geometry.height + geometry.spacing
	local maxScroll = max(0, self.stackHeight - self.viewportHeight)
	local scroll = min(maxScroll, max(0, self.stackScroll - (Plain(delta) or 0) * step))
	if scroll ~= self.stackScroll then
		self.stackScroll = scroll
		self:PlaceStackOffset()
	end
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
	local tables = { self.slots, self.pinSection and self.pinSection.clones }
	for _, slots in pairs(tables) do
		for _, bagSlots in pairs(slots) do
			for _, slot in pairs(bagSlots) do
				Slot.Style(slot)
				Slot.Paint(slot)
			end
		end
	end
end

local slotLabels = {}

function Window:UpdateSlot(slot)
	local record = Data.Read(slot.bag, slot.id, slot.record)
	local level = not record.empty and Settings.Get("showItemLevel") and Data.ItemLevel(record) or nil
	local o, extra = self.opts, nil
	if o.labels then
		local info = (o.bind or o.sets) and record.bound == false and Data.Info(record)
		local unbound = info and info.equipLoc and info.equipLoc ~= "" and BIND_LABELS[info.bind]
		extra = slotLabels
		extra.bind = o.bind and unbound or nil
		extra.set = o.sets and not unbound and not record.empty and Data.SetName(record.itemID) or nil
		extra.mark = o.mark and slot.bag == Data.ReagentBag()
	end
	Slot.Update(slot, record, level, self:Match(slot, record), slot.packed, extra, slot.shownCount)
	local container = C_Container
	if not record.empty and container and container.GetContainerItemCooldown then
		Slot.SetCooldown(slot, container.GetContainerItemCooldown(slot.bag, slot.id))
	else
		Slot.SetCooldown(slot)
	end
end

local function Lock(slot, bag, slotID)
	if slot then
		Slot.SetLocked(slot, Data.Read(bag, slotID, slot.record).locked)
	end
end

function Window:UpdateLock(bag, slotID)
	local clones = self.pinSection and self.pinSection.clones[bag]
	Lock(self:Slot(bag, slotID), bag, slotID)
	Lock(clones and clones[slotID], bag, slotID)
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

local function SlotCount(free, total)
	local mode = Settings.Get("slotCount")
	if mode == "usedTotal" then return string.format(L["%d/%d used"], total - free, total) end
	if mode == "free" then return string.format(L["%d free"], free) end
	return string.format(L["%d/%d free"], free, total)
end

function Window:UpdateFooter()
	local remote = self.remoteData
	if remote then
		if remote.free and remote.total then
			Widgets.SetText(self.free, SlotCount(remote.free, remote.total))
		else
			Widgets.SetText(self.free, remote.name)
		end
		self:UpdateMoney()
		return
	end
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
	Widgets.SetText(self.free, SlotCount(free, total))
	self:UpdateMoney()
	self:UpdateCurrencies()
end

function Window:UpdateCurrencies()
	local text = self.currency
	if not text or not (self.spec.currencies and Settings.Get("currencies")) then
		return
	end
	text:SetText(Data.CurrencyText() or L["Track currencies on the backpack to see them here."])
end

function Window:GoldTooltip(owner)
	local tooltip, alts = GameTooltip, ns.Alts
	if not Settings.Get("goldTooltip") or self.remoteData or not tooltip or type(tooltip.SetOwner) ~= "function" or not alts or type(alts.Money) ~= "function" then
		return
	end
	local coins, total = Settings.Get("goldCoins"), 0
	local wr, wg, wb = Tokens.Color("text")
	tooltip:SetOwner(owner, "ANCHOR_TOP")
	tooltip:AddLine(L["Gold"])
	for _, entry in ipairs(alts.Money()) do
		total = total + entry.money
		local r, g, b = Tokens.Color("textEmphasis")
		if entry.class then
			r, g, b = K.Theme.ClassColor(entry.class)
		end
		tooltip:AddDoubleLine(entry.name, Window.MoneyText(entry.money, coins), r, g, b, wr, wg, wb)
	end
	local r, g, b = Tokens.Color("capsGold")
	tooltip:AddDoubleLine(L["Total"], Window.MoneyText(total, coins), r, g, b, wr, wg, wb)
	tooltip:Show()
end

function Window:UpdateMoney()
	local remote = self.remoteData
	if remote then
		self.money:SetText(remote.money and Window.MoneyText(remote.money) or "")
		return
	end
	local money = type(GetMoney) == "function" and Plain(GetMoney()) or nil
	if not money then
		self.money:SetText("")
		return
	end
	if type(GetMoneyString) == "function" then
		self.money:SetText(GetMoneyString(money, true))
	else
		self.money:SetText(Window.MoneyText(money))
	end
end

function Window.MoneyText(copper, coins)
	copper = max(0, floor(copper))
	local gold = floor(copper / (COPPER_PER_SILVER * SILVER_PER_GOLD))
	local silver = floor(copper / COPPER_PER_SILVER) % SILVER_PER_GOLD
	local rest = copper % COPPER_PER_SILVER
	local parts = {}
	if gold > 0 or coins == "gold" then
		parts[#parts + 1] = string.format(L["%dg"], gold)
	end
	if (gold > 0 or silver > 0 or coins == "silver") and coins ~= "gold" then
		parts[#parts + 1] = string.format(L["%ds"], silver)
	end
	if coins ~= "gold" and coins ~= "silver" then
		parts[#parts + 1] = string.format(L["%dc"], rest)
	end
	return table.concat(parts, " ")
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
	self:UpdateDropTargets()
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
			Slot.SetMatch(slot, self:Match(slot, slot.record))
		end
	end
	if self.remote then
		self.remote:SetQuery(query)
	end
end

function Window:Browse(key)
	local data = nil
	if key ~= nil then
		data = ns.Alts and type(ns.Alts.View) == "function" and ns.Alts.View(key) or nil
		if not data then
			ns.Log("no saved items for " .. tostring(key) .. "; the window keeps showing this character's bags")
			return false
		end
	end
	self.remoteData = data
	if self.open then
		self:Refresh()
	end
	return true
end

function Window:Browsing()
	return self.remoteData ~= nil and self.remoteData.key or nil
end

function Window:Open()
	if self.open then
		self:Refresh()
		return
	end
	self.open = true
	if self.spec.views then
		self.view, self.only = Settings.Get("openTo"), nil
	end
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
	self.open, self.held = false, nil
	self.panel:Hide()
end

function Window:Closed()
	self.open, self.held, self.only = false, nil, nil
	if self.search:HasFocus() then
		self.search:ClearFocus()
	end
	self:ClearNew()
	if self.spec.onClosed then
		K.Call(self.spec.onClosed, self)
	end
end

function Window:ClearNew()
	self.gained = {}
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
end

function Window:ScaleChanged()
	local scale = Plain(self.panel:GetScale())
	if scale and scale ~= self.scale then
		self.scale = scale
		Widgets.RestyleAll()
	end
end

function Window:HoldCorner()
	if Settings.Get("nearestCorner") then
		self:SavePosition()
	elseif K.Layout and K.Layout.Set then
		K.Call(K.Layout.Set, self.spec.key, "anchor", self.spec.position.anchor)
	end
end

function Window:SavePosition()
	local layout = K.Layout
	if type(layout) ~= "table" or type(layout.Update) ~= "function" or type(layout.Get) ~= "function" then
		return
	end
	local settings = layout.Get(self.spec.key)
	local panel, root = self.panel, Scale.Root()
	local left, bottom, width, height = Plain(panel:GetLeft()), Plain(panel:GetBottom()), Plain(panel:GetWidth()), Plain(panel:GetHeight())
	local rootLeft, rootBottom, rootWidth, rootHeight = Plain(root:GetLeft()) or 0, Plain(root:GetBottom()) or 0, Plain(root:GetWidth()), Plain(root:GetHeight())
	local scale, rootScale = Plain(panel:GetEffectiveScale()), Plain(root:GetEffectiveScale())
	if not (settings and left and bottom and width and height and rootWidth and rootHeight and scale and rootScale) or rootScale <= 0 then
		return
	end
	local f = scale / rootScale
	local anchor = settings.anchor
	if Settings.Get("nearestCorner") then
		local cx, cy = (left + width / 2) * f - rootLeft, (bottom + height / 2) * f - rootBottom
		anchor = (cy >= rootHeight / 2 and "TOP" or "BOTTOM") .. (cx >= rootWidth / 2 and "RIGHT" or "LEFT")
	end
	local fraction = ANCHOR_FRACTIONS[anchor]
	if not fraction then
		return
	end
	local x = (left + width * fraction[1]) * f - (rootLeft + rootWidth * fraction[1])
	local y = (bottom + height * fraction[2]) * f - (rootBottom + rootHeight * fraction[2])
	local values = { x = floor(x + 0.5), y = floor(y + 0.5) }
	if anchor ~= settings.anchor then
		values.anchor = anchor
	end
	K.Call(layout.Update, self.spec.key, values)
end
