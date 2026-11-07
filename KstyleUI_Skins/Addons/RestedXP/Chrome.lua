-- Chrome.lua: KstyleUI's glass, buttons, scroll bars, check boxes, edit boxes and accent titles on every RestedXP Guides window, applied as RestedXP makes or first shows each one, and on RestedXP's menus only while RestedXP shows them.
local _, ns = ...

local K = KstyleUI
local Skin, Tokens, Widgets = K.Skin, K.Tokens, K.Widgets
local Style, Parts, Skins, Kit = ns.Style, ns.Parts, ns.Skins, ns.PartC

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

local WEAK = { __mode = "k" }
local titles = setmetatable({}, WEAK)
local arrows = setmetatable({}, WEAK)
local washes = setmetatable({}, WEAK)
local queued = setmetatable({}, WEAK)
local done = setmetatable({}, WEAK)
local hooks = {}
local menu = { active = false, hooked = setmetatable({}, WEAK) }
local dress = { panels = setmetatable({}, WEAK), veiled = setmetatable({}, WEAK), tinted = setmetatable({}, WEAK), hooked = setmetatable({}, WEAK) }
local state = { rxp = nil, tracked = false }

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

local function Glass(frame, opts)
	if not IsTable(frame) or type(frame.GetRegions) ~= "function" then
		return nil
	end
	opts = opts or {}
	Skin.Strip(frame, { keep = opts.keep, children = RXP_ART })
	if opts.tile then
		return Skin.Backdrop(frame, { shape = "tile", fill = "raised", shadow = false })
	end
	return Skin.Backdrop(frame, { shape = "panel", fill = "surface", shadow = true })
end

local function Tile(frame)
	return Glass(frame, { tile = true })
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
		return
	end
	for _, step in pairs(pool) do
		if IsTable(step) then
			if not Skin.IsSkinned(step, "Backdrop") then
				Glass(step)
			end
			if IsTable(step.number) and not Skin.IsSkinned(step.number, "Backdrop") then
				Tile(step.number)
			end
			for _, element in pairs(IsTable(step.elements) and step.elements or {}) do
				local check = IsTable(element) and element.button
				if IsTable(check) and not Skin.IsSkinned(check, "CheckBox") then
					Kit.CheckBox(check)
				end
			end
		end
	end
end

local function GuideWindow(rxp)
	local f = Find(rxp, "RXPFrame")
	if not f then
		return
	end
	local name = Find(f, "GuideName")
	if name then
		local keep = {}
		for _, key in ipairs({ "icon", "classIcon" }) do
			if IsTexture(name[key]) then
				keep[name[key]] = true
			end
		end
		Glass(name, { keep = keep })
		Title(name.text)
	end
	Glass(Find(f, "BottomFrame"))
	Tile(Find(f, "Footer"))
	ScrollBar(IsTable(f.ScrollFrame) and f.ScrollFrame.ScrollBar or Find(f, "ScrollFrame.ScrollBar"))
	StepFrames(f)
	Hook(rxp, "SetStep", "SetStep", function()
		StepFrames(f)
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

local function IconFrame(f, hide)
	local skinned = Skin.IsSkinned(f, "Backdrop")
	if not skinned then
		Glass(f)
	elseif not InCombatLockdown() then
		Skin.Strip(f, { children = RXP_ART })
	end
	local title = f.title
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

local function Configurator(configurator)
	local ui = configurator.ui
	if not IsTable(ui) or not IsTable(ui.frame) then
		return
	end
	if not Skin.IsSkinned(ui.frame, "Backdrop") then
		Glass(ui.frame)
	end
	Title(ui.titletext)
	for _, key in ipairs(CONFIGURATOR_BUTTONS) do
		Button(ui[key])
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
