-- Window.lua: the first-run setup window, four steps built from the widget kit: welcome, layout, modules and summary; the layout step's preview draws the picked or hovered layout's real footprints, named where a name fits and its role elements brighter than the shared ones, and the summary says what Edit Mode did, with Try again.
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
local CARD_HEIGHT = 120
local REFERENCE_WIDTH, REFERENCE_HEIGHT = 1920, 1080
local LABEL_ROOM = 4
local LABEL_FLOOR = 8
local PREVIEW_FALLBACK, LEGEND_WIDTH = 260, 240
local SUMMARY_PREVIEW = 352
local ROW_HEIGHT = 44
local ROWS_PER_COLUMN = 8
local HEADER_HEIGHT = 32
local ELEMENT_ALPHA, ROLE_ALPHA = 0.22, 0.5
local SLOT_FILL, SLOT_EDGE = 0.08, 0.7
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

local function GuidePlaced()
	if Setup.Choice().modules.Skins ~= true then
		return false
	end
	local ok, skins = pcall(ns.Store.Module, "Skins")
	local rxp = ok and type(skins) == "table" and skins.restedXP or nil
	return type(rxp) ~= "table" or (rxp.enabled ~= false and rxp.rail ~= false)
end

local function GuideStep()
	return applied and Setup.GuideLoaded() and not GuidePlaced()
end

local function EditModeText()
	local EditMode = Setup.EditMode
	local last = EditMode and EditMode.Last()
	local lines = {}
	if last and last.state ~= "none" and (applied or last.state == "failed") then
		if last.state == "waiting" then
			lines[1] = string.format(L["Edit Mode: %s is written when combat ends."], last.layout)
		elseif last.state == "failed" then
			lines[1] = string.format(L["Edit Mode did not take %s. %s"], last.layout, last.why)
		else
			lines[1] = string.format(#last.notes > 0 and L["Edit Mode: %s is your active layout, with the quest tracker in the story rail."] or L["Edit Mode: %s is your active layout, with the quest tracker in the story rail and Blizzard's tracked buffs around your hands."], last.layout)
			for _, note in ipairs(last.notes) do
				lines[#lines + 1] = EditMode.Note(note)
			end
			if #last.notes > 0 then
				lines[#lines + 1] = EditMode.Step()
			end
		end
	end
	if GuideStep() then
		lines[#lines + 1] = L["RestedXP: drag its guide onto the story rail yourself; Window skins place it only with their RestedXP story rail on."]
	end
	return #lines > 0 and table.concat(lines, "\n") or nil
end

local function StepsLeft()
	local last = Setup.EditMode and Setup.EditMode.Last()
	local steps = GuideStep() and 1 or 0
	if last and last.state == "failed" then
		steps = steps + 1
	elseif last and last.state == "written" then
		steps = steps + #last.notes
	end
	return steps
end

local function SummaryTitle()
	if not applied then
		return L["Ready to apply"]
	end
	local steps = StepsLeft()
	if steps == 1 then
		return L["Applied, with one step left"]
	elseif steps > 1 then
		return string.format(L["Applied, with %d steps left"], steps)
	end
	return L["Applied"]
end

local function Manager()
	local settings = CooldownViewerSettings
	return type(settings) == "table" and type(settings.ShowUIPanel) == "function" and settings or nil
end

local function RefreshEditMode()
	local text = EditModeText()
	local last = Setup.EditMode and Setup.EditMode.Last()
	panel.editMode:SetShown(text ~= nil)
	panel.editMode:SetText(text or "")
	panel.retry:SetShown(text ~= nil and last ~= nil and (last.state == "failed" or (last.state == "written" and #last.notes > 0)))
	panel.manager:SetShown(text ~= nil and last ~= nil and last.state == "written" and #last.notes > 0 and Manager() ~= nil)
	if step == STEPS then
		Widgets.SetText(panel.summaryTitle, SummaryTitle())
	end
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
	if not panel.preview.hovered then
		panel.preview:Draw(choice.layout)
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
		if #off > 0 then
			text = text .. "\n" .. L["Off: "] .. table.concat(off, ", ")
		end
		panel.summary:SetText(text)
		panel.summaryPreview:Draw(choice.layout)
		panel.summaryHelp:SetText(applied
			and L["Reload the interface to finish. Modules that replace Blizzard's frames need it."]
			or L["Apply switches these modules on or off, moves every element to the layout, then asks for a reload."])
	end
	RefreshEditMode()
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
	local note = Paragraph(page, "body", "text", TEXT_WIDTH)
	note:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -gap("gapHuge"))
	note:SetText(L["Close this window and KstyleUI applies the DPS layout with every module on. Keep my UI leaves the game's own interface as it is."])
	panel.welcomeTitle, panel.welcomeNote = title, note
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
end

function Card:Restyle()
	local pad = Widgets.Snap(self, Tokens.Size("gapLarge"))
	self.title:ClearAllPoints()
	self.title:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
	self.note:ClearAllPoints()
	self.note:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -Widgets.Snap(self, Tokens.Size("gapSmall")))
	self.note:SetWidth(max(1, self:GetWidth() - pad * 2))
	self:Paint()
end

local roles
local function Roles()
	if roles then
		return roles
	end
	roles = {}
	local names = Layouts.Names()
	local first = Layouts.Get(names[1])
	for _, element in ipairs(Layouts.ELEMENTS) do
		local key = element.key
		local a = first[key]
		for i = 2, #names do
			local b = Layouts.Get(names[i])[key]
			local w1, h1 = Layouts.Footprint(names[1], key)
			local w2, h2 = Layouts.Footprint(names[i], key)
			if a.anchor ~= b.anchor or a.x ~= b.x or a.y ~= b.y or w1 ~= w2 or h1 ~= h2 or Layouts.Shown(names[1], key) ~= Layouts.Shown(names[i], key) then
				roles[key] = true
			end
		end
	end
	return roles
end

local Preview = {}

local function PlaceSlot(preview, s, line)
	local want = Layouts.Slot(preview.layout)
	local l, b, r, t = Layouts.Rect(want, want, REFERENCE_WIDTH, REFERENCE_HEIGHT)
	local slot = preview.slot
	slot:ClearAllPoints()
	slot:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", Widgets.Snap(preview, l * s), Widgets.Snap(preview, b * s))
	slot:SetSize(Widgets.Snap(preview, (r - l) * s), Widgets.Snap(preview, (t - b) * s))
	slot.fill:SetColorTexture(Widgets.Rgba("accent", SLOT_FILL))
	local top, bottom, left, right = slot.edges[1], slot.edges[2], slot.edges[3], slot.edges[4]
	for _, edge in ipairs(slot.edges) do
		edge:SetColorTexture(Widgets.Rgba("accent", SLOT_EDGE))
		edge:ClearAllPoints()
	end
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(line)
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(line)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(line)
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(line)
	slot:Show()
end

local function Widest(label, lines)
	local widest = 0
	for _, line in ipairs(lines) do
		Widgets.SetText(label, line)
		widest = max(widest, Widgets.TextWidth(label, math.huge))
	end
	return widest
end

local function Lines(text)
	local best
	for at in text:gmatch("() ") do
		if not best or math.abs(at - #text / 2) < math.abs(best - #text / 2) then
			best = at
		end
	end
	if not best then
		return nil
	end
	return { text:sub(1, best - 1), text:sub(best + 1) }
end

local function Fit(label, element, width, height)
	local texts = { element.label, element.short }
	local face, size, flags = label:GetFont()
	size = type(size) == "number" and math.floor(size) or Tokens.Size("caption")
	for points = size, LABEL_FLOOR, -1 do
		if face and points < size then
			label:SetFont(face, points, flags)
		end
		for _, split in ipairs({ false, true }) do
			for _, text in ipairs(texts) do
				local lines = split and Lines(text) or (not split and { text }) or nil
				if lines and #lines * points <= height - LABEL_ROOM and Widest(label, lines) <= width - LABEL_ROOM then
					Widgets.SetText(label, table.concat(lines, "\n"))
					return true
				end
			end
		end
	end
	return false
end

local function Name(rect, width, height)
	local label, element = rect.label, rect.element
	label:ClearAllPoints()
	label:SetPoint("CENTER", rect, "CENTER", 0, 0)
	label:SetJustifyH("CENTER")
	Widgets.StyleText(label, "caption")
	if Layouts.Dock(element.key) or Tokens.Size("caption") > height - LABEL_ROOM then
		label:Hide()
		return
	end
	label:SetShown(Fit(label, element, width, height))
end

function Preview:Draw(name)
	self.layout = name
	if self.nameText then
		self.nameText:SetText(string.format(L["Showing: %s"], Layouts.Label(name)))
	end
	self:Fit()
	local s = self:GetWidth() / REFERENCE_WIDTH
	local line = Widgets.Border(self)
	local positions = Layouts.Get(name)
	for _, rect in ipairs(self.rects) do
		local key = rect.element.key
		local w, h = Layouts.Footprint(name, key)
		local l, b, r, t = Layouts.Rect({ width = w, height = h }, positions[key], REFERENCE_WIDTH, REFERENCE_HEIGHT)
		local shown = Layouts.Shown(name, key) ~= false
		local width, height = max(line, Widgets.Snap(self, (r - l) * s)), max(line, Widgets.Snap(self, (t - b) * s))
		rect:SetShown(shown)
		rect:ClearAllPoints()
		rect:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", Widgets.Snap(self, l * s), Widgets.Snap(self, b * s))
		rect:SetSize(width, height)
		if rect.role then
			rect:SetColorTexture(Widgets.Rgba("accent", ROLE_ALPHA))
		else
			rect:SetColorTexture(Widgets.Rgba("text", ELEMENT_ALPHA))
		end
		if shown then
			Name(rect, width, height)
		else
			rect.label:Hide()
		end
	end
	PlaceSlot(self, s, line)
end

function Preview:Restyle()
	if self.layout then
		self:Draw(self.layout)
	end
end

local function NewPreview(page)
	local preview = CreateFrame("Frame", nil, page)
	for k, fn in pairs(Preview) do
		preview[k] = fn
	end
	Widgets.Track(preview)
	preview.chrome = Widgets.Chrome(preview, { shape = "tile", fill = "surface", shadow = true })
	preview.slot = CreateFrame("Frame", nil, preview)
	preview.slot.fill = preview.slot:CreateTexture(nil, "BACKGROUND")
	preview.slot.fill:SetAllPoints(preview.slot)
	preview.slot.edges = {}
	for i = 1, 4 do
		preview.slot.edges[i] = preview.slot:CreateTexture(nil, "BORDER")
	end
	preview.rects = {}
	for _, element in ipairs(Layouts.ELEMENTS) do
		if not SKIP_IN_PREVIEW[element.key] then
			local rect = preview:CreateTexture(nil, "ARTWORK")
			rect.element, rect.isElement, rect.role = element, true, Roles()[element.key] == true
			rect.label = Widgets.Text(preview, "caption", "textEmphasis", "OVERLAY")
			preview.rects[#preview.rects + 1] = rect
		end
	end
	return preview
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
	card.title = Widgets.Text(card, "heading", "textEmphasis")
	card.title:SetText(Layouts.Label(name))
	card.note = Paragraph(card, "body", "text", width)
	card.note:SetText(Layouts.Note(name))
	card.onClick = function()
		Setup.Choice().layout = name
		Changed()
	end
	Widgets.HookPointer(card)
	card:HookScript("OnEnter", function()
		panel.preview.hovered = true
		panel.preview:Draw(name)
	end)
	card:HookScript("OnLeave", function()
		panel.preview.hovered = false
		panel.preview:Draw(Setup.Choice().layout)
	end)
	card:Restyle()
	return Widgets.Track(card)
end

function Preview:Fit()
	if self.size then
		Widgets.Size(self, self.size[1], self.size[2])
		return
	end
	local page, width = self.page, self.pageWidth
	local spacing = gap("gapLarge")
	local top = Widgets.Snap(page, CARD_HEIGHT) + spacing
	local height = page:GetHeight()
	if type(height) ~= "number" or height <= top then
		height = top + PREVIEW_FALLBACK
	end
	local previewHeight = Widgets.Snap(page, height - top)
	local previewWidth = Widgets.Snap(page, min(width - spacing - LEGEND_WIDTH, previewHeight * REFERENCE_WIDTH / REFERENCE_HEIGHT))
	previewHeight = Widgets.Snap(page, previewWidth * REFERENCE_HEIGHT / REFERENCE_WIDTH)
	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -top)
	Widgets.Size(self, previewWidth, previewHeight)
	panel.layoutHint:SetWidth(width - previewWidth - spacing)
end

local function BuildLayouts(page, width)
	local names = Layouts.Names()
	local spacing = gap("gapLarge")
	local cardWidth = math.floor((width - spacing * (#names - 1)) / #names)
	panel.cards = {}
	for i, name in ipairs(names) do
		local card = NewCard(page, name, cardWidth)
		card:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * (cardWidth + spacing), 0)
		panel.cards[name] = card
	end
	local preview = NewPreview(page)
	preview.page, preview.pageWidth = page, width
	panel.preview = preview
	local shown = Widgets.Text(page, "heading", "textEmphasis")
	shown:SetJustifyH("LEFT")
	shown:SetPoint("TOPLEFT", preview, "TOPRIGHT", spacing, 0)
	preview.nameText = shown
	panel.previewName = shown
	local hint = Paragraph(page, "body", "text", width / 2)
	hint:SetPoint("TOPLEFT", shown, "BOTTOMLEFT", 0, -gap("gapMedium"))
	hint:SetText(L["The bright blocks change with the role. The outlined space on the left rail is the Story rail: Apply places the quest tracker there through Edit Mode, and Window skins put the RestedXP guide above it. In a raid, the raid frames take its top."]
		.. "\n\n" .. L["Point at a layout to preview it."]
		.. "\n\n" .. L["You can move and resize every element later in Layout Mode: type /kstyle layout."])
	panel.layoutHint = hint
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
	local preview = NewPreview(page)
	preview.size = { SUMMARY_PREVIEW, Widgets.Snap(page, SUMMARY_PREVIEW * REFERENCE_HEIGHT / REFERENCE_WIDTH) }
	preview:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
	local column = width - SUMMARY_PREVIEW - gap("gapLarge")
	local editMode = Paragraph(page, "body", "text", column)
	editMode:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -gap("gapHuge"))
	editMode:Hide()
	local retry = Widgets.Button(page, {
		text = L["Try again"],
		onClick = function()
			Setup.RetryEditMode()
		end,
	})
	retry:SetPoint("TOPLEFT", editMode, "BOTTOMLEFT", 0, -gap("gapMedium"))
	retry:Hide()
	local manager = Widgets.Button(page, {
		text = L["Open the Cooldown Manager"],
		onClick = function()
			local settings = Manager()
			if settings and not InCombatLockdown() then
				settings:ShowUIPanel()
			end
		end,
	})
	manager:SetPoint("LEFT", retry, "RIGHT", gap("gapSmall"), 0)
	manager:Hide()
	local help = Paragraph(page, "body", "text", column)
	help:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
	panel.summaryTitle, panel.summary, panel.summaryHelp, panel.summaryPreview = title, summary, help, preview
	panel.editMode, panel.retry, panel.manager = editMode, retry, manager
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
	local width = WIDTH - 2 * Widgets.WindowInset(panel)
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
	panel.skip = Widgets.Button(content, {
		text = L["Keep my UI"],
		onClick = function()
			Setup.Keep()
			panel:Close()
		end,
	})
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
	Setup.EditModeChanged = function()
		if panel:IsShown() then
			Refresh()
		end
	end
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
	panel.welcomeNote:SetShown(Setup.IsFirstRun())
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
