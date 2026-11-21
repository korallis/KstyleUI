-- List.lua: the category list beside a bag or bank window: its views, the bank's tabs and its sections, each shown alone with a click.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Data, Settings, L = ns.Data, ns.Settings, ns.L

local List = {}
ns.List = List

local WIDTH, FOLDED, GAP, COUNT_ROOM = 150, 34, 6, 30
local VIEWS = { { "all", L["All items"] }, { "grid", L["One grid"] }, { "bags", L["Bag by bag"] } }

function List.ByRank(a, b)
	if a.rank ~= b.rank then
		return a.rank < b.rank
	end
	return tostring(a.spec.caption) < tostring(b.spec.caption)
end

local function Items(win)
	local items, only = {}, win.only
	local function add(kind, value, label, count, selected)
		items[#items + 1] = { kind = kind, value = value, label = label, count = count, selected = selected }
	end
	if win.spec.views then
		for _, view in ipairs(VIEWS) do
			add("view", view[1], view[2], nil, not only and (win.view or "all") == view[1])
		end
	end
	if win.spec.listTabs and Settings.Get("sidebarTabs") then
		add("tab", nil, L["All tabs"], nil, not only and not win.onlyBag)
		for i, bag in ipairs(win.spec.listTabs()) do
			add("tab", bag, string.format(L["Tab %d"], i), nil, not only and win.onlyBag == bag)
		end
	end
	local groups, categories = {}, false
	for _, group in pairs(win.listed or {}) do
		groups[#groups + 1] = group
	end
	table.sort(groups, List.ByRank)
	for _, section in ipairs(win.placed) do
		if win:Grouped(section) then
			categories = win.view ~= "bags"
			for _, group in ipairs(groups) do
				add("only", group.key, group.spec.caption, group.total, only == group.key)
			end
		elseif section.spec.caption and #section.order > 0 then
			add("only", section.key, section.spec.caption, #section.order, only == section.key)
		end
	end
	if categories and Settings.Get("sidebarEmpty") then
		for _, category in ipairs(Data.Categories()) do
			if not (win.listed or {})[category.key] then
				add("only", category.key, category.label, 0, only == category.key)
			end
		end
	end
	if Settings.Get("sidebarAdd") then
		add("add", nil, L["Add category"])
	end
	return items
end

function List.Pick(win, item)
	if item.kind == "add" then
		K.Options.Open("Bags")
		return
	elseif item.kind == "view" then
		win.view, win.only = item.value, nil
	elseif item.kind == "tab" then
		win.onlyBag, win.only = item.value, nil
	else
		win.only = win.only ~= item.value and item.value or nil
	end
	win:Refresh()
end

local function Fold(win)
	win.folded = not win.folded
	win:Layout(true)
end

local function Chevron(parent, onClick)
	local button = Widgets.Button(parent, { width = 24, onClick = onClick })
	button.glyph = button:CreateTexture(nil, "ARTWORK")
	button.glyph:SetTexture((Tokens.Texture("glyphChevron")))
	Widgets.Size(button.glyph, 10, 10)
	Widgets.Point(button.glyph, "CENTER", button, "CENTER")
	Widgets.Tint(button.glyph, "textEmphasis")
	return button
end

local function Entry(win, i)
	local list = win.list
	local entry = list.entries[i]
	if not entry then
		entry = CreateFrame("Button", nil, list.frame)
		entry.mark = entry:CreateTexture(nil, "ARTWORK")
		entry.mark:SetTexture((Tokens.Texture("diamond")))
		entry.label = Widgets.Text(entry, "body", "text")
		entry.label:SetJustifyH("LEFT")
		entry.label:SetWordWrap(false)
		entry.count = Widgets.Text(entry, "caption", "muted")
		entry:SetScript("OnClick", function(self)
			List.Pick(win, self.item)
		end)
		Widgets.AttachTooltip(entry, function(tip, self)
			tip:AddLine(self.item and self.item.label or "")
		end)
		list.entries[i] = entry
	end
	return entry
end

function List.Update(win, left, top)
	local list, panel = win.list, win.panel
	local on = Settings.Get("sidebar") and win.remoteData == nil
	if not on and not list then
		return 0, 0
	end
	if not list then
		list = { frame = CreateFrame("Frame", nil, panel), entries = {} }
		list.fold = Chevron(list.frame, function() Fold(win) end)
		list.expand = Chevron(panel, function() Fold(win) end)
		win.list = list
	end
	local folded = win.folded == true
	local hide = folded and Settings.Get("sidebarHide")
	list.frame:SetShown(on and not hide)
	list.expand:SetShown(on and hide)
	if hide then
		list.expand:ClearAllPoints()
		Widgets.Point(list.expand, "RIGHT", panel.closeButton or panel, "LEFT", -GAP, 0)
		list.expand.glyph:SetRotation(math.pi / 2)
	end
	if not on or hide then
		return 0, 0
	end
	list.fold.glyph:SetRotation(folded and math.pi / 2 or -math.pi / 2)
	local width = folded and FOLDED or WIDTH
	local row = Tokens.Size("rowHeight")
	Widgets.Point(list.fold, "TOPLEFT", list.frame, "TOPLEFT")
	local items, y = Items(win), row + GAP
	for i, item in ipairs(items) do
		local entry = Entry(win, i)
		entry.item = item
		entry:Show()
		entry:ClearAllPoints()
		Widgets.Point(entry, "TOPLEFT", list.frame, "TOPLEFT", 0, -y)
		Widgets.Size(entry, width, row)
		Widgets.Size(entry.mark, 8, 8)
		Widgets.Point(entry.mark, "LEFT", entry, "LEFT", folded and (width - 8) / 2 or 0, 0)
		if item.selected then
			entry.mark:SetVertexColor(Settings.Accent())
		else
			Widgets.Tint(entry.mark, "muted")
		end
		entry.label:SetShown(not folded)
		entry.count:SetShown(not folded)
		Widgets.SetText(entry.label, item.label)
		Widgets.TextColor(entry.label, item.selected and "textEmphasis" or "text")
		entry.count:SetText(item.count and tostring(item.count) or "")
		Widgets.Point(entry.count, "RIGHT", entry, "RIGHT")
		Widgets.Point(entry.label, "LEFT", entry.mark, "RIGHT", GAP, 0)
		Widgets.Point(entry.label, "RIGHT", entry, "RIGHT", item.count and -COUNT_ROOM or 0, 0)
		y = y + row
	end
	for i = #items + 1, #list.entries do
		list.entries[i]:Hide()
	end
	local frame = list.frame
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", panel, "TOPLEFT", left, -top)
	Widgets.Size(frame, width, y)
	return Widgets.Snap(panel, width + Tokens.Size("gapMedium")), Widgets.Snap(panel, y)
end
