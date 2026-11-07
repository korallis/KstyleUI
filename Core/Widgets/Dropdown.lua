-- Dropdown.lua: the dropdown, a raised box with the chosen label and a chevron, and the one shared menu that lists its options.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale, Motion, L = ns.Tokens, ns.Scale, ns.Motion, ns.L
local min = math.min

local DEFAULT_WIDTH = 200
local DEFAULT_ROWS = 8
local CHEVRON_SIZE = 8
local MARK_LINES = 1
local CHOSEN_WASH = 0.12
local HOVER_WASH = 0.05
local MENU_LEVEL = 10

local EMPTY = {}
local menu
local LayoutMenu

local Dropdown = {}

local function Resolve(self)
	local options = self.options
	if type(options) == "function" then
		local ok, list = ns.Call(options, self)
		if ok and type(list) == "table" then
			return list
		end
		return EMPTY
	end
	return type(options) == "table" and options or EMPTY
end

local function LabelFor(self, value, options)
	if value == nil then
		return nil
	end
	for _, option in ipairs(options or Resolve(self)) do
		if option.value == value then
			return option.label
		end
	end
	local unknown = self.opts.unknownLabel
	if unknown then
		local ok, label = pcall(unknown, value)
		if ok then
			return label
		end
	end
	return nil
end

function Dropdown:UpdateLabel(options)
	local label = LabelFor(self, self.value, options)
	self.chosen = label ~= nil
	Widgets.SetText(self.text, label or self.opts.placeholder or L["Select Option"])
	self:Paint()
end

function Dropdown:GetValue()
	return self.value
end

function Dropdown:GetOptions()
	return Resolve(self)
end

function Dropdown:SetOptions(options)
	self.options = options
	self:UpdateLabel()
	if self:IsOpen() then
		LayoutMenu(menu, self)
	end
end

function Dropdown:SetValue(value, silent)
	local options = Resolve(self)
	local found = false
	for _, option in ipairs(options) do
		found = found or option.value == value
	end
	if not found then
		return false
	end
	if value == self.value then
		return true
	end
	self.value = value
	self:UpdateLabel(options)
	local onChange = self.opts.onChange
	if not silent and onChange then
		ns.Call(onChange, value, self)
	end
	return true
end

function Dropdown:IsOpen()
	return menu ~= nil and menu.owner == self
end

function Dropdown:Paint()
	local hover = self.hoverT or 0
	local enabled = self:IsEnabled() ~= false
	if not enabled then
		self.chrome:SetEdge("edgeInner")
		Widgets.TextColor(self.text, "textDisabled")
		Widgets.Tint(self.chevron, "textDisabled")
	else
		if self:IsOpen() then
			self.chrome:SetEdge("accent")
		else
			self.chrome:SetEdgeRGBA(Widgets.MixTokens("edgeInner", 1, "accent", 1, hover))
		end
		self.text:SetTextColor(Widgets.MixTokens(self.chosen and "textEmphasis" or "text", 1, "textHover", 1, hover))
		self.chevron:SetVertexColor(Widgets.MixTokens("text", 1, "textHover", 1, hover))
	end
	if self:IsOpen() then
		self.chevron:SetTexCoord(0, 1, 1, 0)
	else
		self.chevron:SetTexCoord(0, 1, 0, 1)
	end
end

function Dropdown:Restyle()
	local opts = self.opts
	Widgets.Size(self, opts.width or DEFAULT_WIDTH, opts.height or (Tokens.Size("rowHeight") + Tokens.Size("gapTiny")))
	local pad = Widgets.Snap(self, Tokens.Size("gapMedium"))
	Widgets.Size(self.chevron, CHEVRON_SIZE, CHEVRON_SIZE)
	self.chevron:ClearAllPoints()
	self.chevron:SetPoint("RIGHT", self, "RIGHT", -pad, 0)
	self.text:ClearAllPoints()
	self.text:SetPoint("LEFT", self, "LEFT", pad, 0)
	self.text:SetPoint("RIGHT", self.chevron, "LEFT", -pad, 0)
	self:Paint()
end

local function CloseMenu(m)
	local owner = m.owner
	m.owner = nil
	m.catcher:Hide()
	Motion.FadeOut(m, Tokens.Duration("hover"))
	if owner then
		owner:Paint()
	end
end

function Dropdown:Close()
	if self:IsOpen() then
		CloseMenu(menu)
	end
end

function Dropdown:Toggle()
	if self:IsOpen() then
		self:Close()
	else
		self:Open()
	end
end

local function MenuRowPaint(row)
	local hover = row.hoverT or 0
	row.label:SetTextColor(Widgets.MixTokens(row.isChosen and "textEmphasis" or "text", 1, "textHover", 1, hover))
	if row.isChosen then
		row.wash:SetVertexColor(Widgets.Rgba("accent", CHOSEN_WASH))
	else
		row.wash:SetVertexColor(Widgets.Rgba("white", HOVER_WASH * hover))
	end
end

local function MenuRowClick(row)
	local m = menu
	local owner = m and m.owner
	local option = row.list.items[row.index]
	if owner and option then
		owner:SetValue(option.value)
		CloseMenu(m)
	end
end

local function MenuRow(list)
	local row = CreateFrame("Button", nil, list.view)
	row.wash = row:CreateTexture(nil, "BACKGROUND")
	row.wash:SetColorTexture(Tokens.Color("white"))
	row.wash:SetAllPoints(row)
	row.mark = row:CreateTexture(nil, "ARTWORK")
	row.mark:SetColorTexture(Tokens.Color("white"))
	row.mark:SetPoint("TOPLEFT", row, "TOPLEFT")
	row.mark:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
	row.sample = row:CreateTexture(nil, "ARTWORK")
	row.label = Widgets.Text(row, "body", "text")
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.Paint = MenuRowPaint
	row.onClick = MenuRowClick
	Widgets.HookPointer(row)
	return row
end

local function MenuRowUpdate(row, option)
	local owner = menu.owner
	local pad = Widgets.Snap(row, Tokens.Size("gapMedium"))
	Widgets.StyleText(row.label, "body")
	row.label:ClearAllPoints()
	row.label:SetPoint("LEFT", row, "LEFT", pad, 0)
	row.label:SetPoint("RIGHT", row, "RIGHT", -pad, 0)
	row.sample:Hide()
	Widgets.SetText(row.label, option.label)
	row.isChosen = owner ~= nil and owner.value ~= nil and owner.value == option.value
	row.mark:SetWidth(Widgets.Border(row) * MARK_LINES)
	row.mark:SetShown(row.isChosen)
	Widgets.Tint(row.mark, "accent")
	local render = owner and owner.opts.renderRow
	if render then
		ns.Call(render, row, option, owner)
	end
	MenuRowPaint(row)
end

function LayoutMenu(m, owner)
	local options = Resolve(owner)
	local rowHeight = Tokens.Size("rowHeight")
	local rows = min(#options, owner.opts.maxRows or DEFAULT_ROWS)
	local pad = Tokens.Size("gapSmall")
	local width = owner:GetWidth()
	if type(width) ~= "number" or Widgets.IsSecret(width) then
		width = owner.opts.width or DEFAULT_WIDTH
	end
	width = width * Widgets.ScaleFactor(owner) / Widgets.ScaleFactor(m)
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -Widgets.Snap(m, Tokens.Size("gapTiny")))
	Widgets.Size(m, width, rows * rowHeight + 2 * pad)
	m.list:ClearAllPoints()
	m.list:SetPoint("TOPLEFT", m, "TOPLEFT", 0, -Widgets.Snap(m, pad))
	Widgets.Size(m.list, width, rows * rowHeight)
	m.list:SetData(options)
	for i, option in ipairs(options) do
		if owner.value ~= nil and option.value == owner.value then
			m.list:ScrollToIndex(i, true)
		end
	end
end

local Menu = {}

function Menu:Restyle()
	if self.owner then
		LayoutMenu(self, self.owner)
	end
end

function Widgets.DropdownMenu()
	if menu then
		return menu
	end
	local root = Scale.Root()
	local catcher = CreateFrame("Button", nil, root)
	catcher:SetAllPoints(root)
	catcher:SetFrameStrata("FULLSCREEN_DIALOG")
	catcher:RegisterForClicks("AnyUp")
	catcher:Hide()
	menu = CreateFrame("Frame", nil, root)
	for k, fn in pairs(Menu) do
		menu[k] = fn
	end
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetFrameLevel(catcher:GetFrameLevel() + MENU_LEVEL)
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu.catcher = catcher
	catcher:SetScript("OnClick", function()
		CloseMenu(menu)
	end)
	menu.chrome = Widgets.Chrome(menu, { shape = "tile", fill = "surface", shadow = true })
	menu.list = Widgets.ScrollList(menu, { createRow = MenuRow, updateRow = MenuRowUpdate, stagger = false })
	Widgets.EscapeCloses(menu, CloseMenu)
	menu:Hide()
	return Widgets.Track(menu)
end

function Dropdown:Open()
	if self:IsEnabled() == false then
		return
	end
	local m = Widgets.DropdownMenu()
	if m.owner and m.owner ~= self then
		local previous = m.owner
		m.owner = nil
		previous:Paint()
	end
	m.owner = self
	LayoutMenu(m, self)
	m.catcher:Show()
	Motion.FadeIn(m, Tokens.Duration("hover"))
	Widgets.Sound("U_CHAT_SCROLL_BUTTON")
	self:Paint()
end

function Widgets.Dropdown(parent, opts)
	opts = opts or {}
	local dd = CreateFrame("Button", opts.name, parent or Scale.Root())
	for k, fn in pairs(Dropdown) do
		dd[k] = fn
	end
	dd.opts = opts
	dd.options = opts.options
	dd.chrome = Widgets.Chrome(dd, { shape = "tile", fill = "raised", shadow = false })
	dd.text = Widgets.Text(dd, "body", "text")
	dd.text:SetJustifyH("LEFT")
	dd.text:SetWordWrap(false)
	dd.chevron = dd:CreateTexture(nil, "ARTWORK")
	dd.chevron:SetTexture((Tokens.Texture("glyphChevron")))
	dd.onClick = function(self)
		self:Toggle()
	end
	Widgets.HookPointer(dd)
	dd:HookScript("OnHide", function(self)
		self:Close()
	end)
	if opts.tooltip and Widgets.AttachTooltip then
		Widgets.AttachTooltip(dd, opts.tooltip)
	end
	dd.value = opts.value
	dd:Restyle()
	dd:UpdateLabel()
	return Widgets.Track(dd)
end
