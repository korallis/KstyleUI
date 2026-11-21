-- List.lua: the category list beside a bag or bank window: its views, the bank's tabs and its sections, each shown alone with a click.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Data, Settings, L = ns.Data, ns.Settings, ns.L
local max, min = math.max, math.min

local List = {}
ns.List = List

local WIDTH, FOLDED, GAP, COUNT_ROOM, ROW = 150, 34, 6, 30, 26
List.WIDTH, List.ROW = WIDTH, ROW

function List.ByRank(a, b)
	if a.rank ~= b.rank then
		return a.rank < b.rank
	end
	return tostring(a.spec.caption) < tostring(b.spec.caption)
end

local function Items(win)
	local items, only, used = {}, win.only, {}
	local function add(kind, value, label, count, selected)
		items[#items + 1] = { kind = kind, value = value, label = label, count = count, selected = selected }
	end
	if win.spec.views then
		for _, view in ipairs(Settings.VIEWS) do
			add("view", view.value, view.label, nil, not only and (win.view or "all") == view.value)
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
		used[group.category or group.key] = true
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
			if not used[category.key] then
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
		K.Options.Open({ page = "Bags", module = Settings.MODULE, key = Settings.CUSTOM[1] .. ".name" })
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

local function Paint(row)
	local item, hover = row.item, row.hoverT or 0
	if not item then
		return
	end
	row.hover:SetVertexColor(Widgets.Rgba("white", Tokens.Share("rowHover") * hover))
	if item.selected then
		row.mark:SetVertexColor(Settings.Accent())
		Widgets.TextColor(row.label, "textEmphasis")
	else
		Widgets.Tint(row.mark, "muted")
		row.label:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, hover))
	end
end

local function NewRow(scroll)
	local row = CreateFrame("Button", nil, scroll.view)
	row.hover = row:CreateTexture(nil, "BACKGROUND")
	row.hover:SetColorTexture(Tokens.Color("white"))
	row.hover:SetAllPoints(row)
	row.mark = row:CreateTexture(nil, "ARTWORK")
	row.label = Widgets.Text(row, "body", "text")
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.count = Widgets.Text(row, "caption", "muted")
	row.Paint = Paint
	row.onClick = function(self)
		if scroll.win then
			List.Pick(scroll.win, self.item)
		end
	end
	Widgets.HookPointer(row)
	Widgets.AttachTooltip(row, function(tip, self)
		tip:AddLine(self.item and self.item.label or "")
	end)
	return row
end

local function UpdateRow(row, item, _, scroll)
	local folded, gap = scroll.folded, Tokens.Size("gapSmall")
	row.item = item
	row.label:SetShown(not folded)
	row.count:SetShown(not folded)
	Widgets.SetText(row.label, item.label)
	row.count:SetText(item.count and tostring(item.count) or "")
	row.label:ClearAllPoints()
	Widgets.Point(row.label, "LEFT", row, "LEFT", Tokens.Size("gapLarge"), 0)
	Widgets.Point(row.label, "RIGHT", row, "RIGHT", item.count and -COUNT_ROOM or 0, 0)
	Widgets.Point(row.count, "RIGHT", row, "RIGHT", -gap, 0)
	row.mark:ClearAllPoints()
	if folded then
		row.mark:SetTexture((Tokens.Texture("diamond")))
		Widgets.Size(row.mark, 8, 8)
		Widgets.Point(row.mark, "CENTER", row, "CENTER")
	else
		row.mark:SetColorTexture(Tokens.Color("white"))
		Widgets.Size(row.mark, 2, 10)
		Widgets.Point(row.mark, "RIGHT", row.label, "LEFT", -gap, 0)
	end
	row.mark:SetShown(folded or item.selected == true)
	Paint(row)
end

function List.New(parent, win)
	local scroll = Widgets.ScrollList(parent, { rowHeight = ROW, createRow = NewRow, updateRow = UpdateRow, stagger = false })
	scroll.win = win
	return scroll
end

function List.Show(scroll, items, folded)
	local old = scroll:GetData()
	local same = scroll.folded == folded and #old == #items
	for i = 1, same and #items or 0 do
		local a, b = old[i], items[i]
		same = same and a.kind == b.kind and a.value == b.value and a.label == b.label and a.count == b.count and a.selected == b.selected
	end
	if not same then
		scroll.folded = folded
		scroll:SetData(items, true)
	end
end

function List.Update(win, left, top, tallest)
	local list, panel = win.list, win.panel
	local on = Settings.Get("sidebar") and win.remoteData == nil
	if not on and not list then
		return 0, 0
	end
	if not list then
		list = { frame = CreateFrame("Frame", nil, panel) }
		list.fold = Chevron(list.frame, function() Fold(win) end)
		list.expand = Chevron(panel, function() Fold(win) end)
		list.scroll = List.New(list.frame, win)
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
	local width, head, items = folded and FOLDED or WIDTH, Tokens.Size("rowHeight") + GAP, Items(win)
	local height = #items * ROW
	if tallest then
		height = max(ROW, min(height, tallest - head))
	end
	local frame = list.frame
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", panel, "TOPLEFT", left, -top)
	Widgets.Size(frame, width, head + height)
	Widgets.Point(list.fold, "TOPLEFT", frame, "TOPLEFT")
	Widgets.Point(list.scroll, "TOPLEFT", frame, "TOPLEFT", 0, -head)
	list.scroll:SetSize(width, height)
	List.Show(list.scroll, items, folded)
	return Widgets.Snap(panel, width + Tokens.Size("gapMedium")), Widgets.Snap(panel, head + height)
end
