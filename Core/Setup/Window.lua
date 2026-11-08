-- Window.lua: the first-run setup window, four steps built from the widget kit: welcome, layout, modules and summary.
local _, ns = ...

local Setup = ns.Setup
local Layouts = Setup.Layouts
local Widgets, Tokens, Motion, Scale = ns.Widgets, ns.Tokens, ns.Motion, ns.Scale
local L = ns.L
local max, min = math.max, math.min

local WIDTH, HEIGHT = 760, 540
local STEPS = 4
local STRIP_HEIGHT = 32
local FOOTER_HEIGHT = 28
local LOGO_SIZE = 128
local TEXT_WIDTH = 520
local CARD_HEIGHT = 224
local PREVIEW_WIDTH, PREVIEW_HEIGHT = 208, 117
local REFERENCE_WIDTH, REFERENCE_HEIGHT = 1920, 1080
local ROW_HEIGHT = 44
local ROWS_PER_COLUMN = 8
local HEADER_HEIGHT = 32
local ELEMENT_ALPHA, ELEMENT_SELECTED_ALPHA = 0.3, 0.75
local CARD_HOVER_EDGE = 0.6
local WINDOW_KEY = "setup.window"
local WINDOW_POSITION = { anchor = "CENTER", x = 0, y = 40 }
local SKIP_IN_PREVIEW = { ["groupframes.raid"] = true }
local STEP_LABELS = { L["Welcome"], L["Layout"], L["Modules"], L["Summary"] }

local panel
local step, reached, applied, open = 0, 1, false, false

local function gap(name)
	return Widgets.Snap(panel, Tokens.Size(name))
end

local function Refresh()
	local choice = Setup.Choice()
	panel.back:SetShown(step > 1)
	panel.skip:SetShown(step == 1)
	panel.next:SetShown(step < STEPS)
	panel.apply:SetShown(step == STEPS and not applied)
	panel.reload:SetShown(step == STEPS and applied)
	panel.later:SetShown(step == STEPS and applied)
	for name, card in pairs(panel.cards) do
		card.selected = choice.layout == name
		card:Paint()
		if card.selected then
			card.glow:Start()
		else
			card.glow:Stop()
		end
	end
	if step == STEPS then
		local on, off = {}, {}
		for _, entry in ipairs(Setup.PICKER) do
			if Setup.Available(entry.name) then
				local list = choice.modules[entry.name] and on or off
				list[#list + 1] = entry.label
			end
		end
		local text = string.format(L["Layout: %s. %s"], Layouts.Label(choice.layout), Layouts.Note(choice.layout))
			.. "\n\n" .. L["On: "] .. (#on > 0 and table.concat(on, ", ") or L["none"])
			.. "\n\n" .. L["Off: "] .. (#off > 0 and table.concat(off, ", ") or L["none"])
		panel.summary:SetText(text)
		Widgets.SetText(panel.summaryTitle, applied and L["Applied"] or L["Ready to apply"])
		panel.summaryHelp:SetText(applied
			and L["Reload the interface to finish. Modules that replace Blizzard's frames need it."]
			or L["Apply switches these modules on or off, moves every element to the layout, then asks for a reload."])
	end
end

local function Changed()
	applied = false
	Refresh()
end

function Setup.Go(target)
	if not panel then
		return false
	end
	target = max(1, min(STEPS, target))
	reached = max(reached, target)
	for i = 1, STEPS do
		panel.steps:SetTabEnabled(i, i <= reached)
	end
	panel.steps:Select(target, true)
	if target ~= step then
		local old = panel.pages[step]
		if old then
			old:Hide()
		end
		step = target
		Motion.FadeIn(panel.pages[step], Tokens.Duration("fade"))
	end
	Refresh()
	return true
end

function Setup.Step()
	return step
end

local function Paragraph(parent, role, color, width)
	local text = Widgets.Text(parent, role, color)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetWordWrap(true)
	text:SetWidth(Widgets.Snap(parent, width))
	return text
end

local function BuildWelcome(page)
	local pad = gap("gapLarge")
	local logo = page:CreateTexture(nil, "ARTWORK")
	logo:SetTexture((Tokens.Texture("logoLarge")))
	logo:SetSize(Widgets.Snap(page, LOGO_SIZE), Widgets.Snap(page, LOGO_SIZE))
	logo:SetPoint("TOPLEFT", page, "TOPLEFT", pad, -pad)
	local title = Widgets.Text(page, "display", "textEmphasis")
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", gap("gapHuge") * 2, 0)
	title:SetText(L["Welcome to KstyleUI"])
	local body = Paragraph(page, "body", "text", TEXT_WIDTH)
	body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -gap("gapLarge"))
	body:SetText(L["This short setup picks a layout and the parts of the interface KstyleUI replaces. You can change everything later in the settings window, and move or resize any element in Layout Mode."])
	local caption = Widgets.Text(page, "caption", "text")
	caption:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -gap("gapHuge"))
	Widgets.SetText(caption, L["Three steps"])
	local list = Paragraph(page, "body", "textEmphasis", TEXT_WIDTH)
	list:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -gap("gapSmall"))
	list:SetText(L["1. Pick a layout: DPS, Tank or Healer."] .. "\n" .. L["2. Choose the modules you want."] .. "\n" .. L["3. Apply, then reload."])
	panel.welcomeTitle = title
end

local Card = {}

function Card:Paint()
	local hover = self.hoverT or 0
	if self.selected then
		self.chrome:SetEdge("accent", 1)
	else
		self.chrome:SetEdgeRGBA(Widgets.MixTokens("edgeInner", 1, "accent", CARD_HOVER_EDGE, hover))
	end
	local emphasis = self.selected and 1 or hover
	self.title:SetTextColor(Widgets.MixTokens("textEmphasis", 1, "textHover", 1, emphasis))
	local color = self.selected and "accent" or "text"
	local alpha = self.selected and ELEMENT_SELECTED_ALPHA or ELEMENT_ALPHA
	for _, rect in ipairs(self.rects) do
		rect:SetColorTexture(Widgets.Rgba(color, alpha))
	end
end

function Card:Restyle()
	local pad = Widgets.Snap(self, Tokens.Size("gapLarge"))
	self.screen:ClearAllPoints()
	self.screen:SetPoint("TOP", self, "TOP", 0, -pad)
	Widgets.Size(self.screen, PREVIEW_WIDTH, PREVIEW_HEIGHT)
	local s = PREVIEW_WIDTH / REFERENCE_WIDTH
	local line = Widgets.Border(self)
	local positions = Layouts.Get(self.layout)
	for _, rect in ipairs(self.rects) do
		local l, b, r, t = Layouts.Rect(rect.element, positions[rect.element.key], REFERENCE_WIDTH, REFERENCE_HEIGHT)
		rect:ClearAllPoints()
		rect:SetPoint("BOTTOMLEFT", self.screen, "BOTTOMLEFT", Widgets.Snap(self, l * s), Widgets.Snap(self, b * s))
		rect:SetSize(max(line, Widgets.Snap(self, (r - l) * s)), max(line, Widgets.Snap(self, (t - b) * s)))
	end
	self.title:ClearAllPoints()
	self.title:SetPoint("TOPLEFT", self.screen, "BOTTOMLEFT", 0, -pad)
	self.note:ClearAllPoints()
	self.note:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -Widgets.Snap(self, Tokens.Size("gapSmall")))
	self.note:SetWidth(Widgets.Snap(self, PREVIEW_WIDTH))
	self:Paint()
end

local function NewCard(page, name, width)
	local card = CreateFrame("Button", nil, page)
	for k, fn in pairs(Card) do
		card[k] = fn
	end
	card.layout = name
	Widgets.Size(card, width, CARD_HEIGHT)
	card.chrome = Widgets.Chrome(card, { shape = "tile", fill = "buttonFill", shadow = false })
	card.glow = Widgets.Glow(card, { kind = "selection" })
	card.screen = CreateFrame("Frame", nil, card)
	card.screenChrome = Widgets.Chrome(card.screen, { shape = "tile", fill = "surface", shadow = true })
	card.rects = {}
	for _, element in ipairs(Layouts.ELEMENTS) do
		if not SKIP_IN_PREVIEW[element.key] then
			local rect = card.screen:CreateTexture(nil, "ARTWORK")
			rect.element, rect.isElement = element, true
			card.rects[#card.rects + 1] = rect
		end
	end
	card.title = Widgets.Text(card, "heading", "textEmphasis")
	card.title:SetText(Layouts.Label(name))
	card.note = Paragraph(card, "body", "text", PREVIEW_WIDTH)
	card.note:SetText(Layouts.Note(name))
	card.onClick = function()
		Setup.Choice().layout = name
		Changed()
	end
	Widgets.HookPointer(card)
	card:Restyle()
	return Widgets.Track(card)
end

local function BuildLayouts(page, width)
	local names = Layouts.Names()
	local spacing = gap("gapLarge")
	local cardWidth = Widgets.Snap(page, (width - spacing * (#names - 1)) / #names)
	panel.cards = {}
	for i, name in ipairs(names) do
		local card = NewCard(page, name, cardWidth)
		card:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * (cardWidth + spacing), 0)
		panel.cards[name] = card
	end
	local hint = Paragraph(page, "body", "text", width)
	hint:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(Widgets.Snap(page, CARD_HEIGHT) + gap("gapLarge")))
	hint:SetText(L["You can move and resize every element later in Layout Mode: type /kstyle layout."])
end

local function SetAll(value)
	for _, entry in ipairs(Setup.PICKER) do
		local toggle = panel.toggles[entry.name]
		if toggle:IsEnabled() ~= false then
			toggle:SetValue(value)
		end
	end
end

local function BuildModules(page, width)
	local header = Paragraph(page, "body", "text", width / 2)
	header:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -gap("gapSmall"))
	header:SetText(L["Every module starts on. Turn off any you do not want."])
	local allOff = Widgets.Button(page, { text = L["All off"], onClick = function() SetAll(false) end })
	allOff:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	local allOn = Widgets.Button(page, { text = L["All on"], onClick = function() SetAll(true) end })
	allOn:SetPoint("RIGHT", allOff, "LEFT", -gap("gapSmall"), 0)
	local column = Widgets.Snap(page, width / 2)
	local top = Widgets.Snap(page, HEADER_HEIGHT) + gap("gapMedium")
	panel.toggles = {}
	for i, entry in ipairs(Setup.PICKER) do
		local col = i <= ROWS_PER_COLUMN and 0 or 1
		local row = (i - 1) % ROWS_PER_COLUMN
		local name = entry.name
		local toggle = Widgets.Toggle(page, {
			label = entry.label,
			onChange = function(value)
				Setup.Choice().modules[name] = value
				Changed()
			end,
		})
		toggle:SetPoint("TOPLEFT", page, "TOPLEFT", col * column, -(top + row * Widgets.Snap(page, ROW_HEIGHT)))
		local note = Widgets.Text(page, "body", "text")
		note:SetJustifyH("LEFT")
		note:SetWordWrap(false)
		local indent = toggle.trackBox:GetWidth() + gap("gapMedium")
		note:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", indent, -gap("gapTiny"))
		note:SetWidth(column - indent - gap("gapLarge"))
		toggle.note = note
		panel.toggles[name] = toggle
	end
end

local function BuildSummary(page, width)
	local title = Widgets.Text(page, "heading", "textEmphasis")
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -gap("gapSmall"))
	local summary = Paragraph(page, "body", "textEmphasis", width)
	summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -gap("gapLarge"))
	local help = Paragraph(page, "body", "text", width)
	help:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, gap("gapMedium"))
	panel.summaryTitle, panel.summary, panel.summaryHelp = title, summary, help
end

local function SyncChoice()
	local choice = Setup.Choice()
	for _, entry in ipairs(Setup.PICKER) do
		local toggle = panel.toggles[entry.name]
		local available = Setup.Available(entry.name)
		toggle:SetEnabled(available)
		toggle:SetValue(choice.modules[entry.name] == true, true)
		if available then
			toggle.note:SetText(entry.note)
		elseif entry.name == "Icons" then
			toggle.note:SetText(L["Needs the KstyleUI_Icons addon."])
		else
			toggle.note:SetText(L["Not installed, or turned off in the AddOns list."])
		end
		Widgets.TextColor(toggle.note, available and "text" or "textDisabled")
	end
end

local function OnClose()
	open = false
	Setup.Closed(applied)
end

local function Build()
	panel = Widgets.Panel(Scale.Root(), {
		width = WIDTH,
		height = HEIGHT,
		title = L["KstyleUI setup"],
		close = true,
		escape = true,
		strata = "DIALOG",
		hidden = true,
		onClose = OnClose,
		layout = { key = WINDOW_KEY, position = WINDOW_POSITION, options = { scalable = true, window = true, label = L["First-run setup"] } },
	})
	local content = panel.content
	local width = WIDTH - 2 * Tokens.Size("panelPadding")
	local tabs = {}
	for i, label in ipairs(STEP_LABELS) do
		tabs[i] = { value = i, label = label, disabled = i > 1 }
	end
	panel.steps = Widgets.Tabs(content, {
		tabs = tabs,
		value = 1,
		width = width,
		height = STRIP_HEIGHT,
		onSelect = function(value)
			Setup.Go(value)
		end,
	})
	panel.steps:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	panel.pages = {}
	for i = 1, STEPS do
		local page = CreateFrame("Frame", nil, content)
		page:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(Widgets.Snap(panel, STRIP_HEIGHT) + gap("gapLarge")))
		page:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, Widgets.Snap(panel, FOOTER_HEIGHT) + gap("gapLarge"))
		page:Hide()
		panel.pages[i] = page
	end
	BuildWelcome(panel.pages[1])
	BuildLayouts(panel.pages[2], width)
	BuildModules(panel.pages[3], width)
	BuildSummary(panel.pages[4], width)
	panel.back = Widgets.Button(content, { text = L["Back"], onClick = function() Setup.Go(step - 1) end })
	panel.back:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
	panel.skip = Widgets.Button(content, { text = L["Skip setup"], onClick = function() panel:Close() end })
	panel.skip:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
	panel.next = Widgets.Button(content, { text = L["Next"], primary = true, onClick = function() Setup.Go(step + 1) end })
	panel.next:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
	panel.apply = Widgets.Button(content, {
		text = L["Apply"],
		primary = true,
		onClick = function()
			if Setup.Apply(Setup.Choice()) then
				applied = true
				Refresh()
			end
		end,
	})
	panel.apply:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
	panel.reload = Widgets.ReloadButton(content, {})
	panel.reload:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
	panel.later = Widgets.Button(content, { text = L["Later"], onClick = function() panel:Close() end })
	panel.later:SetPoint("RIGHT", panel.reload, "LEFT", -gap("gapSmall"), 0)
	Setup.window = panel
end

function Setup.ShowWindow()
	if not panel then
		Build()
	end
	applied = false
	reached = 1
	for i = 1, STEPS do
		panel.pages[i]:Hide()
	end
	step = 0
	SyncChoice()
	Setup.Go(1)
	if not open or not panel:IsShown() then
		open = true
		panel:Open()
	end
end

function Setup.IsShown()
	return open
end
