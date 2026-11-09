-- Remote.lua: the bag window's read-only view of a saved character: that character's items from KstyleUI's own account data, as plain tiles under the Lumen section caps, the bags by category and then the bank.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local Data, Slot, L = ns.Data, ns.Slot, ns.L
local max, min = math.max, math.min

local Remote = {}
Remote.__index = Remote
ns.Remote = Remote

local function HideTooltip()
	if type(GameTooltip_Hide) == "function" then
		GameTooltip_Hide()
	end
end

local function ShowTooltip(tile)
	local tooltip = GameTooltip
	local id = tile.entry and tile.entry.id
	if not id or type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
		return
	end
	tooltip:SetOwner(tile.button, "ANCHOR_RIGHT")
	local shown = type(tooltip.SetItemByID) == "function" and tooltip:SetItemByID(id)
	if not shown and type(tooltip.SetText) == "function" then
		tooltip:SetText(tile.entry.name or tostring(id))
	end
	tooltip:Show()
end

function Remote.New(win)
	local frame = CreateFrame("Frame", nil, win.panel.content)
	frame:SetClipsChildren(true)
	frame:EnableMouseWheel(true)
	frame:Hide()
	local stack = CreateFrame("Frame", nil, frame)
	local view = setmetatable({ win = win, frame = frame, stack = stack, groups = {}, tiles = {}, shown = 0, scroll = 0, stackHeight = 0, viewHeight = 0, step = 1 }, Remote)
	frame:SetScript("OnMouseWheel", function(_, delta)
		view:Scroll(delta)
	end)
	return view
end

local function Tile(group, index)
	local tile = group.tiles[index]
	if not tile then
		tile = Slot.New(group.frame, index, {})
		tile.button:SetScript("OnEnter", function()
			ShowTooltip(tile)
		end)
		tile.button:SetScript("OnLeave", HideTooltip)
		group.tiles[index] = tile
	end
	return tile
end

function Remote:Group(index, label)
	local group = self.groups[index]
	if not group then
		local holder = CreateFrame("Frame", nil, self.stack)
		group = { frame = holder, cap = Widgets.SectionCap(self.stack, { text = label }), entries = {}, tiles = {} }
		self.groups[index] = group
	elseif group.label ~= label then
		group.cap:SetText(label)
	end
	group.label = label
	return group
end

local function Record(entry)
	return {
		empty = false, itemID = entry.id, name = entry.name, icon = entry.icon, count = entry.count,
		quality = entry.quality, junk = entry.quality == 0, locked = false, isNew = false,
	}
end

local function Groups(view, data)
	local list = {}
	local byCat = {}
	for _, entry in ipairs(data.bags) do
		local key = entry.cat or "other"
		if not byCat[key] then
			byCat[key] = {}
		end
		byCat[key][#byCat[key] + 1] = entry
	end
	local index = 0
	local function Add(label, entries)
		if #entries == 0 then
			return
		end
		index = index + 1
		local group = view:Group(index, label)
		group.entries = entries
		list[#list + 1] = group
	end
	local listed = {}
	for _, category in ipairs(Data.Categories()) do
		local entries = byCat[category.key]
		if entries then
			listed[category.key] = true
			Add(category.label, entries)
		end
	end
	local rest = {}
	for key, entries in pairs(byCat) do
		if not listed[key] then
			for _, entry in ipairs(entries) do
				rest[#rest + 1] = entry
			end
		end
	end
	Add(L["Other"], rest)
	Add(L["Bank"], data.bank)
	for i = index + 1, #view.groups do
		local group = view.groups[i]
		group.frame:Hide()
		group.cap:Hide()
		for _, tile in ipairs(group.tiles) do
			tile.entry = nil
		end
	end
	return list
end

function Remote:Columns(data, columns)
	local widest = 0
	for _, group in ipairs(Groups(self, data)) do
		widest = max(widest, #group.entries)
	end
	return max(1, (Data.Grid(widest, columns)))
end

function Remote:Place()
	self.scroll = min(self.scroll, max(0, self.stackHeight - self.viewHeight))
	self.stack:ClearAllPoints()
	self.stack:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, self.scroll)
end

function Remote:Scroll(delta)
	delta = Data.Plain(delta, "number") or 0
	local scroll = min(max(0, self.stackHeight - self.viewHeight), max(0, self.scroll - delta * self.step))
	if scroll ~= self.scroll then
		self.scroll = scroll
		self:Place()
	end
end

function Remote:Layout(data, parent, top, width, geometry, capBlock, gap, room)
	local frame, stack = self.frame, self.stack
	local size, spacing, columns = geometry.size, geometry.spacing, geometry.columns
	local step = size + spacing
	self.step = step
	local y = 0
	local used = 0
	local query = self.win.query
	local tiles = self.tiles
	for i = #tiles, 1, -1 do
		tiles[i] = nil
	end
	for _, group in ipairs(Groups(self, data)) do
		local cap = group.cap
		cap.opts.width = width
		cap:Restyle()
		cap:SetCount(tostring(#group.entries))
		cap:ClearAllPoints()
		cap:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, -y)
		cap:Show()
		y = y + capBlock
		local cols, rows = Data.Grid(#group.entries, columns)
		local gridWidth, gridHeight = Data.Size(cols, rows, size, spacing)
		group.frame:ClearAllPoints()
		group.frame:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, -y)
		group.frame:SetSize(max(1, gridWidth), max(1, gridHeight))
		group.frame:Show()
		for i, entry in ipairs(group.entries) do
			used = used + 1
			local tile = Tile(group, i)
			tile.entry = entry
			tiles[used] = tile
			local button = tile.button
			local x, dy = Data.Cell(i, cols, rows, size, spacing, geometry.growth)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", group.frame, "TOPLEFT", x, dy)
			Slot.Style(tile)
			Slot.Layout(tile, size, true)
			local record = Record(entry)
			Slot.Update(tile, record, nil, Data.Matches(record, query))
			button:Show()
		end
		for i = #group.entries + 1, #group.tiles do
			group.tiles[i].entry = nil
			group.tiles[i].button:Hide()
		end
		y = y + gridHeight + gap
	end
	self.shown = used
	local stackHeight = max(step, y - gap)
	local height = stackHeight
	local rowsLimit = geometry.rows or 0
	if rowsLimit > 0 then
		height = min(height, rowsLimit * step + capBlock)
	end
	if room then
		height = min(height, room)
	end
	height = max(step, height)
	self.stackHeight, self.viewHeight = stackHeight, height
	stack:SetSize(max(1, width), stackHeight)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -top)
	frame:SetSize(max(1, width), height)
	frame:Show()
	self:Place()
	return top + height + gap
end

function Remote:SetQuery(query)
	for i = 1, self.shown do
		local tile = self.tiles[i]
		if tile.entry then
			Slot.SetMatch(tile, Data.Matches(Record(tile.entry), query))
		end
	end
end

function Remote:Hide()
	self.frame:Hide()
end
