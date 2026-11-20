-- Window.lua: the setup, with HUD and role pictures, module and detected-addon choices, ornaments and the Apply summary.
local _, ns = ...

local Setup = ns.Setup
local Layouts = Setup.Layouts
local Widgets, Tokens, Motion, Scale = ns.Widgets, ns.Tokens, ns.Motion, ns.Scale
local L = ns.L
local max, min = math.max, math.min

local WIDTH, HEIGHT = 760, 540
local STEPS = 6
local STRIP_HEIGHT = 32
local FOOTER_HEIGHT = 28
local CARD_HEIGHT = 120
local ORNAMENT_CARD_HEIGHT = 64
local STYLE_PICTURE_SHARE = 0.5
local REFERENCE_HEIGHT = ns.Setup.Layouts.HEIGHT
local REFERENCE_WIDTH = REFERENCE_HEIGHT * 16 / 9
local LABEL_ROOM = 2
local LABEL_FLOOR = 8
local PREVIEW_FALLBACK, LEGEND_WIDTH = 260, 240
local ROW_HEIGHT = 44
local NOTE_SIZE = 11
local LAYOUT_PICTURE_WIDTH, LAYOUT_PICTURE_HEIGHT = 180, 90
local LAYOUT_PICTURE_PATH = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\Layout"
local ROWS_PER_COLUMN = 8
local HEADER_HEIGHT = 32
local ELEMENT_ALPHA, ROLE_ALPHA = 0.22, 0.5
local SLOT_FILL, SLOT_EDGE = 0.08, 0.7
local CARD_HOVER_EDGE = 0.6
local WINDOW_KEY = "setup.window"
local WINDOW_POSITION = { anchor = "CENTER", x = 0, y = 40 }
local SKIP_IN_PREVIEW = { ["groupframes.raid"] = true }
local STORY = { label = L["Story rail"], short = L["Quests"] }
local STEP_LABELS = { L["Welcome"], L["HUD style"], L["Layout"], L["Modules"], L["Ornaments"], L["Summary"] }
local STYLES = {
	{ value = "frames", label = L["Frames"], note = L["Your health and resource on the player frame above the action bars."], picture = "hudStyleFrames" },
	{ value = "orbs", label = L["Orbs"], note = L["Your health and resource in two orbs either side of the action bars."], picture = "hudStyleOrbs" },
	{ value = "medallions", label = L["Medallions"], note = L["Round portraits on your unit frames and a hub in the middle of one long action slab."], picture = "hudStyleMedallions" },
}
for i = #STYLES, 1, -1 do
	if not ns.HudStyle.Offered(STYLES[i].value) then
		table.remove(STYLES, i)
	end
end

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
	local choices, full = Setup.EditMode.Replacements()
	panel.replace:SetOptions(choices)
	panel.replace:SetValue(Setup.Choice().replaceLayout or "", true)
	panel.replace:SetShown(full and not applied and ns.Store.Module("Setup").replaceLayout)
	if step == STEPS then
		panel.summaryStatus.cap:SetText(SummaryTitle())
	end
end

local function Select(cards, value)
	for key, card in pairs(cards) do
		card.selected = key == value
		card:Paint()
		if card.selected then
			card.glow:Start()
		else
			card.glow:Stop()
		end
	end
end

local FitStyles, PlaceSummary, PlaceLayouts, PlaceModules

function Setup.RestyleText(frame, skip)
	if frame == skip then return end
	if frame:GetObjectType() == "EditBox" then Widgets.StyleText(frame, "body") end
	for _, text in ipairs({ frame:GetRegions() }) do
		if text:GetObjectType() == "FontString" then Widgets.StyleText(text) end
	end
	for _, child in ipairs({ frame:GetChildren() }) do Setup.RestyleText(child, skip) end
end

local function Refresh()
	local choice = Setup.Choice()
	panel.addons:Sync()
	for name, toggle in pairs(panel.toggles) do toggle:SetValue(choice.modules[name] == true, true) end
	panel.back:SetShown(step > 1)
	panel.skip:SetShown(step == 1)
	panel.next:SetShown(step < STEPS)
	panel.apply:SetShown(step == STEPS and not applied)
	panel.reload:SetShown(step == STEPS and applied)
	panel.later:SetShown(step == STEPS and applied)
	Select(panel.cards, choice.layout)
	Select(panel.ornamentCards, choice.ornaments)
	Select(panel.styleCards, choice.hudStyle)
	FitStyles()
	PlaceLayouts()
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
		local ornaments = Setup.Ornament(choice.ornaments)
		local style = STYLES[1].label
		for _, entry in ipairs(STYLES) do
			if entry.value == choice.hudStyle then
				style = entry.label
			end
		end
		local lead = string.format(L["HUD style: %s."], style) .. "\n" .. string.format(L["Layout: %s."], Layouts.Label(choice.layout))
		local head = lead .. "\n" .. string.format(L["Ornaments: %s. %s"], ornaments.label, ornaments.note) .. "\n\n"
		local tail = #off > 0 and "\n" .. L["Off: "] .. table.concat(off, ", ") or ""
		local modules = string.format(L["Modules on: %d of %d."], #on, #on + #off)
		local count = head .. modules
		panel.summaryTexts = { head .. L["On: "] .. (#on > 0 and table.concat(on, ", ") or L["none"]) .. tail, count .. tail, count }
		if ns.Store.Module("Setup").readableNotes then
			panel.summaryTexts[4] = lead .. "\n" .. string.format(L["Ornaments: %s. %s"], ornaments.label, "") .. "\n\n" .. modules
		end
		panel.summary:SetText(panel.summaryTexts[1])
		panel.summaryLayout.cap:SetText(string.format(L["%s layout"], Layouts.Label(choice.layout)))
		panel.summaryHelp:SetText(applied
			and L["Reload the interface to finish. Modules that replace Blizzard's frames need it."]
			or L["Apply switches these modules on or off, moves every element to the layout, then asks for a reload."])
		local bars = ns.Store.Module("ActionBars")
		if bars.bindingHints ~= false then panel.summaryHelp:SetText(panel.summaryHelp:GetText() .. "\n" .. L["Bind keys on the Action Bars page or the Layout Mode toolbar."]) end
	end
	RefreshEditMode()
	if step == STEPS then
		PlaceSummary()
		panel.summaryPreview:Draw(choice.layout)
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

local function NoteStyle(text)
	local readable = ns.Store.Module("Setup").readableNotes
	Widgets.Fitted(text, not readable and not text.bodyNote)
	text:SetWordWrap(readable or text.bodyNote == true)
	if readable then
		local path, _, flags = Tokens.Font("body")
		Widgets.ApplyFont(text, path, NOTE_SIZE * ns.Theme.FontScale(), flags)
	elseif text.bodyNote then
		Widgets.StyleText(text, "body")
	else
		Widgets.ApplyFont(text, Tokens.NoteFont())
	end
end

local function Paragraph(parent, role, color, width, small)
	local text = small and Widgets.FontString(parent) or Widgets.Text(parent, role, color)
	if small then
		text.bodyNote = small == "body"
		text.Restyle = NoteStyle
		Widgets.Track(text)
		NoteStyle(text)
		Widgets.TextColor(text, color)
	end
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetWordWrap(true)
	text:SetWidth(Widgets.Snap(parent, width))
	return text
end

local function WelcomeNote()
	local later = ns.Store.Module("Setup").closeBehaviour == "later"
	local text = later and L["Close or press Escape to set up later. Only Apply changes your interface."]
		or L["Close this window and KstyleUI applies the DPS layout with every module on and Full ornaments. Keep my UI leaves the game's own interface as it is."]
	if later and ns.Store.Module("ProfileTools").backups then text = text .. " " .. L["A backup is saved before Apply."] end
	return text
end

local function WelcomeSteps(page)
	local addons = #Setup.Choice().addons > 0
	Widgets.SetText(page.caption, addons and L["Six steps"] or L["Five steps"])
	page.list:SetText((ns.HudStyle.Offered("medallions") and L["1. Pick a HUD style: Frames, Orbs or Medallions."] or L["1. Pick a HUD style: Frames or Orbs."])
		.. "\n" .. L["2. Pick a layout: DPS, Tank or Healer."] .. "\n" .. L["3. Choose the modules you want."]
		.. "\n" .. (addons and L["4. Choose how KstyleUI works with your addons."] .. "\n" .. L["5. Pick the ornaments: Off, Subtle or Full."] .. "\n" .. L["6. Apply, then reload."]
			or L["4. Pick the ornaments: Off, Subtle or Full."] .. "\n" .. L["5. Apply, then reload."]))
end

local function BuildClassicWelcome(page)
	local pad = gap("gapLarge")
	local logo = page:CreateTexture(nil, "ARTWORK")
	logo:SetTexture((Tokens.Texture("logoLarge")))
	logo:SetSize(Widgets.Snap(page, 128), Widgets.Snap(page, 128))
	Widgets.Point(logo, "TOPLEFT", page, "TOPLEFT", pad, -pad)
	local title = Widgets.Text(page, "display", "textEmphasis")
	Widgets.Point(title, "TOPLEFT", logo, "TOPRIGHT", gap("gapHuge") * 2, 0)
	title:SetText(L["Welcome to KstyleUI"])
	local body = Paragraph(page, "body", "text", 520)
	Widgets.Point(body, "TOPLEFT", title, "BOTTOMLEFT", 0, -gap("gapLarge"))
	body:SetText(L["This short setup picks a layout and the parts of the interface KstyleUI replaces. You can change everything later in the settings window, and move or resize any element in Layout Mode."])
	local caption = Widgets.Text(page, "caption", "text")
	Widgets.Point(caption, "TOPLEFT", body, "BOTTOMLEFT", 0, -gap("gapHuge"))
	local list = Paragraph(page, "body", "textEmphasis", 520)
	Widgets.Point(list, "TOPLEFT", caption, "BOTTOMLEFT", 0, -gap("gapSmall"))
	page.caption, page.list = caption, list
	WelcomeSteps(page)
	local note = Paragraph(page, "body", "text", 520)
	Widgets.Point(note, "TOPLEFT", list, "BOTTOMLEFT", 0, -gap("gapHuge"))
	note:SetText(L["Close this window and KstyleUI applies the DPS layout with every module on and Full ornaments. Keep my UI leaves the game's own interface as it is."])
	return title, note
end

local function BuildBrandedWelcome(page)
	local pad, gutter = gap("gapLarge"), gap("gapSmall")
	local width = WIDTH - 2 * Widgets.WindowInset(panel)
	local hero = CreateFrame("Frame", nil, page)
	Widgets.Point(hero, "TOPLEFT", page, "TOPLEFT", 0, 0)
	Widgets.Size(hero, width, 92)
	hero.chrome = Widgets.Chrome(hero, { shape = "tile", fill = "buttonFill", shadow = false })
	local logo = hero:CreateTexture(nil, "ARTWORK")
	logo:SetTexture((Tokens.Texture("logoLarge")))
	Widgets.Size(logo, 72, 72)
	Widgets.Point(logo, "LEFT", hero, "LEFT", pad, 0)
	local title = Widgets.Text(hero, "display", "textEmphasis")
	Widgets.Point(title, "TOPLEFT", hero, "TOPLEFT", 100, -pad)
	title:SetText("KstyleUI")
	local version = Widgets.Text(hero, "caption", "text")
	Widgets.Point(version, "TOPRIGHT", hero, "TOPRIGHT", -pad, -pad)
	version:SetText(type(ns.VERSION) == "string" and not ns.VERSION:find("@", 1, true) and ns.VERSION or "")
	local body = Paragraph(hero, "body", "text", width - 112)
	Widgets.Point(body, "TOPLEFT", title, "BOTTOMLEFT", 0, -gutter)
	body:SetText(L["Dark forged chrome for the whole game."] .. "\n" .. L["Three HUDs. One setup. Every screen."])
	local pictures = CreateFrame("Frame", nil, page)
	Widgets.Point(pictures, "TOPLEFT", hero, "BOTTOMLEFT", 0, -gutter)
	Widgets.Size(pictures, width, 104)
	for i, style in ipairs(STYLES) do
		local card = CreateFrame("Frame", nil, pictures)
		local cardWidth = (width - gutter * (#STYLES - 1)) / #STYLES
		Widgets.Size(card, cardWidth, 104)
		Widgets.Point(card, "TOPLEFT", pictures, "TOPLEFT", (i - 1) * (cardWidth + gutter), 0)
		card.chrome = Widgets.Chrome(card, { shape = "tile", fill = "buttonFill", shadow = false })
		local picture = card:CreateTexture(nil, "ARTWORK")
		picture:SetTexture((Tokens.Texture(style.picture)))
		Widgets.Size(picture, 152, 76)
		Widgets.Point(picture, "TOP", card, "TOP", 0, -2)
		local label = Widgets.Text(card, "caps", "capsGold")
		Widgets.CapsSize(label)
		Widgets.Point(label, "BOTTOM", card, "BOTTOM", 0, gutter)
		Widgets.SetText(label, style.label)
	end
	local features = Paragraph(page, "body", "text", width * 0.51 - pad)
	Widgets.Point(features, "TOPLEFT", pictures, "BOTTOMLEFT", pad, -gap("gapLarge"))
	features:SetText(L["Pixel-perfect from laptop to ultrawide."] .. "\n"
		.. L["Three HUDs. DPS, Tank and Healer layouts."] .. "\n"
		.. L["Unit frames, nameplates, raids, bags, tooltips, meter and skins."] .. "\n"
		.. L["/kb: bind keys by hovering over a button."] .. "\n"
		.. L["Layout Mode and shareable profiles."] .. "\n"
		.. L["Every module optional. Make it yours."])
	features:SetSpacing(Widgets.Snap(page, 3))
	local caption = Widgets.Text(page, "caps", "capsGold")
	Widgets.CapsSize(caption)
	Widgets.Point(caption, "TOPLEFT", pictures, "BOTTOMLEFT", width * 0.53, -gap("gapLarge"))
	local list = Paragraph(page, "body", "textEmphasis", width * 0.47 - pad)
	Widgets.Point(list, "TOPLEFT", caption, "BOTTOMLEFT", 0, -gutter)
	local note = Paragraph(page, "body", "text", width - pad * 2)
	Widgets.Point(note, "BOTTOMLEFT", page, "BOTTOMLEFT", pad, gutter)
	note:SetText(L["Close this window and KstyleUI applies the DPS layout with every module on and Full ornaments. Keep my UI leaves the game's own interface as it is."])
	page.hero, page.pictures, page.features, page.caption, page.list = hero, pictures, features, caption, list
	WelcomeSteps(page)
	page.title, page.note, page.body, page.version = title, note, body, version
	return title, note
end

local function BuildWelcome(page)
	local classic = CreateFrame("Frame", nil, page)
	Widgets.Fill(classic, page, 0, 0, 0, 0)
	classic.title, classic.note = BuildClassicWelcome(classic)
	local scroll = CreateFrame("ScrollFrame", nil, page)
	Widgets.Fill(scroll, page, 0, 0, 0, 0)
	scroll:SetClipsChildren(true)
	scroll:EnableMouseWheel(true)
	local branded = CreateFrame("Frame", nil, scroll)
	Widgets.Size(branded, WIDTH - 2 * Widgets.WindowInset(panel), 400)
	scroll:SetScrollChild(branded)
	BuildBrandedWelcome(branded)
	local bar = CreateFrame("Frame", nil, page)
	Widgets.Point(bar, "TOPLEFT", scroll, "TOPRIGHT", gap("gapTiny"), 0)
	bar:SetFrameLevel(scroll:GetFrameLevel() + 10)
	local thumb = bar:CreateTexture(nil, "OVERLAY")
	local function ScrollTo(offset)
		local height, view = branded:GetHeight(), scroll:GetHeight()
		offset = Widgets.Snap(scroll, max(0, min(max(0, height - view), offset)))
		scroll:SetVerticalScroll(offset)
		Widgets.Size(bar, 2, view)
		thumb:ClearAllPoints()
		Widgets.Point(thumb, "TOPLEFT", bar, "TOPLEFT", 0, -offset * view / height)
		Widgets.Size(thumb, 2, view * view / height)
		bar:SetShown(scroll:IsShown() and height > view)
	end
	scroll:SetScript("OnMouseWheel", function(_, delta)
		ScrollTo(scroll:GetVerticalScroll() - delta * Widgets.LineHeight(branded.features) * 3)
	end)
	function page:Restyle()
		WelcomeSteps(classic)
		WelcomeSteps(branded)
		thumb:SetColorTexture(Widgets.Rgba("accent", 0.6))
		local shown = ns.Options.Read("Widgets", "general.brandedWelcome") ~= false
		classic:SetShown(not shown)
		scroll:SetShown(shown)
		local active = shown and branded or classic
		panel.welcomeTitle, panel.welcomeNote = active.title, active.note
		classic.note:SetText(WelcomeNote())
		branded.note:SetText(WelcomeNote())
		classic.note:SetShown(self.firstRun)
		branded.note:SetShown(self.firstRun)
		local pad, gutter = gap("gapLarge"), gap("gapSmall")
		local cap = Widgets.LineHeight(branded.caption)
		Widgets.Size(branded.hero, branded.hero:GetWidth(), max(92, pad * 2 + Widgets.LineHeight(branded.title) + gutter + Widgets.WrappedHeight(branded.body, branded.body:GetWidth())))
		local lower = max(Widgets.WrappedHeight(branded.features, branded.features:GetWidth()), cap + gutter + Widgets.WrappedHeight(branded.list, branded.list:GetWidth()))
		local height = branded.hero:GetHeight() + gutter + branded.pictures:GetHeight() + pad + lower + pad
		if branded.note:IsShown() then
			height = height + Widgets.WrappedHeight(branded.note, branded.note:GetWidth()) + gutter
		end
		Widgets.Size(branded, branded:GetWidth(), max(scroll:GetHeight(), height))
		ScrollTo(0)
	end
	page.scroll, page.branded, page.classic, page.bar, page.thumb = scroll, branded, classic, bar, thumb
	page:HookScript("OnShow", function(self)
		self.firstRun = Setup.IsFirstRun()
		self:Restyle()
	end)
	Widgets.Track(page)
	page.firstRun = Setup.IsFirstRun()
	page:Restyle()
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
	local picture = self.layout and ns.Store.Module("Setup").layoutPictures and LAYOUT_PICTURE_HEIGHT + Widgets.Snap(self, Tokens.Size("gapSmall")) or 0
	Widgets.Point(self.title, "TOPLEFT", self, "TOPLEFT", pad, -(pad + picture))
	self.note:ClearAllPoints()
	Widgets.Point(self.note, "TOPLEFT", self.title, "BOTTOMLEFT", 0, -Widgets.Snap(self, Tokens.Size("gapSmall")))
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
local FitLabel

local function PlaceSlot(preview, s, line)
	local want = Layouts.Slot(preview.layout)
	local l, b, r, t = Layouts.Rect(want, want, REFERENCE_WIDTH, REFERENCE_HEIGHT)
	local slot = preview.slot
	slot:ClearAllPoints()
	Widgets.Point(slot, "BOTTOMLEFT", preview, "BOTTOMLEFT", Widgets.Snap(preview, l * s), Widgets.Snap(preview, b * s))
	slot:SetSize(Widgets.Snap(preview, (r - l) * s), Widgets.Snap(preview, (t - b) * s))
	slot.fill:SetColorTexture(Widgets.Rgba("accent", SLOT_FILL))
	local top, bottom, left, right = slot.edges[1], slot.edges[2], slot.edges[3], slot.edges[4]
	for _, edge in ipairs(slot.edges) do
		edge:SetColorTexture(Widgets.Rgba("accent", SLOT_EDGE))
		edge:ClearAllPoints()
	end
	Widgets.Point(top, "TOPLEFT")
	Widgets.Point(top, "TOPRIGHT")
	top:SetHeight(line)
	Widgets.Point(bottom, "BOTTOMLEFT")
	Widgets.Point(bottom, "BOTTOMRIGHT")
	bottom:SetHeight(line)
	Widgets.Point(left, "TOPLEFT")
	Widgets.Point(left, "BOTTOMLEFT")
	left:SetWidth(line)
	Widgets.Point(right, "TOPRIGHT")
	Widgets.Point(right, "BOTTOMRIGHT")
	right:SetWidth(line)
	slot:Show()
	local label = slot.label
	label:ClearAllPoints()
	Widgets.Point(label, "CENTER", slot, "CENTER", 0, 0)
	label:SetJustifyH("CENTER")
	Widgets.StyleText(label, "caption")
	label:SetShown(FitLabel(label, STORY, slot:GetWidth(), slot:GetHeight()))
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
			Widgets.ApplyFont(label, face, points, flags)
		end
		local drawn = Widgets.LineHeight(label)
		for _, split in ipairs({ false, true }) do
			for _, text in ipairs(texts) do
				local lines = split and Lines(text) or (not split and { text }) or nil
				if lines and #lines * drawn <= height - LABEL_ROOM and Widest(label, lines) <= width - LABEL_ROOM then
					Widgets.SetText(label, table.concat(lines, "\n"))
					return true
				end
			end
		end
	end
	return false
end

FitLabel = Fit

local function Name(rect, width, height)
	local label, element = rect.label, rect.element
	label:ClearAllPoints()
	Widgets.Point(label, "CENTER", rect, "CENTER", 0, 0)
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
		local w, h, offsetX = Layouts.Footprint(name, key)
		local l, b, r, t = Layouts.Rect({ width = w, height = h, offsetX = offsetX }, positions[key], REFERENCE_WIDTH, REFERENCE_HEIGHT)
		local shown = Layouts.Shown(name, key) ~= false
		local width, height = max(line, Widgets.Snap(self, (r - l) * s)), max(line, Widgets.Snap(self, (t - b) * s))
		rect:SetShown(shown)
		rect:ClearAllPoints()
		Widgets.Point(rect, "BOTTOMLEFT", self, "BOTTOMLEFT", Widgets.Snap(self, l * s), Widgets.Snap(self, b * s))
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
	preview.slot.label = Widgets.Text(preview.slot, "caption", "textEmphasis", "OVERLAY")
	preview.rects = {}
	for _, element in ipairs(Layouts.ELEMENTS) do
		if not SKIP_IN_PREVIEW[element.key] then
			local rect = preview:CreateTexture(nil, "ARTWORK")
			rect.element, rect.isElement, rect.role = element, true, Roles()[element.key] == true
			rect.label = Widgets.Fitted(Widgets.Text(preview, "caption", "textEmphasis", "OVERLAY"))
			preview.rects[#preview.rects + 1] = rect
		end
	end
	return preview
end

local function NewCard(page, width, height, title, note, pick)
	local card = CreateFrame("Button", nil, page)
	for k, fn in pairs(Card) do
		card[k] = fn
	end
	Widgets.Size(card, width, height)
	card.chrome = Widgets.Chrome(card, { shape = "tile", fill = "buttonFill", shadow = false })
	card.glow = Widgets.Glow(card, { kind = "selection" })
	card.title = Widgets.Text(card, "caps", "capsGold")
	Widgets.CapsSize(card.title)
	card.title:SetText(title)
	card.note = Paragraph(card, "body", "text", width, "body")
	card.note:SetText(note)
	card.onClick = function()
		pick()
		Changed()
	end
	Widgets.HookPointer(card)
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
	Widgets.Point(self, "TOPLEFT", page, "TOPLEFT", 0, -top)
	Widgets.Size(self, previewWidth, previewHeight)
	panel.layoutHint:SetWidth(width - previewWidth - spacing)
end

local function BuildLayouts(page, width)
	local names = Layouts.Names()
	local spacing = gap("gapLarge")
	local cardWidth = math.floor((width - spacing * (#names - 1)) / #names)
	panel.cards = {}
	for i, name in ipairs(names) do
		local card = NewCard(page, cardWidth, CARD_HEIGHT, Layouts.Label(name), Layouts.Note(name), function()
			Setup.Choice().layout = name
		end)
		card.layout = name
		card:HookScript("OnEnter", function()
			panel.preview.hovered = true
			panel.preview:Draw(name)
		end)
		card:HookScript("OnLeave", function()
			panel.preview.hovered = false
			panel.preview:Draw(Setup.Choice().layout)
		end)
		Widgets.Point(card, "TOPLEFT", page, "TOPLEFT", (i - 1) * (cardWidth + spacing), 0)
		panel.cards[name] = card
		card.picture = card:CreateTexture(nil, "ARTWORK")
		Widgets.Size(card.picture, LAYOUT_PICTURE_WIDTH, LAYOUT_PICTURE_HEIGHT)
		Widgets.Point(card.picture, "TOP", card, "TOP", 0, -gap("gapLarge"))
	end
	local preview = NewPreview(page)
	preview.page, preview.pageWidth = page, width
	panel.preview = preview
	local shown = Widgets.Text(page, "heading", "textEmphasis")
	shown:SetJustifyH("LEFT")
	Widgets.Point(shown, "TOPLEFT", preview, "TOPRIGHT", spacing, 0)
	preview.nameText = shown
	panel.previewName = shown
	local hint = Paragraph(page, "body", "text", width / 2, "body")
	Widgets.Point(hint, "TOPLEFT", shown, "BOTTOMLEFT", 0, -gap("gapMedium"))
	panel.layoutHint = hint
end

PlaceLayouts = function()
	local pictures = ns.Store.Module("Setup").layoutPictures
	local style = Setup.Choice().hudStyle
	local pad, spacing = gap("gapLarge"), gap("gapSmall")
	local height = CARD_HEIGHT
	for name, card in pairs(panel.cards) do
		card.picture:SetShown(pictures)
		card.picture:SetTexture(LAYOUT_PICTURE_PATH .. style:sub(1, 1):upper() .. style:sub(2) .. name .. ".tga")
		card.title:ClearAllPoints()
		Widgets.Point(card.title, "TOPLEFT", card, "TOPLEFT", pad, -(pictures and pad + LAYOUT_PICTURE_HEIGHT + spacing or pad))
		height = max(height, (pictures and LAYOUT_PICTURE_HEIGHT + spacing or 0) + 2 * pad + Widgets.LineHeight(card.title) + spacing + Widgets.WrappedHeight(card.note, card:GetWidth() - 2 * pad))
	end
	for _, card in pairs(panel.cards) do Widgets.Size(card, card:GetWidth(), height) end
	panel.preview:SetShown(not pictures)
	panel.previewName:SetShown(not pictures)
	panel.layoutHint:ClearAllPoints()
	if pictures then
		Widgets.Point(panel.layoutHint, "TOPLEFT", panel.pages[3], "TOPLEFT", 0, -(height + gap("gapLarge")))
		panel.layoutHint:SetWidth(panel.preview.pageWidth)
		panel.layoutHint:SetText(L["Choose DPS, Tank or Healer. Each picture shows your chosen HUD style; you can move and resize everything later in Layout Mode."])
	else
		Widgets.Point(panel.layoutHint, "TOPLEFT", panel.previewName, "BOTTOMLEFT", 0, -gap("gapMedium"))
		panel.layoutHint:SetText(L["The bright blocks change with the role. The outlined space on the right rail, under the map, is the Story rail: Apply places the quest tracker there through Edit Mode, and Window skins put the RestedXP guide above it."]
			.. "\n\n" .. L["Point at a layout to preview it."] .. "\n\n" .. L["You can move and resize every element later in Layout Mode: type /kstyle layout."])
	end
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
	local header = Paragraph(page, "body", "text", width / 2, "body")
	Widgets.Point(header, "TOPLEFT", page, "TOPLEFT", 0, -gap("gapSmall"))
	panel.moduleNote = header
	local allOff = Widgets.Button(page, { text = L["All off"], onClick = function() SetAll(false) end })
	Widgets.Point(allOff, "TOPRIGHT", page, "TOPRIGHT", 0, 0)
	local allOn = Widgets.Button(page, { text = L["All on"], onClick = function() SetAll(true) end })
	Widgets.Point(allOn, "RIGHT", allOff, "LEFT", -gap("gapSmall"), 0)
	local top = Widgets.Snap(page, HEADER_HEIGHT) + gap("gapMedium")
	local scroll = CreateFrame("ScrollFrame", nil, page)
	Widgets.Fill(scroll, page, 0, top, 0, 0)
	scroll:SetClipsChildren(true)
	scroll:EnableMouseWheel(true)
	local body = CreateFrame("Frame", nil, scroll)
	Widgets.Size(body, width, 1)
	scroll:SetScrollChild(body)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		scroll:SetVerticalScroll(max(0, min(max(0, body:GetHeight() - scroll:GetHeight()), (scroll:GetVerticalScroll() or 0) - delta * ROW_HEIGHT)))
	end)
	panel.moduleScroll, panel.moduleBody = scroll, body
	panel.toggles = {}
	for _, entry in ipairs(Setup.PICKER) do
		local name = entry.name
		local toggle = Widgets.Toggle(body, {
			label = entry.label,
			onChange = function(value)
				Setup.Choice().modules[name] = value
				Changed()
			end,
		})
		local note = Widgets.FontString(body)
		note.Restyle = NoteStyle
		Widgets.Track(note)
		NoteStyle(note)
		note:SetJustifyH("LEFT")
		toggle.note = note
		panel.toggles[name] = toggle
	end
end

PlaceModules = function()
	local column = panel.moduleBody:GetWidth() / 2
	local top = ns.Store.Module("Setup").readableNotes and max(HEADER_HEIGHT, Widgets.WrappedHeight(panel.moduleNote, panel.moduleNote:GetWidth())) or HEADER_HEIGHT
	Widgets.Fill(panel.moduleScroll, panel.pages[4], 0, top + gap("gapMedium"), 0, 0)
	local heights = { 0, 0 }
	for i, entry in ipairs(Setup.PICKER) do
		local col = i <= ROWS_PER_COLUMN and 1 or 2
		local toggle = panel.toggles[entry.name]
		NoteStyle(toggle.note)
		local indent = toggle.trackBox:GetWidth() + gap("gapMedium")
		toggle:ClearAllPoints()
		Widgets.Point(toggle, "TOPLEFT", panel.moduleBody, "TOPLEFT", (col - 1) * column, -heights[col])
		toggle.note:ClearAllPoints()
		Widgets.Point(toggle.note, "TOPLEFT", toggle, "BOTTOMLEFT", indent, -gap("gapTiny"))
		toggle.note:SetWidth(column - indent - gap("gapLarge"))
		local height = ns.Store.Module("Setup").readableNotes and max(ROW_HEIGHT, toggle:GetHeight() + gap("gapTiny") + Widgets.WrappedHeight(toggle.note, toggle.note:GetWidth()) + gap("gapSmall")) or ROW_HEIGHT
		heights[col] = heights[col] + Widgets.Snap(panel.moduleBody, height)
	end
	panel.moduleBody:SetHeight(max(heights[1], heights[2]))
	panel.moduleScroll:SetVerticalScroll(max(0, min(panel.moduleScroll:GetVerticalScroll() or 0, panel.moduleBody:GetHeight() - panel.moduleScroll:GetHeight())))
end

local function BuildStyles(page, width)
	local spacing = gap("gapLarge")
	local cardWidth = math.floor((width - spacing * (#STYLES - 1)) / #STYLES)
	local pad = gap("gapLarge")
	local pictureWidth = cardWidth - 2 * pad
	local pictureHeight = Widgets.Snap(page, pictureWidth * STYLE_PICTURE_SHARE)
	panel.styleCards = {}
	for i, entry in ipairs(STYLES) do
		local value = entry.value
		local card = NewCard(page, cardWidth, pictureHeight + 2 * pad, entry.label, entry.note, function()
			Setup.Choice().hudStyle = value
		end)
		card.hudStyle = value
		card.picture = card:CreateTexture(nil, "ARTWORK")
		card.picture:SetTexture((Tokens.Texture(entry.picture)))
		card.picture:SetSize(Widgets.Snap(card, pictureWidth), pictureHeight)
		Widgets.Point(card.picture, "TOP", card.note, "BOTTOM", 0, -gap("gapMedium"))
		Widgets.Point(card.picture, "LEFT", card, "LEFT", pad, 0)
		Widgets.Point(card, "TOPLEFT", page, "TOPLEFT", (i - 1) * (cardWidth + spacing), 0)
		panel.styleCards[value] = card
	end
	local hint = Paragraph(page, "body", "text", width, "body")
	hint:SetText(L["Change it at any time in the settings window, at the top of the General page. A change made in combat waits until combat ends."])
	panel.styleHint = hint
	panel.styleFit = { width = cardWidth, picture = pictureHeight, pad = pad, spacing = spacing }
end

FitStyles = function()
	local fit, page = panel.styleFit, panel.pages[2]
	local height = 0
	for _, card in pairs(panel.styleCards) do
		local text = Widgets.LineHeight(card.title) + gap("gapSmall") + Widgets.WrappedHeight(card.note, fit.width - 2 * fit.pad)
		height = max(height, fit.pad + text + gap("gapMedium") + fit.picture + fit.pad)
	end
	for _, card in pairs(panel.styleCards) do
		Widgets.Size(card, fit.width, height)
	end
	panel.styleHint:ClearAllPoints()
	Widgets.Point(panel.styleHint, "TOPLEFT", page, "TOPLEFT", 0, -(Widgets.Snap(page, height) + fit.spacing))
end

local function BuildOrnaments(page, width)
	local spacing = gap("gapLarge")
	local height = Widgets.Snap(page, ORNAMENT_CARD_HEIGHT)
	panel.ornamentCards = {}
	for i, entry in ipairs(Setup.ORNAMENTS) do
		local value = entry.value
		local card = NewCard(page, width, ORNAMENT_CARD_HEIGHT, entry.label, entry.note, function()
			Setup.Choice().ornaments = value
		end)
		card.ornaments = value
		Widgets.Point(card, "TOPLEFT", page, "TOPLEFT", 0, -(i - 1) * (height + spacing))
		panel.ornamentCards[value] = card
	end
	local hint = Paragraph(page, "body", "text", width, "body")
	Widgets.Point(hint, "TOPLEFT", page, "TOPLEFT", 0, -#Setup.ORNAMENTS * (height + spacing))
	hint:SetText(L["Ornaments add forged trim around the HUD without moving anything. They show on every card material but Glass."]
		.. "\n\n" .. L["Change them at any time in the settings window, on the General page."])
	panel.ornamentHint = hint
end

local function SummaryCard(page, text)
	local card = CreateFrame("Frame", nil, page)
	card.chrome = Widgets.Chrome(card, { shape = "card", shadow = false })
	card.cap = Widgets.SectionCap(card, { text = text })
	return card
end

local function SizeCard(card, x, y, width, height, pad)
	card:ClearAllPoints()
	Widgets.Point(card, "TOPLEFT", card:GetParent(), "TOPLEFT", x, -y)
	Widgets.Size(card, width, height)
	card.cap.opts.width = width - 2 * pad
	card.cap:Restyle()
	card.cap:ClearAllPoints()
	Widgets.Point(card.cap, "TOPLEFT", card, "TOPLEFT", pad, -pad)
end

PlaceSummary = function()
	local page = panel.pages[STEPS]
	local width, height = page:GetWidth(), page:GetHeight()
	if type(width) ~= "number" or width <= 0 or type(height) ~= "number" or height <= 0 then
		width, height = panel.summaryWidth, PREVIEW_FALLBACK + CARD_HEIGHT
	end
	local pad, spacing, line = gap("gapHuge"), gap("gapLarge"), gap("gapMedium")
	local column = Widgets.Snap(page, (width - spacing) / 2)
	local inner, full = column - 2 * pad, width - 2 * pad
	local cap = Widgets.Snap(page, Widgets.SECTION_CAP_HEIGHT)
	local top = pad + cap + line
	local summary, editMode, help, retry = panel.summary, panel.editMode, panel.summaryHelp, panel.retry
	summary:SetWidth(inner)
	editMode:SetWidth(full)
	help:SetWidth(full)
	local y = top
	if panel.replace:IsShown() then y = y + panel.replace:GetHeight() + line end
	local editAt, retryAt
	if editMode:IsShown() then
		editAt, y = y, y + Widgets.Snap(page, Widgets.WrappedHeight(editMode, full)) + line
	end
	if retry:IsShown() then
		retryAt, y = y, y + Widgets.Snap(page, retry:GetHeight()) + line
	end
	local helpAt = y
	local status = y + Widgets.Snap(page, Widgets.WrappedHeight(help, full)) + pad
	local free = height - spacing - status
	local choices
	for _, text in ipairs(panel.summaryTexts or { summary:GetText() or "" }) do
		summary:SetText(text)
		choices = top + Widgets.WrappedHeight(summary, inner) + pad
		if choices <= free then
			break
		end
	end
	local row = Widgets.Snap(page, free)
	local left, right, low = panel.summaryChoices, panel.summaryLayout, panel.summaryStatus
	panel.replace:ClearAllPoints()
	Widgets.Point(panel.replace, "TOPLEFT", low, "TOPLEFT", pad, -top)
	SizeCard(left, 0, 0, column, row, pad)
	SizeCard(right, column + spacing, 0, column, row, pad)
	SizeCard(low, 0, row + spacing, width, max(status, height - row - spacing), pad)
	summary:ClearAllPoints()
	Widgets.Point(summary, "TOPLEFT", left, "TOPLEFT", pad, -top)
	local room = row - top - pad
	local previewWidth = Widgets.Snap(page, min(inner, room * REFERENCE_WIDTH / REFERENCE_HEIGHT))
	local previewHeight = Widgets.Snap(page, previewWidth * REFERENCE_HEIGHT / REFERENCE_WIDTH)
	local preview = panel.summaryPreview
	preview.size = { previewWidth, previewHeight }
	preview:ClearAllPoints()
	Widgets.Point(preview, "TOPLEFT", right, "TOPLEFT", Widgets.Snap(page, (column - previewWidth) / 2), -(top + Widgets.Snap(page, (room - previewHeight) / 2)))
	editMode:ClearAllPoints()
	Widgets.Point(editMode, "TOPLEFT", low, "TOPLEFT", pad, -(editAt or top))
	retry:ClearAllPoints()
	Widgets.Point(retry, "TOPLEFT", low, "TOPLEFT", pad, -(retryAt or top))
	help:ClearAllPoints()
	Widgets.Point(help, "TOPLEFT", low, "TOPLEFT", pad, -helpAt)
end

local function BuildSummary(page, width)
	local choices = SummaryCard(page, L["Your choices"])
	local layout = SummaryCard(page, L["Layout"])
	local status = SummaryCard(page, L["Ready to apply"])
	local summary = Paragraph(choices, "body", "textEmphasis", width, "body")
	local preview = NewPreview(layout)
	local editMode = Paragraph(status, "body", "text", width, true)
	editMode:Hide()
	local retry = Widgets.Button(status, {
		text = L["Try again"],
		onClick = function()
			Setup.RetryEditMode()
		end,
	})
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
	Widgets.Point(manager, "LEFT", retry, "RIGHT", gap("gapSmall"), 0)
	manager:Hide()
	local help = Paragraph(status, "body", "muted", width, true)
	panel.replace = Widgets.Dropdown(status, { width = 260, placeholder = L["Replace this one"], onChange = function(value)
		Setup.Choice().replaceLayout = value
		Changed()
	end })
	panel.replace:Hide()
	panel.summaryChoices, panel.summaryLayout, panel.summaryStatus, panel.summaryWidth = choices, layout, status, width
	panel.summaryTitle, panel.summary, panel.summaryHelp, panel.summaryPreview = status.cap.label, summary, help, preview
	panel.editMode, panel.retry, panel.manager = editMode, retry, manager
	page.Restyle = function()
		if step == STEPS then
			PlaceSummary()
			preview:Draw(Setup.Choice().layout)
		end
	end
	Widgets.Track(page)
end

local function SyncChoice()
	local choice = Setup.Choice()
	panel.moduleNote:SetText(ns.Store.Module("Integrations").notices
		and L["On uses KstyleUI; Off keeps your other addon for that feature."]
		or L["Every module starts on. Turn off any you do not want."])
	for _, entry in ipairs(Setup.PICKER) do
		local toggle = panel.toggles[entry.name]
		local available = Setup.Available(entry.name)
		toggle:SetEnabled(available)
		toggle:SetValue(choice.modules[entry.name] == true, true)
		if available then
			toggle.note:SetText(Setup.Integrations.Note(entry.name, entry.note))
		else
			toggle.note:SetText(L["Not installed, or turned off in the AddOns list."])
		end
		Widgets.TextColor(toggle.note, available and "text" or "textDisabled")
	end
	PlaceModules()
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
	Widgets.Point(panel.steps, "TOPLEFT", content, "TOPLEFT", 0, 0)
	panel.pages = {}
	for i = 1, STEPS do
		local page = CreateFrame("Frame", nil, content)
		Widgets.Fill(page, content, 0, STRIP_HEIGHT + Tokens.Size("gapLarge"), 0, FOOTER_HEIGHT + Tokens.Size("gapLarge"))
		page:Hide()
		panel.pages[i] = page
	end
	BuildWelcome(panel.pages[1])
	BuildStyles(panel.pages[2], width)
	BuildLayouts(panel.pages[3], width)
	BuildModules(panel.pages[4], width)
	BuildOrnaments(panel.pages[5], width)
	BuildSummary(panel.pages[6], width)
	panel.ornamentPage, panel.summaryPage = panel.pages[5], panel.pages[6]
	panel.addonsPage = CreateFrame("Frame", nil, content)
	Widgets.Fill(panel.addonsPage, panel.pages[4])
	panel.addonsPage:Hide()
	panel.addons = Setup.AddonsPage(panel.addonsPage, width, Changed)
	panel.back = Widgets.Button(content, { text = L["Back"], onClick = function() Setup.Go(step - 1) end })
	Widgets.Point(panel.back, "BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
	panel.skip = Widgets.Button(content, {
		text = L["Keep my UI"],
		onClick = function()
			Setup.Keep()
			panel:Close()
		end,
	})
	Widgets.Point(panel.skip, "BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
	panel.next = Widgets.Button(content, { text = L["Next"], primary = true, onClick = function() Setup.Go(step + 1) end })
	Widgets.Point(panel.next, "BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
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
	Widgets.Point(panel.apply, "BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
	panel.reload = Widgets.ReloadButton(content, {})
	Widgets.Point(panel.reload, "BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
	panel.later = Widgets.Button(content, { text = L["Later"], onClick = function() panel:Close() end })
	Widgets.Point(panel.later, "RIGHT", panel.reload, "LEFT", -gap("gapSmall"), 0)
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
	local addons = #Setup.Choice().addons > 0
	STEPS = addons and 7 or 6
	panel.pages[5] = addons and panel.addonsPage or panel.ornamentPage
	panel.pages[6] = addons and panel.ornamentPage or panel.summaryPage
	panel.pages[7] = addons and panel.summaryPage or nil
	local tabs = {}
	for i, label in ipairs(STEP_LABELS) do
		if addons and i == 5 then tabs[#tabs + 1] = { value = 5, label = L["Your addons"], disabled = true } end
		tabs[#tabs + 1] = { value = #tabs + 1, label = label, disabled = i > 1 }
	end
	panel.steps:SetTabs(tabs, 1)
	panel.addons:Refresh()
	step = 0
	panel.welcomeNote:SetText(WelcomeNote())
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

ns.Callbacks.Register("SettingChanged", "SetupWindow", function(_, module)
	if panel and (module == "Setup" or module == "ProfileTools" or module == "OptionsPresentation") then
		Widgets.RestyleUnder({ [panel] = true })
		panel.pages[1]:Restyle()
		PlaceLayouts()
		PlaceModules()
		panel.addons:Restyle()
	end
end)

ns.Callbacks.Register("LayoutChanged", "SetupWindow", function(_, key)
	if panel and key == WINDOW_KEY and ns.Store.Module("Setup").readableNotes then
		Setup.RestyleText(panel)
		Widgets.RestyleUnder({ [panel] = true })
		PlaceLayouts()
		PlaceModules()
		panel.addons:Restyle()
	end
end)

ns.Callbacks.Register("ThemeChanged", "SetupWindow", function()
	if panel then Refresh(); PlaceModules(); panel.addons:Restyle() end
end)
