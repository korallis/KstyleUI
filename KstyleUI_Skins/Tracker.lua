-- Tracker.lua: the objective tracker skin: a glass panel that follows the tracked content, one caption header per module with an accent chevron and rule, accent POI discs numbered in order, accent quest titles, the skin font and KstyleUI progress and timer bars.
local _, ns = ...

local K = KstyleUI
local Skin, L, Tokens, Widgets = K.Skin, K.L, K.Tokens, K.Widgets
local Style, Parts, Skins = ns.Style, ns.Parts, ns.Skins

local KEY = "tracker"
local LINE_DEFAULT, HEADER_EXTRA = 12, 2
local PANEL_LEFT, PANEL_TOP, PANEL_BOTTOM = 16, -4, -8
local LINE_ALPHA, LINE_UNITS, LINE_INSET = 0.5, 1, -2
local CHEVRON_UNITS, CAPTION_Y, CAPTION_SIZE, CAPTION_RIGHT = 19, 2, 12.5, 24
local QUARTER_TURN = math.pi / 2
local DISC_UNITS, RING_UNITS, NUMERAL_SIZE = 18, 24, 11
local RING_ALPHA, HOVER_RING_ALPHA, HOVER_MIX = 0.9, 0.45, 0.15
local THIN_SPACE = "\226\128\137"
local CODEPOINT = "([\1-\127\194-\244][\128-\191]*)"

local WEAK = { __mode = "k" }
local done = setmetatable({}, WEAK)
local hushedTexts = setmetatable({}, WEAK)
local captions = setmetatable({}, WEAK)
local discs = setmetatable({}, WEAK)
local titles = setmetatable({}, WEAK)
local fonts = {}
local panel, fit, fitTop, fitBottom
local allRow, allGlyph, allLine
local hasContents = false
local rehushing = false

local function Log(message)
	K.DevTest.Log("Skins", KEY .. ": " .. message)
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function PlainSize(value)
	if IsSecret(value) or type(value) ~= "number" or value <= 0 then
		return nil
	end
	return value
end

local function PlainText(value)
	if IsSecret(value) or type(value) ~= "string" then
		return ""
	end
	return value
end

local function PaintFont(entry)
	Style.ApplyFont(entry.object, entry.role, entry.size * Style.Setting("text", "size"))
end

local function PaintFonts()
	if not Skins.Setting(KEY, "font") then
		return
	end
	for _, entry in ipairs(fonts) do
		PaintFont(entry)
	end
end

local function WatchFont(name, role, fallback)
	local object = _G[name]
	if type(object) ~= "table" or type(object.SetFont) ~= "function" or type(object.GetFont) ~= "function" then
		Log(name .. " is missing on this client; the tracker keeps Blizzard's font")
		return
	end
	local _, size = object:GetFont()
	local entry = { object = object, role = role, size = PlainSize(size) or fallback }
	fonts[#fonts + 1] = entry
	if type(object.SetFontObject) == "function" then
		hooksecurefunc(object, "SetFontObject", function(_, source)
			local sourceName = source
			if type(source) == "table" and type(source.GetName) == "function" then
				sourceName = source:GetName()
			end
			local picked = type(sourceName) == "string" and tonumber(sourceName:match("(%d+)$"))
			if picked then
				entry.size = picked
			end
			if Skins.Setting(KEY, "font") then
				PaintFont(entry)
			end
		end)
	end
end

local function Rehush(text)
	if rehushing then
		return
	end
	rehushing = true
	text:SetAlpha(0)
	rehushing = false
end

local function HushText(text)
	if type(text) ~= "table" or type(text.SetAlpha) ~= "function" or hushedTexts[text] then
		return
	end
	hushedTexts[text] = true
	text:SetAlpha(0)
	hooksecurefunc(text, "SetAlpha", Rehush)
end

local function Tracked(value)
	local path = Style.Font("caption")
	if type(path) ~= "string" or not path:find("KstyleUI", 1, true) then
		return value
	end
	return (value:gsub(CODEPOINT, "%1" .. THIN_SPACE):sub(1, -#THIN_SPACE - 1))
end

local function SetCaption(state, value)
	state.value = PlainText(value)
	state.text:SetText(Tracked(state.value:upper()))
end

local function RestyleCaption(state)
	Style.Text(state.text, "caption", "textEmphasis")
	Style.ApplyFont(state.text, "caption", CAPTION_SIZE * Style.Setting("text", "size"))
	local left = Widgets.Inset(state.row, Tokens.Size("chamferWindow")) - PANEL_LEFT
	state.text:ClearAllPoints()
	state.text:SetPoint("LEFT", state.row, "LEFT", Widgets.Snap(state.row, left + CHEVRON_UNITS + Tokens.Size("gapSmall")), Widgets.Snap(state.row, CAPTION_Y))
	state.text:SetPoint("RIGHT", state.row, "RIGHT", -Widgets.Snap(state.row, CAPTION_RIGHT), Widgets.Snap(state.row, CAPTION_Y))
	state.text:SetJustifyH("LEFT")
	state.text:SetWordWrap(false)
	Widgets.Size(state.chevron, CHEVRON_UNITS, CHEVRON_UNITS)
	state.chevron:ClearAllPoints()
	state.chevron:SetPoint("LEFT", state.row, "LEFT", Widgets.Snap(state.row, left), Widgets.Snap(state.row, CAPTION_Y))
	Style.TintAccent(state.chevron)
	SetCaption(state, state.value)
end

local function CaptionRow(header, value)
	local row = CreateFrame("Frame", nil, header)
	row:SetAllPoints(header)
	row:SetFrameLevel(header:GetFrameLevel() + 1)
	local chevron = row:CreateTexture(nil, "OVERLAY")
	chevron:SetTexture((Tokens.Texture("glyphChevron")))
	chevron:SetRotation(-QUARTER_TURN)
	local state = { row = row, chevron = chevron, text = Widgets.FontString(row, "OVERLAY"), value = "", Restyle = RestyleCaption }
	RestyleCaption(state)
	SetCaption(state, value)
	Style.Track(state)
	Widgets.Track(state)
	captions[header] = state
	return state
end

local function Header(header, value)
	if type(header) ~= "table" or done[header] then
		return
	end
	done[header] = true
	Parts.Hush(header.Background)
	Parts.Hush(header.Shine)
	Parts.Hush(header.Glow)
	local text = header.Text
	local follows = value == nil and type(text) == "table" and type(text.GetText) == "function" and type(text.SetText) == "function"
	if type(text) == "table" then
		HushText(text)
	end
	if follows then
		value = PlainText(text:GetText())
	end
	local state = CaptionRow(header, value or "")
	if follows then
		hooksecurefunc(text, "SetText", function(_, newValue)
			SetCaption(state, newValue)
		end)
	end
	local line = Parts.AccentLine(header, { alpha = LINE_ALPHA, units = LINE_UNITS, inset = LINE_INSET })
	local chevron = Parts.Glyph(header.MinimizeButton, "glyphChevron", { flip = true })
	if chevron and type(header.SetCollapsed) == "function" then
		local function Point(_, collapsed)
			chevron:SetTexCoord(0, 1, collapsed and 0 or 1, collapsed and 1 or 0)
		end
		hooksecurefunc(header, "SetCollapsed", Point)
		local owner = header:GetParent()
		Point(nil, owner and type(owner.IsCollapsed) == "function" and owner:IsCollapsed() == true)
	end
	return state, chevron, line
end

local function TitleColor(block)
	local r, g, b = Style.Accent()
	if block.isHighlighted == true then
		r, g, b = Widgets.Mix(r, g, b, 1, 1, 1, 1, 1, HOVER_MIX)
	end
	return r, g, b
end

local function PaintTitle(block)
	local text = block.HeaderText
	if type(text) ~= "table" or type(text.SetTextColor) ~= "function" then
		return
	end
	if Skins.Setting(KEY, "titles") then
		text:SetTextColor(TitleColor(block))
		return
	end
	local c = text.colorStyle
	if type(c) == "table" and not IsSecret(c.r) and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
		text:SetTextColor(c.r, c.g, c.b)
	end
end

local function PaintTitles()
	for block in pairs(titles) do
		PaintTitle(block)
	end
end

local function WatchTitle(block)
	if titles[block] then
		return
	end
	titles[block] = true
	if type(block.SetHeader) == "function" then
		hooksecurefunc(block, "SetHeader", PaintTitle)
	end
	if type(block.UpdateHighlight) == "function" then
		hooksecurefunc(block, "UpdateHighlight", PaintTitle)
	end
end

local function PaintDisc(state)
	local button = state.button
	local selected = type(button.IsSelected) == "function" and button:IsSelected() == true
	Style.TintAccent(state.disc)
	Style.TintAccent(state.ring, selected and RING_ALPHA or HOVER_RING_ALPHA)
	state.ring:SetShown(selected or state.hover)
end

local function RestyleDisc(state)
	Widgets.Size(state.disc, DISC_UNITS, DISC_UNITS)
	Widgets.Size(state.ring, RING_UNITS, RING_UNITS)
	Style.ApplyFont(state.numeral, "number", NUMERAL_SIZE * Style.Setting("text", "size"))
	Widgets.TextColor(state.numeral, "black")
	PaintDisc(state)
end

local function Disc(button)
	local state = discs[button]
	if state then
		return state
	end
	Skin.Strip(button, { children = { "Display" } })
	local holder = CreateFrame("Frame", nil, button)
	holder:SetAllPoints(button)
	holder:SetFrameLevel(button:GetFrameLevel() + 1)
	local ring = holder:CreateTexture(nil, "ARTWORK", nil, -1)
	ring:SetTexture((Tokens.Texture("ringBevel")))
	ring:SetPoint("CENTER", holder, "CENTER")
	local disc = holder:CreateTexture(nil, "ARTWORK")
	disc:SetTexture((Tokens.Texture("dot")))
	disc:SetPoint("CENTER", holder, "CENTER")
	local numeral = Widgets.FontString(holder, "OVERLAY")
	numeral:SetPoint("CENTER", disc, "CENTER", 0, 0)
	state = { button = button, holder = holder, disc = disc, ring = ring, numeral = numeral, hover = false, Restyle = RestyleDisc }
	button:HookScript("OnEnter", function()
		state.hover = true
		PaintDisc(state)
	end)
	button:HookScript("OnLeave", function()
		state.hover = false
		PaintDisc(state)
	end)
	RestyleDisc(state)
	Style.Track(state)
	Widgets.Track(state)
	discs[button] = state
	return state
end

local function Blocks(module)
	local index = 0
	local block, seen = module.firstBlock, {}
	while type(block) == "table" and not seen[block] do
		seen[block] = true
		WatchTitle(block)
		PaintTitle(block)
		local button = block.poiButton
		if type(button) == "table" and type(button.HookScript) == "function" then
			index = index + 1
			local state = Disc(button)
			state.numeral:SetText(tostring(index))
			PaintDisc(state)
		end
		block = block.nextBlock
	end
end

local function Bar(holder)
	local bar = type(holder) == "table" and holder.Bar
	if type(bar) ~= "table" or done[bar] then
		return
	end
	done[bar] = true
	local keep = {}
	local fill = type(bar.GetStatusBarTexture) == "function" and bar:GetStatusBarTexture()
	if Parts.IsTexture(fill) then
		keep[fill] = true
	end
	Skin.Strip(bar, { keep = keep })
	Skin.Backdrop(bar, { shape = "tile", fill = "surface", edge = "edgeBar", shadow = false })
	Style.StatusBar(bar)
	if bar.Label then
		Style.Text(bar.Label, "caption", "textEmphasis")
	end
	if holder.Label then
		Style.Text(holder.Label, "caption")
	end
end

local function Bars(list)
	if type(list) == "table" then
		for _, holder in pairs(list) do
			Bar(holder)
		end
	end
end

local function ProgressBars(module)
	Bars(module.usedProgressBars)
end

local function TimerBars(module)
	Bars(module.usedTimerBars)
end

local function Module(module)
	if type(module) ~= "table" or done[module] then
		return
	end
	done[module] = true
	Header(module.Header)
	if type(module.GetProgressBar) == "function" then
		hooksecurefunc(module, "GetProgressBar", ProgressBars)
	end
	if type(module.GetTimerBar) == "function" then
		hooksecurefunc(module, "GetTimerBar", TimerBars)
	end
	if type(module.EndLayout) == "function" then
		hooksecurefunc(module, "EndLayout", Blocks)
	else
		Log("EndLayout is missing; POI discs and title colours follow the first layout only")
	end
	ProgressBars(module)
	TimerBars(module)
	Blocks(module)
end

local function CountModule(module)
	if not hasContents and type(module.GetContentsHeight) == "function" and PlainSize(module:GetContentsHeight()) then
		hasContents = true
	end
end

local function ShowsContent(tracker)
	if type(tracker.IsCollapsed) == "function" and tracker:IsCollapsed() == true then
		return false
	end
	if type(tracker.ForEachModule) ~= "function" then
		return true
	end
	hasContents = false
	tracker:ForEachModule(CountModule)
	return hasContents
end

local firstHeader

local function FindHeader(module)
	if not firstHeader and type(module.GetContentsHeight) == "function" and PlainSize(module:GetContentsHeight()) and type(module.Header) == "table" then
		firstHeader = module.Header
	end
end

local function LeadingHeader(tracker)
	firstHeader = nil
	if type(tracker.ForEachModule) == "function" then
		tracker:ForEachModule(FindHeader)
	end
	return firstHeader
end

local function PaintAll(collapsed)
	if allRow then
		allRow.row:SetShown(collapsed)
	end
	if allGlyph then
		allGlyph:SetShown(collapsed)
	end
	if allLine then
		allLine:SetShown(collapsed)
	end
end

local function Fit(tracker)
	local shows = ShowsContent(tracker)
	local top, bottom = tracker, tracker.NineSlice
	if shows then
		top = LeadingHeader(tracker) or tracker
	elseif type(tracker.Header) == "table" then
		bottom = tracker.Header
	end
	if type(bottom) ~= "table" then
		bottom = tracker
	end
	PaintAll(top == tracker)
	if top == fitTop and bottom == fitBottom then
		return
	end
	fitTop, fitBottom = top, bottom
	fit:ClearAllPoints()
	fit:SetPoint("TOP", top, "TOP")
	fit:SetPoint("LEFT", tracker, "LEFT", -Widgets.Snap(fit, PANEL_LEFT), 0)
	fit:SetPoint("RIGHT", tracker, "RIGHT")
	fit:SetPoint("BOTTOM", bottom, "BOTTOM")
end

local function PanelInset()
	return { left = 0, right = -Widgets.WindowInset(), top = PANEL_TOP, bottom = PANEL_BOTTOM }
end

local function PaintPanel()
	if panel then
		panel:SetShown(Skins.Setting(KEY, "panel") == true)
	end
end

local restyler = { Restyle = function()
	PaintFonts()
	PaintTitles()
end }

local function Apply()
	local tracker = _G.ObjectiveTrackerFrame
	Skin.Strip(tracker, { children = { "NineSlice" } })
	fit = CreateFrame("Frame", nil, tracker)
	allRow, allGlyph, allLine = Header(tracker.Header, L["Objectives"])
	Fit(tracker)
	if type(tracker.NineSlice) ~= "table" then
		Log("NineSlice is missing; the panel covers the whole tracker")
	end
	if type(tracker.UpdateHeaderPosition) == "function" then
		hooksecurefunc(tracker, "UpdateHeaderPosition", Fit)
	else
		Log("UpdateHeaderPosition is missing; the panel keeps its first fit through collapses and empty layouts")
	end
	panel = Skin.Backdrop(tracker, { shape = "window", fill = "surface", inset = PanelInset(), target = fit })
	PaintPanel()
	if type(tracker.ForEachModule) == "function" then
		tracker:ForEachModule(Module)
	else
		Log("ForEachModule is missing; module headers keep Blizzard's look")
	end
	if type(tracker.AddModule) == "function" then
		hooksecurefunc(tracker, "AddModule", function(_, module)
			Module(module)
		end)
	end
	WatchFont("ObjectiveTrackerLineFont", "body", LINE_DEFAULT)
	WatchFont("ObjectiveTrackerHeaderFont", "heading", LINE_DEFAULT + HEADER_EXTRA)
	PaintFonts()
	Style.Track(restyler)
end

local function OnSetting(_, field)
	if field == nil or field == "panel" then
		PaintPanel()
	end
	if field == nil or field == "font" then
		PaintFonts()
	end
	if field == nil or field == "titles" then
		PaintTitles()
	end
end

Skins.Add({
	key = KEY,
	label = L["Objective tracker"],
	help = L["Restyles the quest and objective tracker beside the minimap."],
	addon = "Blizzard_ObjectiveTracker",
	frame = "ObjectiveTrackerFrame",
	defaults = { panel = true, font = true, titles = true },
	rows = {
		{
			type = "toggle", key = "panel", label = L["Glass panel"],
			help = L["Draws a KstyleUI glass panel behind the tracker."],
		},
		{
			type = "toggle", key = "font", label = L["Skin font"],
			help = L["Uses the skin's font for tracker text. Turning it off needs a reload."],
		},
		{
			type = "toggle", key = "titles", label = L["Accent titles"],
			help = L["Colours quest titles with the accent instead of Blizzard's quest colours."],
		},
	},
	Apply = Apply,
	OnSetting = OnSetting,
})
