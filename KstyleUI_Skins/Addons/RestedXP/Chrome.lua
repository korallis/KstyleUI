-- Chrome.lua: KstyleUI's one glass card, buttons, scroll bars, ring checks, edit boxes, accent titles and the Lumen cap on every RestedXP Guides window: the guide reads as one card (the cap with the guide's name and step above the active steps, the route's caption row, the folded list and the footer, with the quests docked under it when the story rail holds both), applied as RestedXP makes or first shows each window, and on RestedXP's menus only while RestedXP shows them.
local _, ns = ...

local K = KstyleUI
local Skin, Tokens, Widgets = K.Skin, K.Tokens, K.Widgets
local Style, Parts, Skins, Kit, Lumen = ns.Style, ns.Parts, ns.Skins, ns.PartC, ns.Lumen

local RestedXP = ns.RestedXP
local LogOnce = RestedXP.LogOnce

local Chrome = {}
RestedXP.Chrome = Chrome

local MODULE = "Skins"
local KEY = "restedXP"
local OWNER = "Skins.RestedXP"
local RXP_ART = { "rxpBackground", "rxpBorder", "rxpShadow" }
local MENU_LEVELS = 8
local MENU_ART = { "Backdrop", "MenuBackdrop" }
local MAX_MENU_ROWS = 64
local HIGHLIGHT_ALPHA = 0.18
local CLEANUP_BUTTON = "RXPQuestLogCleanupButton"
local IMPORT_BUTTONS = { "importButton", "importSplicedString", "purgeButton", "reloadButton", "deleteButton" }
local IMPORT_POPUPS = { "purgeConfirmation", "deleteConfirmation" }
local CONFIGURATOR_BUTTONS = { "backbutton", "resetbutton", "submitbutton" }
local RXP_MARGIN = 4
local GUTTER_GAP = "gapSmall"
local HEADER_OVERLAP = 9
local LIST_LEFT, LIST_RIGHT, RXP_LIST_BOTTOM = 5, 20, 7
local RXP_LIST_TOP = 5
local FOOTER_RISE, FOOTER_CLEAR = 6, "gapSmall"
local CAP_ROW, CAP_AIR, CAP_LEFT, CAP_RIGHT = 16, "gapSmall", RXP_MARGIN, RXP_MARGIN
local META_ROW, META_LEFT = 18, "gapSmall"
local FADE_HEIGHT = "gapXLarge"
local TITLE_AIR = "gapSmall"

local WEAK = { __mode = "k" }
local gutters = setmetatable({}, WEAK)
local fades = setmetatable({}, WEAK)
local paths = setmetatable({}, WEAK)
local hushed = setmetatable({}, WEAK)
local readable = setmetatable({}, WEAK)
local extended = setmetatable({}, WEAK)
local titles = setmetatable({}, WEAK)
local arrows = setmetatable({}, WEAK)
local washes = setmetatable({}, WEAK)
local queued = setmetatable({}, WEAK)
local done = setmetatable({}, WEAK)
local hooks = {}
local menu = { active = false, hooked = setmetatable({}, WEAK) }
local dress = { panels = setmetatable({}, WEAK), veiled = setmetatable({}, WEAK), tinted = setmetatable({}, WEAK), hooked = setmetatable({}, WEAK) }
local state = { rxp = nil, tracked = false, guide = nil }

local function Active()
	return K.Modules.IsRunning(MODULE) and Skins.IsOn(KEY)
end

local function Run(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		LogOnce("fail " .. name, name .. " could not be restyled (" .. tostring(err) .. "); it keeps RestedXP's look")
	end
end

local function IsTable(value)
	return type(value) == "table"
end

local function Plain(value)
	return type(value) == "number" and not Widgets.IsSecret(value)
end

local function IsTexture(region)
	return IsTable(region) and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture"
end

local function Find(root, path)
	local node, walked = root, nil
	for part in path:gmatch("[^%.]+") do
		walked = walked and (walked .. "." .. part) or part
		node = IsTable(node) and node[part] or nil
		if node == nil then
			LogOnce("missing " .. walked, walked .. " is missing in this RestedXP; skipped")
			return nil
		end
	end
	return node
end

local function Hook(owner, method, name, fn)
	if hooks[name] then
		return true
	end
	if not IsTable(owner) or type(owner[method]) ~= "function" then
		LogOnce("hook " .. name, name .. " is missing in this RestedXP; what it makes keeps RestedXP's look")
		return false
	end
	hooks[name] = true
	hooksecurefunc(owner, method, function(...)
		if Active() then
			Run(name, fn, ...)
		end
	end)
	return true
end

local function Profile(field)
	local rxp = state.rxp
	local profile = rxp and rxp.settings and rxp.settings.profile
	return IsTable(profile) and profile[field] or nil
end

local function Panel(frame)
	local parts = Skin.Parts(frame)
	return parts and parts.backdrop or nil
end

local function Reach(frame)
	local reach = Widgets.Inset(frame, Tokens.Size("chamferWindow")) - RXP_MARGIN
	return { left = -reach, right = -reach }
end

local function Glass(frame, opts)
	if not IsTable(frame) or type(frame.GetRegions) ~= "function" then
		return nil
	end
	opts = opts or {}
	Skin.Strip(frame, { keep = opts.keep, children = RXP_ART })
	local inset = opts.reach and Reach(frame) or nil
	if inset and opts.air then
		inset.bottom = Tokens.Size(opts.air)
	end
	if opts.tile then
		return Skin.Backdrop(frame, { shape = "tile", fill = "surface", shadow = false, inset = inset })
	end
	return Skin.Backdrop(frame, { shape = "window", fill = "surface", shadow = true, inset = inset, target = opts.target })
end

function Chrome.Reach(frame)
	return Widgets.Inset(frame, Tokens.Size("chamferWindow")) - RXP_MARGIN
end

local function Tile(frame, reach)
	return Glass(frame, { tile = true, reach = reach })
end

local function LayoutGutter(gutter)
	local line, list, bar = gutter.line, gutter.list, gutter.bar
	local gap = Widgets.Snap(line, Tokens.Size(GUTTER_GAP) / 2)
	line:ClearAllPoints()
	line:SetPoint("TOP", list, "TOP")
	line:SetPoint("BOTTOM", list, "BOTTOM")
	line:SetPoint("RIGHT", bar, "LEFT", -gap, 0)
	line:SetWidth(Widgets.Border(line))
	Widgets.Tint(line, "edgeFaint")
end

local function Gutter(glass, list, bar)
	if not glass or gutters[list] or not IsTable(bar) or type(bar.GetObjectType) ~= "function" then
		return
	end
	local line = glass:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(Tokens.Color("white"))
	local gutter = { line = line, list = list, bar = bar, Restyle = LayoutGutter }
	LayoutGutter(gutter)
	Widgets.Track(gutter)
	gutters[list] = line
end

function Chrome.Gutter(list)
	return gutters[list]
end

local function PaintFade(fade)
	local texture = fade.texture
	local r, g, b, a = Widgets.Rgba("surface")
	if type(texture.SetGradient) == "function" and type(CreateColor) == "function" then
		texture:SetColorTexture(Tokens.Color("white"))
		texture:SetGradient("VERTICAL", CreateColor(r, g, b, a), CreateColor(r, g, b, 0))
	else
		texture:SetColorTexture(r, g, b, a / 2)
	end
	texture:SetHeight(Widgets.Snap(texture, Tokens.Size(FADE_HEIGHT)))
end

local function PlaceFade(fade)
	local bar = fade.bar
	local value = bar:GetValue()
	local _, high = bar:GetMinMaxValues()
	if not (Plain(value) and Plain(high)) then
		return
	end
	fade.texture:SetShown(value < high)
end

local function Fade(list, scroll, bar)
	if fades[list] or not IsTable(scroll) or not IsTable(bar) or type(bar.GetMinMaxValues) ~= "function" then
		return
	end
	local holder = CreateFrame("Frame", nil, list)
	holder:SetAllPoints(scroll)
	holder:SetFrameLevel(scroll:GetFrameLevel() + 2)
	local texture = holder:CreateTexture(nil, "OVERLAY")
	texture:SetPoint("BOTTOMLEFT", scroll, "BOTTOMLEFT")
	texture:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT")
	local fade = { texture = texture, holder = holder, bar = bar, Restyle = PaintFade }
	PaintFade(fade)
	PlaceFade(fade)
	Hook(bar, "SetValue", "RXPFrame.ScrollBar.SetValue.fade", function()
		PlaceFade(fade)
	end)
	Hook(bar, "SetMinMaxValues", "RXPFrame.ScrollBar.SetMinMaxValues.fade", function()
		PlaceFade(fade)
	end)
	Widgets.Track(fade)
	fades[list] = texture
end

function Chrome.Fade(list)
	return fades[list]
end

local function PaintReadable(text, entry)
	if entry.busy then
		return
	end
	entry.busy = true
	local _, minimum = Style.Font(entry.role)
	pcall(Style.ApplyFont, text, entry.role, math.max(entry.size, minimum))
	entry.busy = false
end

local function Readable(text, role)
	if not IsTable(text) or type(text.GetFont) ~= "function" or readable[text] then
		return false
	end
	local _, size = text:GetFont()
	local entry = { role = role, size = type(size) == "number" and not Widgets.IsSecret(size) and size or 0 }
	readable[text] = entry
	hooksecurefunc(text, "SetFont", function(_, _, requested)
		if Active() and not entry.busy and type(requested) == "number" and not Widgets.IsSecret(requested) then
			entry.size = requested
			PaintReadable(text, entry)
		end
	end)
	PaintReadable(text, entry)
	return true
end

local function Measure(f, steps, rows)
	local current, list = f.CurrentStepFrame, f.BottomFrame
	if steps and IsTable(current) and type(current.UpdateText) == "function" then
		Run("guide steps measure", current.UpdateText)
	end
	if rows and IsTable(list) and type(list.UpdateFrame) == "function" then
		Run("guide list measure", list.UpdateFrame)
	end
end

local function GuideRows(f)
	local child = f.ScrollChild
	local changed = false
	for _, row in pairs(IsTable(child) and IsTable(child.framePool) and child.framePool or {}) do
		if IsTable(row) then
			changed = Readable(row.text, "body") or changed
			if IsTable(row.number) then
				Readable(row.number.text, "caption")
			end
		end
	end
	if changed then
		Measure(f, false, true)
	end
end

local function PaintTitle(text)
	text:SetTextColor(Style.Accent())
end

local function Title(text)
	if IsTable(text) and type(text.SetTextColor) == "function" then
		titles[text] = true
		PaintTitle(text)
	end
end

local function Caption(text, colorName)
	if IsTable(text) and type(text.SetFont) == "function" then
		Style.Text(text, "caption")
		Widgets.TextColor(text, colorName or "text")
	end
end

local function Rehush(text)
	local entry = hushed[text]
	if entry and not entry.busy then
		entry.busy = true
		text:SetAlpha(0)
		entry.busy = false
	end
end

local function HushText(text)
	if hushed[text] then
		return
	end
	hushed[text] = { busy = false }
	text:SetAlpha(0)
	hooksecurefunc(text, "SetAlpha", Rehush)
end

local function PlainText(value)
	if Widgets.IsSecret(value) or type(value) ~= "string" then
		return ""
	end
	return value
end

local function Trail(f)
	local steps = IsTable(f) and f.CurrentStepFrame
	local pool = IsTable(steps) and steps.framePool
	if not IsTable(pool) or not steps:IsShown() then
		return ""
	end
	for _, step in ipairs(pool) do
		local plate = IsTable(step) and step.number
		if IsTable(plate) and IsTable(plate.text) and step:IsShown() and not Widgets.IsSecret(step:GetAlpha()) and step:GetAlpha() > 0 then
			local value = PlainText(plate.text:GetText())
			if value ~= "" then
				return value
			end
		end
	end
	return ""
end

local function StepsAbove(f)
	local steps = IsTable(f) and f.CurrentStepFrame
	return IsTable(steps) and steps:IsShown() and steps.anchor ~= "BOTTOM" and steps or nil
end

local function StepsBelow(f)
	local steps = IsTable(f) and f.CurrentStepFrame
	return IsTable(steps) and steps:IsShown() and steps.anchor == "BOTTOM" and steps or nil
end

local function PlaceCard(path)
	local f, card = path.frame, path.card
	local bottom = path.dock or StepsBelow(f) or f
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", path.holder, "TOPLEFT")
	card:SetPoint("TOPRIGHT", path.holder, "TOPRIGHT")
	card:SetPoint("BOTTOM", bottom, "BOTTOM", 0, path.dock and -Widgets.Snap(card, path.dockBottom or 0) or 0)
end

local function PlaceHead(path)
	local f, holder, header = path.frame, path.holder, path.header
	local anchor = StepsAbove(f) or header
	holder:ClearAllPoints()
	holder:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 0)
	holder:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 0)
	holder:SetHeight(Widgets.Snap(holder, path.capHeight))
	PlaceCard(path)
	if path.OnHead then
		path.OnHead(path)
	end
end

local function FitHead(path)
	local cap = path.cap
	cap:SetTitle(path.titleValue)
	cap:SetTrail(Trail(path.frame))
	local meta, value = path.meta, path.metaValue
	meta:SetText(value)
	meta:SetShown(value ~= "")
	path.capHeight = CAP_ROW + 2 * Tokens.Size(CAP_AIR)
	path.height = META_ROW
	PlaceHead(path)
end

local function SetHeading(path, value)
	value = PlainText(value)
	local first, rest = value:match("^([^\n]*)\n?(.*)$")
	path.titleValue = (first or value):gsub("^%s+", ""):gsub("%s+$", "")
	path.metaValue = (rest or ""):gsub("%s*\n%s*", " "):gsub("^%s+", ""):gsub("%s+$", "")
	FitHead(path)
end

local function RestylePath(path)
	local cap, meta, header = path.cap, path.meta, path.header
	local air = Widgets.Snap(cap.row, Tokens.Size(CAP_AIR))
	cap.row:ClearAllPoints()
	cap.row:SetPoint("TOPLEFT", path.holder, "TOPLEFT", 0, -air)
	cap.row:SetPoint("TOPRIGHT", path.holder, "TOPRIGHT", 0, -air)
	cap.row:SetHeight(Widgets.Snap(cap.row, CAP_ROW))
	header:SetHeight(Widgets.Snap(header, META_ROW))
	Style.Text(meta, "caption", "text")
	meta:ClearAllPoints()
	meta:SetPoint("LEFT", header, "LEFT", Widgets.Snap(meta, Tokens.Size(META_LEFT)), 0)
	meta:SetPoint("RIGHT", header, "RIGHT", -Widgets.Snap(meta, Tokens.Size(META_LEFT)), 0)
	meta:SetJustifyH("LEFT")
	meta:SetWordWrap(false)
	FitHead(path)
end

local function Path(f)
	local header = IsTable(f) and f.GuideName
	local text = IsTable(header) and header.text
	if not IsTable(text) or type(text.GetText) ~= "function" or type(text.SetAlpha) ~= "function" then
		return nil
	end
	local path = paths[header]
	if path then
		return path
	end
	HushText(text)
	local holder = CreateFrame("Frame", nil, f)
	holder:SetFrameLevel(header:GetFrameLevel() + 1)
	local card = CreateFrame("Frame", nil, f)
	local cap = Lumen.SectionCap(holder, { left = CAP_LEFT, right = CAP_RIGHT })
	local meta = Widgets.FontString(header, "OVERLAY")
	path = { frame = f, header = header, holder = holder, card = card, cap = cap, meta = meta, titleValue = "", metaValue = "", capHeight = CAP_ROW, height = META_ROW, headerHeight = header:GetHeight(), Restyle = RestylePath }
	RestylePath(path)
	SetHeading(path, text:GetText())
	hooksecurefunc(text, "SetText", function(_, value)
		SetHeading(path, value)
	end)
	Style.Track(path)
	Widgets.Track(path)
	paths[header] = path
	return path
end

function Chrome.Path(f)
	return IsTable(f) and paths[f.GuideName] or nil
end

function Chrome.Card(f)
	local path = Chrome.Path(f)
	return path and path.card or nil
end

function Chrome.Dock(f, target, bottom)
	local path = Chrome.Path(f)
	if not path then
		return false
	end
	path.dock = IsTable(target) and target or nil
	path.dockBottom = bottom
	PlaceCard(path)
	return path.dock ~= nil
end

function Chrome.Refit(f)
	local path = Chrome.Path(f)
	if path then
		FitHead(path)
	end
end

local function Button(button)
	if IsTable(button) and type(button.GetRegions) == "function" and not Skin.IsSkinned(button, "Button") then
		Skin.Strip(button, { children = RXP_ART })
		Kit.Button(button)
	end
end

local function ScrollBar(bar)
	if IsTable(bar) and type(bar.GetRegions) == "function" and not Skin.IsSkinned(bar, "ScrollBar") then
		Kit.ScrollBar(bar)
	end
end

local function CloseButton(button)
	if IsTable(button) and type(button.GetRegions) == "function" and not Skin.IsSkinned(button, "CloseButton") then
		Skin.CloseButton(button)
	end
end

local function PaintArrow(arrow)
	local texture = arrow.texture
	if IsTexture(texture) then
		texture:SetDesaturated(true)
		texture:SetVertexColor(Style.Accent())
	end
end

local function Restyle()
	if next(readable) then
		for text, entry in pairs(readable) do
			PaintReadable(text, entry)
		end
		if state.guide then
			Measure(state.guide, true, true)
		end
	end
	for text in pairs(titles) do
		PaintTitle(text)
	end
	for _, list in pairs(dress.tinted) do
		for text in pairs(list) do
			PaintTitle(text)
		end
	end
	for arrow in pairs(arrows) do
		PaintArrow(arrow)
	end
	for wash in pairs(washes) do
		Style.TintAccent(wash, HIGHLIGHT_ALPHA)
	end
end

local restyler = { Restyle = Restyle }

local function StepFrames(f)
	local pool = IsTable(f.CurrentStepFrame) and f.CurrentStepFrame.framePool
	if not IsTable(pool) then
		return false
	end
	local changed = false
	for _, step in pairs(pool) do
		if IsTable(step) then
			if not done[step] then
				done[step] = true
				Skin.Strip(step, { children = RXP_ART })
			end
			local plate = step.number
			if IsTable(plate) and not done[plate] then
				done[plate] = true
				Skin.Strip(plate, { children = RXP_ART })
				if IsTable(plate.text) then
					HushText(plate.text)
				end
			end
			for _, element in pairs(IsTable(step.elements) and step.elements or {}) do
				if IsTable(element) then
					changed = Readable(element.text, "body") or changed
				end
				local check = IsTable(element) and element.button
				if IsTable(check) and type(check.GetChecked) == "function" and not Lumen.RingOf(check) then
					Lumen.RingCheck(check)
				end
			end
		end
	end
	return changed
end

local function NewSteps(f)
	if StepFrames(f) then
		Measure(f, true, false)
	end
	Chrome.Refit(f)
end

local function PlaceGuideScroll(f)
	local scroll, list = f.ScrollFrame, f.BottomFrame
	if not IsTable(scroll) or not IsTable(list) or type(scroll.SetPoint) ~= "function" or queued[scroll] then
		return
	end
	queued[scroll] = true
	K.Combat.Queue(function()
		queued[scroll] = nil
		if not Active() then
			return
		end
		local top = HEADER_OVERLAP + Widgets.Inset(scroll, Tokens.Size("chamferWindow"))
		scroll:ClearAllPoints()
		scroll:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_LEFT, -Widgets.Snap(scroll, top))
		scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -LIST_RIGHT, Widgets.Snap(scroll, FOOTER_RISE + Tokens.Size(FOOTER_CLEAR)))
	end)
end

local function ExtendScroll(f)
	local scroll, list = f.ScrollFrame, f.BottomFrame
	local bar = IsTable(scroll) and scroll.ScrollBar
	if not IsTable(bar) or type(bar.GetMinMaxValues) ~= "function" or not IsTable(list) then
		return
	end
	local low, high = bar:GetMinMaxValues()
	local listHeight, viewHeight = list:GetHeight(), scroll:GetHeight()
	if not (Plain(low) and Plain(high) and Plain(listHeight) and Plain(viewHeight)) or high == extended[bar] then
		return
	end
	local taken = listHeight - RXP_LIST_TOP - RXP_LIST_BOTTOM - viewHeight
	if taken <= 0 then
		return
	end
	extended[bar] = high + taken
	bar:SetMinMaxValues(low, high + taken)
	local value, down = bar:GetValue(), bar.ScrollDownButton
	if Plain(value) and value < high + taken and IsTable(down) and type(down.Enable) == "function" then
		down:Enable()
	end
end

local function GuideWindow(rxp)
	local f = Find(rxp, "RXPFrame")
	if not f then
		return
	end
	local name = Find(f, "GuideName")
	local path = name and Path(f)
	if name then
		Skin.Strip(name, { children = RXP_ART })
	end
	local glass = path and Glass(f, { reach = true, target = path.card })
	if path then
		path.OnHead = function()
			if state.guide then
				PlaceGuideScroll(state.guide)
			end
			if Chrome.OnHead then
				Chrome.OnHead(state.guide)
			end
		end
	end
	local list = Find(f, "BottomFrame")
	if list then
		Skin.Strip(list, { children = RXP_ART })
	end
	local footer = Find(f, "Footer")
	if footer then
		Skin.Strip(footer, { children = RXP_ART })
		Caption(footer.text)
	end
	local bar = IsTable(f.ScrollFrame) and f.ScrollFrame.ScrollBar or Find(f, "ScrollFrame.ScrollBar")
	ScrollBar(bar)
	if list and glass then
		Gutter(glass, list, bar)
		Fade(list, f.ScrollFrame, bar)
	end
	state.guide = f
	PlaceGuideScroll(f)
	Hook(f, "UpdateVisuals", "RXPFrame.UpdateVisuals", function()
		PlaceGuideScroll(f)
		Chrome.Refit(f)
	end)
	if IsTable(f.ScrollFrame) and IsTable(f.ScrollFrame.ScrollBar) then
		Hook(f.ScrollFrame.ScrollBar, "SetValue", "RXPFrame.ScrollBar.SetValue", function()
			ExtendScroll(f)
		end)
	end
	NewSteps(f)
	GuideRows(f)
	Hook(rxp, "SetStep", "SetStep", function()
		NewSteps(f)
		GuideRows(f)
	end)
	Hook(rxp, "LoadGuide", "LoadGuide", function()
		GuideRows(f)
	end)
end

local function GuideWindowV2(rxp)
	local window = Find(rxp, "v2.state.guideWindow")
	if not window then
		return
	end
	Glass(window.upperFrame)
	Glass(window.guideStepsFrame)
	Parts.Hush(window.banner)
	CloseButton(window.closebutton)
	local scroll = IsTable(window.guideSteps) and window.guideSteps.scroll
	ScrollBar(IsTable(scroll) and scroll.scrollbar or nil)
	Title(window.title)
	Hook(window, "UpdateSubTheme", "guideWindow.UpdateSubTheme", function()
		Title(window.title)
	end)
end

local function MenuPrefix()
	return rawget(_G, "EasyMenu") ~= nil and "DropDownList" or "L_DropDownList"
end

local function RestyleDressPanel(panel)
	panel:SetFrameLevel(math.max(0, panel:GetParent():GetFrameLevel() - 1))
end

local function DressPanel(frame)
	local panel = dress.panels[frame]
	if not panel then
		panel = CreateFrame("Frame", nil, frame)
		panel:SetAllPoints(frame)
		panel.chrome = Widgets.Chrome(panel, { shape = "panel", fill = "surface" })
		panel.Restyle = RestyleDressPanel
		RestyleDressPanel(panel)
		dress.panels[frame] = panel
	end
	panel:Show()
	return panel
end

function Chrome.DressPanel(frame)
	return dress.panels[frame]
end

Chrome.MenuPanel = Chrome.DressPanel

local function Veil(frame, region)
	if not IsTable(region) or type(region.SetAlpha) ~= "function" then
		return
	end
	local list = dress.veiled[frame] or {}
	dress.veiled[frame] = list
	if list[region] == nil then
		list[region] = region:GetAlpha()
	end
	region:SetAlpha(0)
end

local function Tint(frame, text)
	if not IsTable(text) or type(text.GetTextColor) ~= "function" then
		return
	end
	local list = dress.tinted[frame] or {}
	dress.tinted[frame] = list
	if list[text] == nil then
		list[text] = { text:GetTextColor() }
	end
	PaintTitle(text)
end

local function Undress(frame)
	for region, alpha in pairs(dress.veiled[frame] or {}) do
		region:SetAlpha(alpha)
	end
	dress.veiled[frame] = nil
	for text, color in pairs(dress.tinted[frame] or {}) do
		text:SetTextColor(unpack(color))
	end
	dress.tinted[frame] = nil
	local panel = dress.panels[frame]
	if panel then
		panel:Hide()
	end
end

local function UndressOnHide(frame)
	if not dress.hooked[frame] then
		dress.hooked[frame] = true
		frame:HookScript("OnHide", Undress)
	end
end

local function DressMenu(list)
	local name = list:GetName()
	if type(name) == "string" then
		for _, suffix in ipairs(MENU_ART) do
			Veil(list, _G[name .. suffix])
		end
	end
	for _, key in ipairs(RXP_ART) do
		Veil(list, list[key])
	end
	DressPanel(list)
	local path = Style.Font("body")
	for i = 1, MAX_MENU_ROWS do
		local text = type(name) == "string" and _G[name .. "Button" .. i .. "NormalText"]
		if not IsTable(text) then
			break
		end
		local _, size, flags = text:GetFont()
		text:SetFont(path, size or Tokens.Size("body"), flags)
	end
end

local function MenuList(level)
	return rawget(_G, MenuPrefix() .. level)
end

local function HookMenuList(list, level)
	if menu.hooked[list] then
		return
	end
	menu.hooked[list] = true
	UndressOnHide(list)
	if level == 1 then
		list:HookScript("OnHide", function()
			menu.active = false
		end)
	else
		list:HookScript("OnShow", function(self)
			if menu.active then
				Run("menu", DressMenu, self)
			end
		end)
	end
end

local function Menus(rxp)
	Hook(rxp, "ShowMenu", "ShowMenu", function()
		for level = 1, MENU_LEVELS do
			local list = MenuList(level)
			if IsTable(list) and type(list.HookScript) == "function" then
				HookMenuList(list, level)
			end
		end
		local first = MenuList(1)
		if not IsTable(first) then
			LogOnce("menu", MenuPrefix() .. "1 is missing; RestedXP's menus keep their look")
			return
		end
		menu.active = first:IsShown() == true
		if menu.active then
			DressMenu(first)
		end
	end)
end

local function Arrow(rxp)
	local arrow = Find(rxp, "arrowFrame")
	if not arrow then
		return
	end
	arrows[arrow] = true
	PaintArrow(arrow)
	Hook(arrow, "UpdateVisuals", "arrowFrame.UpdateVisuals", function()
		PaintArrow(arrow)
	end)
	Hook(rxp, "SetupArrow", "SetupArrow", function()
		PaintArrow(arrow)
	end)
end

local function Highlight(button)
	for _, region in ipairs({ button:GetRegions() }) do
		if IsTexture(region) and region:GetDrawLayer() == "HIGHLIGHT" then
			region:SetColorTexture(Tokens.Color("white"))
			region:SetBlendMode("BLEND")
			Style.TintAccent(region, HIGHLIGHT_ALPHA)
			washes[region] = true
		end
	end
end

local function IconButton(button, crop)
	if not IsTable(button) or type(button.GetRegions) ~= "function" or done[button] then
		return
	end
	if InCombatLockdown() then
		if not queued[button] then
			queued[button] = true
			K.Combat.Queue(function()
				queued[button] = nil
				Run("icon button", IconButton, button, crop)
			end)
		end
		return
	end
	done[button] = true
	if crop then
		Kit.Crop(button.icon)
	end
	Parts.Rim(button, { outset = Tokens.Size("gapTiny") })
	Highlight(button)
end

local function IconButtons(list, crop)
	for _, button in pairs(IsTable(list) and list or {}) do
		IconButton(button, crop)
	end
end

local function TitleRise(f, title)
	local rise = 0
	if IsTable(title) and type(title.GetNumPoints) == "function" then
		for i = 1, title:GetNumPoints() do
			local _, relative, relativePoint, _, y = title:GetPoint(i)
			if (relative == f or relative == nil) and type(relativePoint) == "string" and relativePoint:find("TOP", 1, true) and type(y) == "number" and not Widgets.IsSecret(y) then
				rise = math.max(rise, y)
			end
		end
	end
	return rise
end

local function IconFrame(f, hide)
	local skinned = Skin.IsSkinned(f, "Backdrop")
	local title = f.title
	if not skinned then
		Glass(f)
	elseif not InCombatLockdown() then
		Skin.Strip(f, { children = RXP_ART })
	end
	local glass = Panel(f)
	local rise = TitleRise(f, title)
	local top = rise > 0 and -(rise + Tokens.Size(TITLE_AIR)) or nil
	if glass and (type(glass.inset) == "table" and glass.inset.top or nil) ~= top then
		glass.inset = top and { top = top } or nil
		glass:Restyle()
	end
	if IsTable(title) then
		if not Skin.IsSkinned(title, "Backdrop") then
			Tile(title)
		elseif not InCombatLockdown() then
			Skin.Strip(title, { children = RXP_ART })
		end
		Title(title.text)
	end
	local panel = Panel(f)
	if panel then
		panel:SetShown(not Profile(hide))
	end
end

local function Items(rxp)
	local f = Find(rxp, "activeItemFrame")
	if not f then
		return
	end
	local function Refresh()
		IconFrame(f, "activeItemHideBG")
		IconButtons(f.buttonList, true)
	end
	Refresh()
	Hook(f, "UpdateVisuals", "activeItemFrame.UpdateVisuals", Refresh)
	Hook(rxp, "UpdateItemFrame", "UpdateItemFrame", Refresh)
end

local function Targets(rxp)
	local targeting = Find(rxp, "targeting")
	local f = targeting and Find(targeting, "activeTargetFrame")
	if not f then
		return
	end
	local function Refresh()
		IconFrame(f, "hideActiveTargetsBackground")
		IconButtons(f.enemyTargetButtons, false)
		IconButtons(f.friendlyTargetButtons, false)
	end
	Refresh()
	Hook(f, "UpdateVisuals", "activeTargetFrame.UpdateVisuals", Refresh)
	Hook(targeting, "UpdateTargetFrame", "targeting.UpdateTargetFrame", Refresh)
	Hook(targeting, "RenderTargetFrameBackground", "targeting.RenderTargetFrameBackground", Refresh)
end

local function Report(tracker)
	local ui = IsTable(tracker.ui) and tracker.ui.CharacterFrame
	if not IsTable(ui) or not IsTable(ui.frame) then
		LogOnce("report", "RestedXP made no leveling report (its leveling tracker may be off); skipped")
		return
	end
	local frame = ui.frame
	Glass(frame)
	if IsTable(ui.titletext) then
		Style.Text(ui.titletext, "heading")
		Title(ui.titletext)
	end
	local status = IsTable(ui.statustext) and ui.statustext:GetParent()
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.obj == ui and child ~= status and child:GetObjectType() == "Button" then
			Button(child)
		end
	end
	ScrollBar(IsTable(ui.scrollContainer) and ui.scrollContainer.scrollbar or nil)
	Button(IsTable(ui.levelButton) and ui.levelButton.frame or nil)
end

local function Splits(tracker)
	local splits = tracker.levelSplits
	if not IsTable(splits) then
		return
	end
	IconFrame(splits, "hideSplitsBackground")
end

local function Tracker(rxp)
	local tracker = Find(rxp, "tracker")
	if not tracker then
		return
	end
	Report(tracker)
	Splits(tracker)
	local function Refresh()
		Splits(tracker)
	end
	Hook(tracker, "CreateLevelSplits", "tracker.CreateLevelSplits", Refresh)
	Hook(tracker, "RenderSplitsBackground", "tracker.RenderSplitsBackground", Refresh)
end

local function Label(text, role, colorName)
	if IsTable(text) and type(text.SetFont) == "function" then
		Style.Text(text, role, colorName)
	end
end

local function KitButton(button)
	Button(button)
	if IsTable(button) and type(button.GetFontString) == "function" then
		Label(button:GetFontString(), "body", "textEmphasis")
	end
	local wash = IsTable(button) and button.configuratorBackground
	if IsTexture(wash) then
		HushText(wash)
	end
end

local function Configurator(configurator)
	local ui = configurator.ui
	if not IsTable(ui) or not IsTable(ui.frame) then
		return
	end
	if not Skin.IsSkinned(ui.frame, "Backdrop") then
		Glass(ui.frame)
	end
	Label(ui.titletext, "title", "textEmphasis")
	for _, key in ipairs(CONFIGURATOR_BUTTONS) do
		KitButton(ui[key])
	end
	local pane = IsTable(ui.scrollContainer) and ui.scrollContainer.frame
	if IsTable(pane) and type(pane.GetRegions) == "function" and not Skin.IsSkinned(pane, "Backdrop") then
		Skin.Backdrop(pane, { shape = "tile", fill = "surface", shadow = false })
	end
	ScrollBar(IsTable(ui.scrollContainer) and ui.scrollContainer.scrollbar or nil)
end

local function Importer(importer)
	local widgets = importer.widgets
	local window = IsTable(widgets) and widgets.import
	if not IsTable(window) or not IsTable(window.frame) then
		return
	end
	if not Skin.IsSkinned(window.frame, "Backdrop") then
		Glass(window.frame)
	end
	CloseButton(window.closebutton)
	Title(window.title)
	for _, key in ipairs(IMPORT_BUTTONS) do
		local widget = widgets[key]
		Button(IsTable(widget) and widget.frame or nil)
	end
	local box = widgets.importBox
	if IsTable(box) then
		if IsTable(box.background) then
			Skin.Strip(box.background, { children = RXP_ART })
		end
		if IsTable(box.editBox) and not Skin.IsSkinned(box.editBox, "EditBox") then
			Kit.EditBox(box.editBox)
		end
	end
	for _, key in ipairs(IMPORT_POPUPS) do
		local popup = widgets[key]
		if IsTable(popup) and IsTable(popup.frame) then
			if not Skin.IsSkinned(popup.frame, "Backdrop") then
				Glass(popup.frame)
			end
			Title(popup.title)
			for _, button in pairs(IsTable(popup.buttons) and popup.buttons or {}) do
				Button(button)
			end
		end
	end
end

local function V2Windows(rxp)
	local configurator = Find(rxp, "ui.v2.configurator")
	if configurator then
		Configurator(configurator)
		Hook(configurator, "CreateGuideConfigurator", "configurator.CreateGuideConfigurator", function()
			Configurator(configurator)
		end)
		Hook(configurator, "UpdateTheme", "configurator.UpdateTheme", function()
			Configurator(configurator)
		end)
	end
	local importer = Find(rxp, "guideImporter")
	local v2 = Find(rxp, "ui.v2")
	if importer and v2 then
		Importer(importer)
		Hook(v2, "CreateGuideImporter", "ui.v2.CreateGuideImporter", function()
			Importer(importer)
		end)
	end
end

local function DressDialog(global)
	local frame = rawget(_G, global)
	if not IsTable(frame) or type(frame.GetRegions) ~= "function" then
		LogOnce("dialog " .. global, global .. " is missing in this RestedXP; the dialog keeps RestedXP's look")
		return
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if IsTexture(region) then
			Veil(frame, region)
		end
	end
	if IsTable(frame.obj) then
		Tint(frame, frame.obj.titletext)
	end
	DressPanel(frame)
	UndressOnHide(frame)
end

local function Dialogs(rxp)
	local comms = Find(rxp, "comms")
	if not comms then
		return
	end
	Hook(comms, "OpenBugReport", "comms.OpenBugReport", function()
		DressDialog("RESTEDXP_BUG_REPORT_WINDOW")
	end)
	Hook(comms, "OpenBrandedExport", "comms.OpenBrandedExport", function()
		DressDialog("RESTEDXP_BRANDED_EXPORT")
	end)
end

local function Cleanup()
	local button = rawget(_G, CLEANUP_BUTTON)
	if not IsTable(button) then
		return false
	end
	Button(button)
	return true
end

local function WatchCleanup()
	if Cleanup() then
		return
	end
	local function Try()
		C_Timer.After(0, function()
			if Active() and Cleanup() then
				K.Events.Unregister(OWNER, "PLAYER_ENTERING_WORLD")
				K.Events.Unregister(OWNER, "ADDON_LOADED")
			end
		end)
	end
	K.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", Try)
	K.Events.Register(OWNER, "ADDON_LOADED", Try)
end

local SECTIONS = {
	{ "guide window", GuideWindow },
	{ "menus", Menus },
	{ "arrow", Arrow },
	{ "active items", Items },
	{ "active targets", Targets },
	{ "leveling tracker", Tracker },
	{ "guide configurator and importer", V2Windows },
	{ "feedback and export dialogs", Dialogs },
	{ "quest log button", WatchCleanup },
}

function Chrome.Start(rxp)
	state.rxp = rxp
	if not state.tracked then
		state.tracked = true
		Style.Track(restyler)
	end
	for _, section in ipairs(SECTIONS) do
		Run(section[1], section[2], rxp)
	end
	if IsTable(rxp.v2) and type(rxp.v2.IsGuideWindowEnabled) == "function" then
		local ok, on = pcall(rxp.v2.IsGuideWindowEnabled, rxp.v2)
		if ok and on == true then
			Run("v2 guide window", GuideWindowV2, rxp)
		end
	end
end
