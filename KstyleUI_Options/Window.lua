-- Window.lua: the settings window: header and search, the category rail, the option rows, the live preview and the Layout Mode and Reset buttons.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Model, Pages, Rows, Rail, Preview = ns.Model, ns.Pages, ns.Rows, ns.Rail, ns.Preview
local format, floor, max = string.format, math.floor, math.max

local Window = {}
ns.Window = Window

local OWNER = "KstyleUI_Options"
local EVENTS_OWNER = "Options.Window"
local WIDTH, HEIGHT = 1040, 680
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 880, 520, 1800, 1040
local HEADER = 44
local RAIL_WIDTH = 196
local PREVIEW_WIDTH = 280
local SEARCH_WIDTH = 340
local LOGO_SIZE = 28
local RULE_ALPHA = 0.5
local TITLE = "K S T Y L E U I"
local DEFAULT_POSITION = { anchor = "CENTER", x = 0, y = 20 }
local FLASH_ALPHA = 0.35

local win, rail, content, preview, search, clear, layoutButton, resetButton, picker
local state = { page = "General", pages = {} }
local refreshQueued = false
local Relayout

local function CalmLists()
	return K.Appearance.Get("calmLists")
end

local function Jumps()
	return K.Store.Account().optionsSearchJump ~= false
end

local function RestyleText()
	local scale = win:GetScale()
	if not K.Store.Module("OptionsPresentation").readableText then win:SetScale(1) end
	K.Setup.RestyleText(win, preview)
	win:SetScale(scale)
end

local function Snap(units)
	return Widgets.Snap(win, units)
end

local function CurrentPage()
	return Pages.Find(state.pages, state.page) or Pages.Find(state.pages, "General") or state.pages[1]
end

local function Note(text)
	return { { kind = "note", label = text } }
end

local function FirstRow()
	local first
	for _, row in ipairs(content.rows) do
		local index = row.index
		if index and row:IsShown() and (first == nil or index < first) then
			first = index
		end
	end
	return first
end

local function TrackSection()
	local first = FirstRow()
	local current
	for _, section in ipairs(state.sections or {}) do
		if first and section.index <= first then
			current = section.index
		end
	end
	state.section = current
	rail:SetCurrent(current)
	local label = current and state.items[current].label
	local page = preview and preview.page
	if page and page.builtinPreview and page.builtinPreview(label) ~= page.builtinPreview(preview.section) then
		Preview.Show(preview, page, label)
	elseif preview and preview.section ~= label then
		preview.section = label
		if preview.current and preview.current.boxes then preview.current:Refresh() end
	end
end

local function Render(keepOffset, reselect, pageChanged)
	if not win then
		return
	end
	local items
	local page = CurrentPage()
	if state.query then
		local account = K.Store.Account()
		items = Model.Search(account.optionsSearchPage == true and { page } or state.pages, state.query) or {}
		if #items == 0 then
			items = Note(format(L["No settings match \"%s\"."], state.query))
		else
			if account.optionsSearchMemory then
				items = Window.Picks(items, account)
			end
			if Jumps() then
				table.insert(items, 1, { kind = "note", label = L["Press Enter or click a result to go to it."] })
			end
		end
	else
		items = page and Model.Visible(Model.PageItems(page)) or {}
		if #items == 0 then
			items = Note(L["Nothing to set on this page yet."])
		end
	end
	local pinned
	if not state.query then
		for i, item in ipairs(items) do if item.pin then pinned = i; break end end
	end
	local wasPinned = picker.item
	picker.item = pinned and table.remove(items, pinned) or nil
	picker:SetShown(pinned and true or false)
	if pinned or wasPinned then Relayout(true) end
	win.pageCap:SetText(state.query and L["Search results"] or page and page.label or "")
	resetButton:SetEnabled(not state.query and page ~= nil and page.reset ~= nil)
	state.items = items
	state.sections = state.query and {} or Model.Sections(items)
	local calm = CalmLists()
	content.revealLimit = calm and 0.45 or nil
	if not keepOffset then content.flashIndex = nil end
	content:SetData(items, keepOffset, not calm or pageChanged == true)
	local folded = K.Store.Account().optionsRailFolded
	local sections = K.Store.Account().optionsRailSections ~= false and not (folded and folded[state.page]) and state.sections or {}
	if reselect then
		rail:Select(state.query and "" or state.page, sections)
	else
		rail:SetPages(state.pages, sections, true)
	end
	TrackSection()
end

local function JumpTo(entry)
	if state.query or type(entry) ~= "table" or type(entry.index) ~= "number" then
		return
	end
	if entry.index < 1 or entry.index > #state.items then
		return
	end
	content:ScrollToIndex(entry.index, false, "TOP")
end

local function PickId(item)
	return item.page .. "|" .. tostring(item.element or item.module) .. "|" .. tostring(item.key or item.label)
end

function Window.Picks(items, account)
	local picks, first, out = account.optionsSearchPicks or {}, {}, {}
	for _, item in ipairs(items) do
		if item.set and item.kind ~= "header" then
			local id, set = PickId(item), item.set
			item.set = function(...)
				local list = account.optionsSearchPicks or {}
				for i = #list, 1, -1 do if list[i] == id then table.remove(list, i) end end
				table.insert(list, 1, id)
				list[9] = nil
				account.optionsSearchPicks = list
				return set(...)
			end
			for rank, pick in ipairs(picks) do if pick == id then first[rank] = item end end
		end
	end
	for rank = 1, 8 do
		if first[rank] then
			if not out[1] then out[1] = { kind = "header", level = 1, label = L["Recent picks"], page = first[rank].page } end
			out[#out + 1] = first[rank]
		end
	end
	for _, item in ipairs(items) do out[#out + 1] = item end
	return out
end

local function Fold(id)
	local account = K.Store.Account()
	local folded = account.optionsRailFolded or {}
	folded[id] = not folded[id] or nil
	account.optionsRailFolded = next(folded) and folded or nil
	if id == state.page and not state.query then Render(true) end
end

function Window.SetFolded(fold)
	if not win or (state.folded or false) == fold then return end
	if fold then
		local parent = win:GetParent()
		local left, top, pl, pb, ps, ws = win:GetLeft(), win:GetTop(), parent:GetLeft(), parent:GetBottom(), parent:GetEffectiveScale(), win:GetEffectiveScale()
		for _, v in ipairs({ left or false, top or false, pl or false, pb or false, ps or false, ws or false }) do
			if Widgets.IsSecret(v) or type(v) ~= "number" or v ~= v then return end
		end
		if ws <= 0 then return end
		local ratio = ps / ws
		win:ClearAllPoints()
		win:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", left - pl * ratio, top - pb * ratio)
		win:SetHeight(Snap(Widgets.WindowInset(win) * 2 + HEADER))
	end
	state.folded = fold
	if win.SetClipsChildren then win:SetClipsChildren(fold) end
	if not fold then K.Layout.Restore(Pages.WINDOW_KEY) end
end

function Window.Refresh()
	if win and win:IsShown() then
		Render(true)
	end
end

function ns.Changed()
	if refreshQueued then
		return
	end
	refreshQueued = true
	local function run()
		refreshQueued = false
		Window.Refresh()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, run)
	else
		run()
	end
end

local function Select(id)
	local page = Pages.Find(state.pages, id) or Pages.Find(state.pages, "General") or state.pages[1]
	if not page then
		return
	end
	local changed = state.page ~= page.id
	state.page = page.id
	if state.query then
		state.query = nil
		search:SetText("")
		clear:Hide()
	end
	Preview.Show(preview, page)
	Relayout()
	Render(false, true, changed)
end

local function Flash(list, alpha)
	for _, row in ipairs(list.rows) do
		local lit = row:IsShown() and row.index == list.flashIndex and alpha or 0
		if lit > 0 and not row.flash then
			row.flash = row:CreateTexture(nil, "BACKGROUND")
			row.flash:SetAllPoints(row)
			row.flash:SetColorTexture(Tokens.Color("white"))
		end
		if row.flash then
			Widgets.Tint(row.flash, "accent", lit)
		end
	end
end

local function Same(item, target)
	if target.element and item.element ~= target.element or target.entry and item.entry ~= target.entry then
		return false
	elseif target.key then
		return item.module == target.module and item.key == target.key
	end
	return target.labelTarget ~= nil and item.label == target.labelTarget
end

function Window.Jump(target)
	Select(target.page)
	if picker:IsShown() and picker.item.module == target.module and picker.item.key == target.key then return true end
	for i, item in ipairs(state.items) do
		if Same(item, target) then
			content:ScrollToIndex(i, true, "TOP")
			if Jumps() then
				content.flashIndex = i
				local duration, ease = K.Motion.Moment("highlight")
				K.Motion.Tween(content, Flash, FLASH_ALPHA, 0, duration, ease)
			end
			return true
		end
	end
end

function Window.Taking(item)
	return state.query ~= nil and Jumps() and item.page ~= nil and item.kind ~= "note"
end

function Window.GoTo(item)
	if item.scope and item.module then
		K.Options.Write(item.module, item.scope.key, item.scope.value)
	end
	return Window.Jump({ page = item.page, module = item.module, key = item.key, element = item.element, entry = item.entry, labelTarget = item.label })
end

local function SetQuery(text)
	local query = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
	if query == "" then
		query = nil
	end
	clear:SetShown(query ~= nil)
	if query == state.query then
		return
	end
	state.query = query
	Render(false, true)
end

local function ReloadPages()
	state.pages = Pages.List()
	rail:SetPages(state.pages, nil, true)
	rail:Select(state.query and "" or state.page)
end

local function SavePosition()
	local layout = K.Layout
	local set = type(layout) == "table" and layout.Set
	if type(set) ~= "function" then
		return
	end
	local root = K.Scale.Root()
	local cx, cy = win:GetCenter()
	local rx, ry = root:GetCenter()
	local ws, rs = win:GetEffectiveScale(), root:GetEffectiveScale()
	for _, v in ipairs({ cx or false, cy or false, rx or false, ry or false, ws or false, rs or false }) do
		if Widgets.IsSecret(v) or type(v) ~= "number" then
			return
		end
	end
	if rs <= 0 then
		return
	end
	K.Call(set, Pages.WINDOW_KEY, "anchor", "CENTER")
	K.Call(set, Pages.WINDOW_KEY, "x", floor((cx * ws - rx * rs) / rs + 0.5))
	K.Call(set, Pages.WINDOW_KEY, "y", floor((cy * ws - ry * rs) / rs + 0.5))
end

local function EnterLayout()
	if InCombatLockdown() then
		K.Print(L["Layout Mode opens after combat."])
		return
	end
	local layout = K.Layout
	local enter = type(layout) == "table" and (layout.Enter or layout.Toggle)
	if type(enter) ~= "function" then
		K.Print(L["Layout Mode is not available yet."])
		Model.Log("Layout Mode button: Layout.Enter is missing")
		return
	end
	win:Close()
	K.Call(enter)
end

local function AskReset()
	local page = CurrentPage()
	if not (page and page.reset) then
		return
	end
	Widgets.Confirm({
		title = L["Reset"],
		text = format(L["Put every setting on the %s page back to its default?"], page.label),
		acceptLabel = L["Reset"],
		onAccept = function()
			K.Call(page.reset, page)
			ns.Changed()
		end,
	})
end

function Relayout(keepPreview)
	if not win then
		return
	end
	local width, height = win:GetSize()
	if type(width) ~= "number" or type(height) ~= "number" then
		return
	end
	local pad, gap = Widgets.WindowInset(win), Tokens.Size("gapMedium")
	local footer = Tokens.Size("rowHeight") + Tokens.Size("gapSmall")
	local top = pad + HEADER
	local bodyHeight = max(1, height - top - pad)
	local shown = preview:IsShown()
	local side = shown and PREVIEW_WIDTH + gap or 0
	local contentWidth = max(1, width - 2 * pad - RAIL_WIDTH - gap - side)
	local columns = K.Store.Module("OptionsPresentation").columns
	local capTop = top + pad
	local capHeight = columns and Widgets.SECTION_CAP_HEIGHT + pad + gap or 0
	win.categoryCap:SetShown(columns)
	win.pageCap:SetShown(columns)
	win.categoryCap:ClearAllPoints()
	Widgets.Point(win.categoryCap, "TOPLEFT", win, "TOPLEFT", pad, -capTop)
	win.categoryCap:SetWrapWidth(RAIL_WIDTH)
	win.pageCap:ClearAllPoints()
	Widgets.Point(win.pageCap, "TOPLEFT", win, "TOPLEFT", pad + RAIL_WIDTH + gap + Tokens.Size("gapMedium"), -capTop)
	win.pageCap:SetWrapWidth(max(1, contentWidth - 2 * Tokens.Size("gapMedium")))
	win.logo:ClearAllPoints()
	win.logo:SetPoint("TOPLEFT", win, "TOPLEFT", Snap(pad), -Snap(pad))
	Widgets.Size(win.logo, LOGO_SIZE, LOGO_SIZE)
	win.title:ClearAllPoints()
	win.title:SetPoint("LEFT", win.logo, "RIGHT", Snap(gap), 0)
	win.rule:ClearAllPoints()
	win.rule:SetPoint("LEFT", win.title, "RIGHT", Snap(Tokens.Size("gapLarge")), 0)
	win.rule:SetPoint("RIGHT", search, "LEFT", -Snap(Tokens.Size("gapLarge")), 0)
	win.rule:SetHeight(Widgets.Border(win))
	Widgets.PaintCapRule(win.rule, RULE_ALPHA)
	win.closeButton:ClearAllPoints()
	win.closeButton:SetPoint("TOPRIGHT", win, "TOPRIGHT", -Snap(pad), -Snap(pad))
	search:ClearAllPoints()
	search:SetPoint("TOPRIGHT", win, "TOPRIGHT", -Snap(pad + (shown and PREVIEW_WIDTH or win.closeButton:GetWidth()) + gap), -Snap(pad))
	clear:ClearAllPoints()
	clear:SetPoint("RIGHT", search, "RIGHT", -Snap(Tokens.Size("gapSmall")), 0)
	win.header:ClearAllPoints()
	win.header:SetPoint("TOPLEFT", win, "TOPLEFT")
	win.header:SetPoint("TOPRIGHT", win, "TOPRIGHT")
	win.header:SetHeight(Snap(top))
	rail:ClearAllPoints()
	rail:SetPoint("TOPLEFT", win, "TOPLEFT", Snap(pad), -Snap(top + capHeight))
	Widgets.Size(rail, RAIL_WIDTH, max(1, bodyHeight - capHeight))
	win.split:ClearAllPoints()
	local splitGap = Snap(Tokens.Size("gapSmall"))
	win.split:SetPoint("TOPLEFT", rail, "TOPRIGHT", splitGap, 0)
	win.split:SetPoint("BOTTOMLEFT", rail, "BOTTOMRIGHT", splitGap, 0)
	win.split:SetWidth(Widgets.Border(win))
	Widgets.Tint(win.split, "edgeFaint")
	content:ClearAllPoints()
	local pickerHeight = 0
	if picker.item then
		picker:SetWidth(contentWidth)
		pickerHeight = Rows.Measure(picker.item, nil, content, contentWidth)
		picker:SetHeight(pickerHeight)
		picker:ClearAllPoints()
		picker:SetPoint("TOPLEFT", rail, "TOPRIGHT", Snap(gap), 0)
		Rows.Update(picker, picker.item, nil, content)
	end
	content:SetPoint("TOPLEFT", rail, "TOPRIGHT", Snap(gap), -pickerHeight)
	local beside = shown and resetButton:GetWidth() + gap + layoutButton:GetWidth() <= PREVIEW_WIDTH
	Widgets.Size(content, contentWidth, max(1, bodyHeight - capHeight - pickerHeight - (beside and 0 or footer + gap)))
	preview:ClearAllPoints()
	preview:SetPoint("TOPRIGHT", win, "TOPRIGHT", -Snap(pad), -Snap(top))
	if keepPreview ~= true then preview:SetRoom(PREVIEW_WIDTH, max(1, bodyHeight - footer - gap)) end
	resetButton:ClearAllPoints()
	resetButton:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -Snap(pad), Snap(pad))
	layoutButton:ClearAllPoints()
	layoutButton:SetPoint("RIGHT", resetButton, "LEFT", -Snap(gap), 0)
end

local function OnCombat(inCombat)
	if layoutButton then
		layoutButton:SetEnabled(not inCombat)
	end
end

local function Build()
	local root = K.Scale.Root()
	win = Widgets.Panel(root, {
		shape = "window",
		strata = "HIGH",
		escape = true,
		hidden = true,
		calmMotion = CalmLists,
		onClose = function()
			if search:HasFocus() then
				search:ClearFocus()
			end
		end,
	})
	win:SetToplevel(true)
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	Widgets.Size(win, WIDTH, HEIGHT)

	win.header = CreateFrame("Frame", nil, win)
	win.header:EnableMouse(true)
	win.header:RegisterForDrag("LeftButton")
	win.header:SetScript("OnDragStart", function()
		win:StartMoving()
	end)
	win.header:SetScript("OnDragStop", function()
		win:StopMovingOrSizing()
		if not state.folded then SavePosition() end
	end)
	win.header:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" or K.Store.Account().optionsFold ~= true then return end
		local now = GetTime()
		if state.clicked and now - state.clicked < 0.4 then
			state.clicked = nil
			Window.SetFolded(not state.folded)
		else
			state.clicked = now
		end
	end)
	win.logo = win.header:CreateTexture(nil, "ARTWORK")
	win.logo:SetTexture((Tokens.Texture("logo")))
	win.title = Widgets.Text(win.header, "caps", "capsGold")
	Widgets.CapsSize(win.title)
	Widgets.SetText(win.title, TITLE)
	win.rule = win.header:CreateTexture(nil, "ARTWORK")
	win.closeButton = Widgets.CloseButton(win.header, function()
		win:Close()
	end)

	search = Widgets.EditBox(win.header, {
		width = SEARCH_WIDTH,
		placeholder = L["Search settings..."],
		onChange = function(text)
			SetQuery(text)
		end,
		onEnter = function()
			for _, item in ipairs(state.query and state.items or {}) do
				if Window.Taking(item) and item.kind ~= "header" then
					Window.GoTo(item)
					return
				end
			end
		end,
	})
	clear = Widgets.CloseButton(search, function()
		search:SetText("")
		search:ClearFocus()
		SetQuery("")
	end)
	clear:Hide()

	rail = Rail.Create(win, Select, JumpTo, Fold)
	win.split = win:CreateTexture(nil, "ARTWORK")
	win.split:SetColorTexture(Tokens.Color("white"))
	content = Widgets.ScrollList(win, {
		rowHeight = Rows.HEIGHT,
		heightOf = Rows.Measure,
		createRow = Rows.Create,
		updateRow = Rows.Update,
	})
	picker = Rows.Create({ view = win })
	picker:Hide()
	local setOffset = content.SetOffset
	content.SetOffset = function(self, offset)
		setOffset(self, offset)
		TrackSection()
	end
	preview = Preview.Create(win)
	win.categoryCap = Widgets.SectionCap(win, { text = L["Settings"] })
	win.pageCap = Widgets.SectionCap(win)
	layoutButton = Widgets.Button(win, { text = L["Layout Mode"], primary = true, onClick = EnterLayout })
	resetButton = Widgets.Button(win, { text = L["Reset"], onClick = AskReset })

	local restyle = win.Restyle
	win.Restyle = function(self)
		restyle(self)
		Relayout()
	end
	win:HookScript("OnSizeChanged", Relayout)
	Relayout()

	Widgets.Place(win, Pages.WINDOW_KEY, DEFAULT_POSITION, {
		label = L["Settings window"], module = "Options", window = true,
		resizable = true, scalable = true,
		minWidth = MIN_WIDTH, minHeight = MIN_HEIGHT, maxWidth = MAX_WIDTH, maxHeight = MAX_HEIGHT,
	})
	if K.Store.Module("OptionsPresentation").readableText then
		RestyleText()
		Widgets.RestyleUnder({ [win] = true })
	end
	state.scale = win:GetScale()

	K.Callbacks.Register("SettingChanged", OWNER, function(_, module, key)
		if module == "OptionsPresentation" then
			if key == "readableText" then RestyleText(); Widgets.RestyleUnder({ [win] = true }) end
			preview.held = {}
			ReloadPages()
			Preview.Refresh(preview)
			Relayout()
		else
			Preview.Refresh(preview, module)
		end
		ns.Changed()
	end)
	K.Callbacks.Register("ScaleChanged", OWNER, ns.Changed)
	K.Callbacks.Register("PlayerRoleChanged", OWNER, function()
		Preview.Refresh(preview, "Meters")
		ns.Changed()
	end)
	K.Callbacks.Register("ProfileChanged", OWNER, function()
		if win:IsShown() then
			ReloadPages()
		end
		Preview.Refresh(preview)
		ns.Changed()
	end)
	local ok = pcall(K.Callbacks.Register, "LayoutChanged", OWNER, function(_, key)
		if preview.current and preview.current.boxes and win:IsShown() then preview.current:Refresh() end
		if key == Pages.WINDOW_KEY then
			local scale = win:GetScale()
			if scale ~= state.scale then
				state.scale = scale
				if K.Store.Module("OptionsPresentation").readableText then RestyleText() end
				Widgets.RestyleAll()
			end
		end
		ns.Changed()
	end)
	if not ok then
		Model.Log("the LayoutChanged callback does not exist yet; the Elements page refreshes when it reopens")
	end
	K.Events.Register(EVENTS_OWNER, "PLAYER_REGEN_DISABLED", function()
		OnCombat(true)
	end)
	K.Events.Register(EVENTS_OWNER, "PLAYER_REGEN_ENABLED", function()
		OnCombat(false)
	end)
	OnCombat(InCombatLockdown())
	Model.Log("built the settings window")
end

function Window.Show(page)
	if page == false then
		if win and win:IsShown() then win:Close() end
		return
	end
	if type(page) == "table" then
		Window.Show(page.page)
		if not Window.Jump(page) then
			page.page = "Elements"
			Window.Jump(page)
		end
		return
	end
	if not win then
		Build()
	end
	if win:IsShown() then
		if win.closing and CalmLists() then
			win:Open()
			Select(page or state.page)
			return
		end
		if page == nil then
			win:Close()
			return
		end
		Select(page)
		win:Raise()
		return
	end
	if page ~= nil then
		state.page = page
	elseif K.Store.Module("OptionsPresentation").tasks then
		state.page = "Tasks"
	end
	state.query = nil
	search:SetText("")
	clear:Hide()
	Window.SetFolded(false)
	ReloadPages()
	win:Open()
	win:Raise()
	Select(state.page)
end

function Window.Frame()
	return win
end

function Window.State()
	return state
end

function Window.Parts()
	return { rail = rail, content = content, picker = picker, preview = preview, search = search, clear = clear, layoutButton = layoutButton, resetButton = resetButton }
end

K.Options.SetWindow(Window.Show)
