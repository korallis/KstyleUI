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
local TITLE = "K S T Y L E U I"
local DEFAULT_POSITION = { anchor = "CENTER", x = 0, y = 20 }

local win, rail, content, preview, search, clear, layoutButton, resetButton
local state = { page = "General", pages = {} }
local refreshQueued = false

local function Snap(units)
	return Widgets.Snap(win, units)
end

local function CurrentPage()
	return Pages.Find(state.pages, state.page) or state.pages[1]
end

local function Note(text)
	return { { kind = "note", label = text } }
end

local function Render(keepOffset)
	if not win then
		return
	end
	local items
	if state.query then
		items = Model.Search(state.pages, state.query) or {}
		if #items == 0 then
			items = Note(format(L["No settings match \"%s\"."], state.query))
		end
	else
		local page = CurrentPage()
		items = page and Model.Visible(Model.PageItems(page)) or {}
		if #items == 0 then
			items = Note(L["Nothing to set on this page yet."])
		end
	end
	state.items = items
	content:SetData(items, keepOffset)
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
	local page = Pages.Find(state.pages, id) or state.pages[1]
	if not page then
		return
	end
	state.page = page.id
	if state.query then
		state.query = nil
		search:SetText("")
		clear:Hide()
	end
	rail:Select(page.id)
	resetButton:SetEnabled(page.reset ~= nil)
	Preview.Show(preview, page)
	Render(false)
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
	rail:Select(query and "" or state.page)
	Render(false)
end

local function ReloadPages()
	state.pages = Pages.List()
	rail:SetData(state.pages, true)
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

local function Relayout()
	if not win then
		return
	end
	local width, height = win:GetSize()
	if type(width) ~= "number" or type(height) ~= "number" then
		return
	end
	local pad, gap = Tokens.Size("panelPadding"), Tokens.Size("gapMedium")
	local footer = Tokens.Size("rowHeight") + Tokens.Size("gapSmall")
	local top = pad + HEADER
	local bodyHeight = max(1, height - top - pad)
	local contentWidth = max(1, width - 2 * pad - RAIL_WIDTH - PREVIEW_WIDTH - 2 * gap)
	win.logo:ClearAllPoints()
	win.logo:SetPoint("TOPLEFT", win, "TOPLEFT", Snap(pad), -Snap(pad))
	Widgets.Size(win.logo, LOGO_SIZE, LOGO_SIZE)
	win.title:ClearAllPoints()
	win.title:SetPoint("LEFT", win.logo, "RIGHT", Snap(gap), 0)
	win.closeButton:ClearAllPoints()
	win.closeButton:SetPoint("TOPRIGHT", win, "TOPRIGHT", -Snap(pad), -Snap(pad))
	search:ClearAllPoints()
	search:SetPoint("TOPRIGHT", win, "TOPRIGHT", -Snap(pad + PREVIEW_WIDTH + gap), -Snap(pad))
	clear:ClearAllPoints()
	clear:SetPoint("RIGHT", search, "RIGHT", -Snap(Tokens.Size("gapSmall")), 0)
	win.header:ClearAllPoints()
	win.header:SetPoint("TOPLEFT", win, "TOPLEFT")
	win.header:SetPoint("TOPRIGHT", win, "TOPRIGHT")
	win.header:SetHeight(Snap(top))
	rail:ClearAllPoints()
	rail:SetPoint("TOPLEFT", win, "TOPLEFT", Snap(pad), -Snap(top))
	Widgets.Size(rail, RAIL_WIDTH, bodyHeight)
	win.split:ClearAllPoints()
	win.split:SetPoint("TOPLEFT", rail, "TOPRIGHT", Snap(gap / 2), 0)
	win.split:SetPoint("BOTTOMLEFT", rail, "BOTTOMRIGHT", Snap(gap / 2), 0)
	win.split:SetWidth(Widgets.Border(win))
	Widgets.Tint(win.split, "edgeInner")
	content:ClearAllPoints()
	content:SetPoint("TOPLEFT", rail, "TOPRIGHT", Snap(gap), 0)
	Widgets.Size(content, contentWidth, bodyHeight)
	preview:ClearAllPoints()
	preview:SetPoint("TOPRIGHT", win, "TOPRIGHT", -Snap(pad), -Snap(top))
	Widgets.Size(preview, PREVIEW_WIDTH, max(1, bodyHeight - footer - gap))
	preview:Layout()
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
		strata = "HIGH",
		escape = true,
		hidden = true,
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
		SavePosition()
	end)
	win.logo = win.header:CreateTexture(nil, "ARTWORK")
	win.logo:SetTexture((Tokens.Texture("logo")))
	win.title = Widgets.Text(win.header, "heading", "textEmphasis")
	Widgets.SetText(win.title, TITLE)
	win.closeButton = Widgets.CloseButton(win.header, function()
		win:Close()
	end)

	search = Widgets.EditBox(win.header, {
		width = SEARCH_WIDTH,
		placeholder = L["Search settings..."],
		onChange = function(text)
			SetQuery(text)
		end,
	})
	clear = Widgets.CloseButton(search, function()
		search:SetText("")
		search:ClearFocus()
		SetQuery("")
	end)
	clear:Hide()

	rail = Rail.Create(win, Select)
	win.split = win:CreateTexture(nil, "ARTWORK")
	win.split:SetColorTexture(Tokens.Color("white"))
	content = Widgets.ScrollList(win, {
		rowHeight = Rows.HEIGHT,
		createRow = Rows.Create,
		updateRow = Rows.Update,
	})
	preview = Preview.Create(win)
	layoutButton = Widgets.Button(win, { text = L["Layout Mode"], primary = true, onClick = EnterLayout })
	resetButton = Widgets.Button(win, { text = L["Reset"], onClick = AskReset })

	local restyle = win.Restyle
	win.Restyle = function(self)
		restyle(self)
		Relayout()
	end
	win:HookScript("OnSizeChanged", Relayout)
	Relayout()

	state.scale = win:GetScale()
	Widgets.Place(win, Pages.WINDOW_KEY, DEFAULT_POSITION, {
		label = L["Settings window"], module = "Options",
		resizable = true, scalable = true,
		minWidth = MIN_WIDTH, minHeight = MIN_HEIGHT, maxWidth = MAX_WIDTH, maxHeight = MAX_HEIGHT,
	})

	K.Callbacks.Register("SettingChanged", OWNER, function(_, module)
		Preview.Refresh(preview, module)
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
		if key == Pages.WINDOW_KEY then
			local scale = win:GetScale()
			if scale ~= state.scale then
				state.scale = scale
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
	if not win then
		Build()
	end
	if win:IsShown() then
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
	end
	state.query = nil
	search:SetText("")
	clear:Hide()
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
	return { rail = rail, content = content, preview = preview, search = search, clear = clear, layoutButton = layoutButton, resetButton = resetButton }
end

K.Options.SetWindow(Window.Show)
