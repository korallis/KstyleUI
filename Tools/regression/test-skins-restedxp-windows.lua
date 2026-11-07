-- test-skins-restedxp-windows.lua: the RestedXP skin puts KstyleUI's chrome on every RestedXP window as RestedXP makes it, through KstyleUI's skin kit, without writing onto RestedXP's frames.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local W = S.W

-- Methods KstyleUI may replace on RestedXP's objects with hooksecurefunc.
local HOOKED = { SetAlpha = true, SetChecked = true, UpdateVisuals = true }

local function Boot(opts)
	opts = opts or {}
	local rxp
	local env, K, ns = S.New({
		setup = function(env)
			rxp = Fake.Install(env, opts)
		end,
	})
	if opts.combat then
		env.SetCombat(true)
	end
	K.Modules.Enable("Skins")
	env.RunTimers()
	return env, K, ns, rxp
end

local function Alpha(region)
	return region:GetAlpha()
end

local function Hushed(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:GetObjectType() == "Texture" and region:GetAlpha() ~= 0 then
			return false
		end
	end
	return true
end

local function Glass(K, frame)
	local parts = K.Skin.Parts(frame)
	return parts ~= nil and parts.backdrop ~= nil and parts.backdrop:IsShown()
end

local function Accented(ns, text)
	local r, g, b = text:GetTextColor()
	local ar, ag, ab = ns.Style.Accent()
	return W.Near(r, ar) and W.Near(g, ag) and W.Near(b, ab)
end

local function Colored(text, r, g, b)
	local cr, cg, cb = text:GetTextColor()
	return W.Near(cr, r) and W.Near(cg, g) and W.Near(cb, b)
end

local function Clean(env, rxp)
	rxp.fake.check(HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
	local failed = S.Logged(env, "could not be restyled")
	assert(not failed, tostring(failed))
end

-- The v1 guide window, its active steps and its guide menu ---------------------------------------------------

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	assert(ns.Skins.IsApplied("restedXP"))
	assert(Glass(K, f.GuideName) and Glass(K, f.BottomFrame), "the header and the step list sit on KstyleUI glass")
	assert(Hushed(f.BottomFrame), "RestedXP's backdrop under the list goes")
	assert(Alpha(f.GuideName.bg) == 0 and Alpha(f.GuideName._pieces[1]) == 0, "the header's banner and backdrop go")
	assert(Alpha(f.GuideName.icon) == 1 and Alpha(f.GuideName.classIcon) == 1, "the logo and class icon stay")
	assert(select(2, f.GuideName.text:GetFont()) == select(2, K.Tokens.Font("heading")), "the guide's title is a kit heading")
	assert(Colored(f.GuideName.text, K.Tokens.Color("textEmphasis")), "in the emphasised text colour, as every window title")
	assert(K.Skin.IsSkinned(f.Footer, "Backdrop") and Alpha(f.Footer.bg) == 0, "the footer is a KstyleUI tile")
	assert(K.Skin.Parts(f.Footer).backdrop.chrome.fillName == "surface", "on the same glass surface as the windows")
	assert(select(2, f.Footer.text:GetFont()) == select(2, K.Tokens.Font("caption")) and Colored(f.Footer.text, K.Tokens.Color("text")), "the footer line is a caption in the body grey")
	assert(K.Skin.IsSkinned(f.ScrollFrame.ScrollBar, "ScrollBar"), "the step list's scroll bar is KstyleUI's")
	f:UpdateVisuals()
	assert(Hushed(f.BottomFrame) and Alpha(f.GuideName._pieces[1]) == 0, "RestedXP's redraw keeps the glass")
	local row = f.ScrollChild.framePool[1]
	assert(Alpha(row._pieces[1]) == 1 and not K.Skin.IsSkinned(row, "Backdrop"), "step rows keep RestedXP's fill in the theme's colours")

	assert(#f.CurrentStepFrame.framePool == 0)
	rxp.SetStep(2)
	for _, step in ipairs(f.CurrentStepFrame.framePool) do
		assert(Glass(K, step) and Hushed(step), "each active step frame is skinned as RestedXP makes it")
		assert(K.Skin.IsSkinned(step.number, "Backdrop") and Hushed(step.number), "its number badge is a tile")
		assert(K.Skin.Parts(step.number).backdrop.chrome.fillName == "surface", "on the glass surface")
		assert(select(2, step.number.text:GetFont()) == select(2, K.Tokens.Font("caption")), "its number is a caption")
		assert(K.Skin.IsSkinned(step.elements[1].button, "CheckBox"), "its check buttons are KstyleUI check boxes")
	end

	local list, menuArt = rxp.menuLists[1], env.L_DropDownList1MenuBackdrop
	rxp:ShowMenu()
	assert(Glass(K, list) or (ns.RestedXP.Chrome.MenuPanel(list) and ns.RestedXP.Chrome.MenuPanel(list):IsShown()), "RestedXP's guide menu sits on glass")
	assert(menuArt:GetAlpha() == 0, "the menu library's backdrop is hidden while RestedXP's menu shows")
	local path = env.L_DropDownList1Button1NormalText:GetFont()
	assert(path == (ns.Style.Font("body")), "menu rows use KstyleUI's font")
	rxp.fake.open(rxp.menuLists[2])
	assert(env.L_DropDownList2MenuBackdrop:GetAlpha() == 0, "a submenu of RestedXP's menu is dressed too")
	rxp.fake.close(list)
	rxp.fake.close(rxp.menuLists[2])
	assert(menuArt:GetAlpha() == 1 and not ns.RestedXP.Chrome.MenuPanel(list):IsShown(), "closing it gives the shared menu its own look back")
	rxp.fake.open(list)
	assert(menuArt:GetAlpha() == 1, "another addon's menu in the same list keeps its own look")
	rxp.fake.close(list)
	Clean(env, rxp)
end

-- The arrow, the icon frames and their buttons ----------------------------------------------------------------

do
	local env, K, ns, rxp = Boot()
	local arrow = rxp.arrowFrame
	local ar, ag, ab = ns.Style.Accent()
	assert(W.LastCall(arrow.texture, "SetDesaturated")[1] == true and W.SameColor(arrow.texture, ar, ag, ab), "the arrow is drawn in the accent")
	arrow:UpdateVisuals()
	assert(W.SameColor(arrow.texture, ar, ag, ab), "and stays so when RestedXP redraws it")
	K.Theme.SetCustomAccent(0.2, 0.4, 0.9)
	K.Theme.SetAccentSource("custom")
	env.RunTimers()
	assert(W.SameColor(arrow.texture, 0.2, 0.4, 0.9), "an accent change reaches the arrow")

	local items, targets = rxp.activeItemFrame, rxp.targeting.activeTargetFrame
	for _, f in ipairs({ items, targets }) do
		assert(Glass(K, f) and Hushed(f), "the icon frame sits on glass")
		assert(K.Skin.IsSkinned(f.title, "Backdrop") and Hushed(f.title), "its title bar is a tile")
		assert(Accented(ns, f.title.text), "its title takes the accent")
	end
	rxp.UpdateItemFrame(items, 2)
	rxp.targeting:UpdateTargetFrame(2)
	for _, button in ipairs({ items.buttonList[1], items.buttonList[2], targets.enemyTargetButtons[1] }) do
		assert(ns.Parts.RimOf(button), "each icon button made later sits on a KstyleUI rim")
	end
	local wash = items.buttonList[1]._highlight
	assert(W.SameRGB(wash, 0.2, 0.4, 0.9), "the button highlight is an accent wash")
	K.Theme.SetCustomAccent(0.9, 0.5, 0.1)
	env.RunTimers()
	assert(W.SameRGB(wash, 0.9, 0.5, 0.1), "and follows an accent change")
	local l, r = items.buttonList[1].icon:GetTexCoord()
	assert(W.Near(l, 0.07) and W.Near(r, 0.93), "item icons are cropped like KstyleUI's")
	rxp.settings.profile.hideActiveTargetsBackground = true
	rxp.targeting:RenderTargetFrameBackground()
	assert(not Glass(K, targets), "RestedXP's hide-background setting hides the glass too")
	rxp.settings.profile.hideActiveTargetsBackground = false
	rxp.targeting:RenderTargetFrameBackground()
	assert(Glass(K, targets) and Hushed(targets), "and showing it again brings the glass back, not RestedXP's backdrop")
	Clean(env, rxp)
end

do
	local env, _, ns, rxp = Boot()
	env.SetCombat(true)
	rxp.UpdateItemFrame(rxp.activeItemFrame, 1)
	local button = rxp.activeItemFrame.buttonList[1]
	assert(not ns.Parts.RimOf(button), "secure buttons made in combat wait")
	env.SetCombat(false)
	assert(ns.Parts.RimOf(button), "and are skinned when combat ends")
	Clean(env, rxp)
end

-- The leveling report and level splits ---------------------------------------------------------------------------

do
	local env, K, ns, rxp = Boot()
	local report = rxp.tracker.ui.CharacterFrame
	assert(Glass(K, report.frame) and Hushed(report.frame), "the leveling report sits on glass")
	assert(Accented(ns, report.titletext), "its title takes the accent")
	local close
	for _, child in ipairs({ report.frame:GetChildren() }) do
		if child.obj == report and child:GetObjectType() == "Button" and child._template == "UIPanelButtonTemplate" then
			close = child
		end
	end
	assert(K.Skin.IsSkinned(close, "Button"), "its close button is a KstyleUI button")
	assert(K.Skin.IsSkinned(report.scrollContainer.scrollbar, "ScrollBar"), "its scroll bar is KstyleUI's")
	assert(K.Skin.IsSkinned(report.levelButton.frame, "Button"), "its level button is a KstyleUI button")

	assert(rxp.tracker.levelSplits == nil)
	rxp.tracker:CreateLevelSplits()
	local splits = rxp.tracker.levelSplits
	assert(Glass(K, splits) and Hushed(splits), "level splits are skinned when RestedXP makes them")
	assert(K.Skin.IsSkinned(splits.title, "Backdrop") and Accented(ns, splits.title.text))
	rxp.settings.profile.hideSplitsBackground = true
	rxp.tracker:RenderSplitsBackground()
	assert(not Glass(K, splits), "the splits' hide-background setting hides the glass")
	Clean(env, rxp)
end

-- The v2 windows: guide configurator, guide importer and its popups, and the v2 guide window --------------------

do
	local env, K, ns, rxp = Boot({ v2 = true })
	local window = rxp.v2.state.guideWindow
	assert(Glass(K, window.upperFrame) and Glass(K, window.guideStepsFrame), "the v2 guide window sits on glass")
	assert(Alpha(window.upperFrame.rxpBackground.textures[1]) == 0 and Alpha(window.upperFrame.rxpShadow.top) == 0, "RestedXP's own fill and shadow go")
	assert(Alpha(window.upperFrame.rxpBorder.textures[1]) == 0, "and its border lines")
	assert(Alpha(window.banner) == 0, "and the header banner art")
	assert(K.Skin.IsSkinned(window.closebutton, "CloseButton"), "its close button is KstyleUI's")
	assert(K.Skin.IsSkinned(window.guideSteps.scroll.scrollbar, "ScrollBar"), "its scroll bar is KstyleUI's")
	assert(Accented(ns, window.title), "its title takes the accent")
	window:UpdateSubTheme()
	assert(Accented(ns, window.title), "and keeps it when RestedXP redraws the window")

	local configurator = rxp.ui.v2.configurator
	assert(configurator.ui == nil)
	configurator:Open()
	local ui = configurator.ui
	assert(Glass(K, ui.frame) and Alpha(ui.frame.rxpBackground.configuratorHeader) == 0, "the guide configurator is skinned when it is made")
	assert(Accented(ns, ui.titletext), "its title takes the accent")
	configurator:UpdateTheme()
	assert(Accented(ns, ui.titletext), "and keeps it when RestedXP redraws the configurator")
	for _, key in ipairs({ "backbutton", "resetbutton", "submitbutton" }) do
		local button = ui[key]
		assert(K.Skin.IsSkinned(button, "Button") and Alpha(button.configuratorBackground) == 0 and Alpha(button.rxpBorder.textures[1]) == 0, key .. " is a KstyleUI button")
	end
	assert(K.Skin.IsSkinned(ui.scrollContainer.scrollbar, "ScrollBar"))

	rxp.guideImporter:Open()
	local widgets = rxp.guideImporter.widgets
	assert(Glass(K, widgets.import.frame) and Hushed(widgets.import.frame), "the guide importer is skinned when it is made")
	assert(K.Skin.IsSkinned(widgets.import.closebutton, "CloseButton"))
	assert(Accented(ns, widgets.import.title))
	assert(K.Skin.IsSkinned(widgets.importButton.frame, "Button") and K.Skin.IsSkinned(widgets.deleteButton.frame, "Button"))
	assert(K.Skin.IsSkinned(widgets.importBox.editBox, "EditBox") and Alpha(widgets.importBox.background.rxpBackground.textures[1]) == 0, "the import box is a KstyleUI edit box")
	for _, key in ipairs({ "purgeConfirmation", "deleteConfirmation" }) do
		local popup = widgets[key]
		assert(Glass(K, popup.frame) and K.Skin.IsSkinned(popup.buttons[1], "Button"), key .. " is a KstyleUI dialog")
	end
	Clean(env, rxp)
end

-- The feedback form and the export box: AceGUI frames that other addons may use after RestedXP --------------------

do
	local env, K, ns, rxp = Boot()
	local frame = rxp.pooledFrame
	local title = frame.obj.titletext
	for _, open in ipairs({ rxp.comms.OpenBugReport, rxp.comms.OpenBrandedExport }) do
		open()
		local panel = ns.RestedXP.Chrome.DressPanel(frame)
		assert(panel and panel:IsShown(), "RestedXP's dialog sits on glass while RestedXP shows it")
		assert(Alpha(frame._pieces[1]) == 0 and Alpha(frame.obj.titlebg) == 0, "its backdrop and title art are hidden")
		assert(Accented(ns, title), "its title takes the accent")
		rxp.fake.close(frame)
		assert(not panel:IsShown() and Alpha(frame._pieces[1]) == 1 and Alpha(frame.obj.titlebg) == 1, "closing it gives the shared frame its own look back")
		local r, g, b = title:GetTextColor()
		assert(W.Near(r, 1) and W.Near(g, 0.82) and W.Near(b, 0), "and its title colour")
	end
	assert(not K.Skin.IsSkinned(frame, "Backdrop"), "the shared frame is never skinned for good")
	rxp.fake.open(frame)
	assert(Alpha(frame._pieces[1]) == 1, "another addon showing the frame sees its own look")
	frame._pieces[1]:SetAlpha(0.5)
	rxp.fake.close(frame)
	assert(Alpha(frame._pieces[1]) == 0.5, "and KstyleUI leaves it alone when that addon hides it")
	Clean(env, rxp)
end

-- RestedXP's quest log button, made after login ---------------------------------------------------------------------

do
	local env, K, _, rxp = Boot()
	local button = rxp.CreateCleanupButton()
	env.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	env.RunTimers()
	assert(K.Skin.IsSkinned(button, "Button"), "the quest log clean-up button is a KstyleUI button")
	Clean(env, rxp)
end

-- Missing or renamed parts are logged once and skipped; the rest still skins --------------------------------------

do
	local env, K, _, rxp = Boot({ skip = { targeting = true, tracker = true } })
	assert(S.Logged(env, "restedXP: targeting is missing"), "a missing part is logged")
	assert(S.Logged(env, "restedXP: tracker is missing"))
	assert(Glass(K, rxp.RXPFrame.GuideName), "the rest still skins")
	Clean(env, rxp)
end

-- Switched off: windows RestedXP makes later keep RestedXP's look ---------------------------------------------------

do
	local env, K, _, rxp = Boot()
	K.Options.Write("Skins", "restedXP.enabled", false)
	rxp.SetStep(1)
	assert(not K.Skin.IsSkinned(rxp.RXPFrame.CurrentStepFrame.framePool[1], "Backdrop"), "nothing new is skinned while the switch is off")
	K.Modules.Disable("Skins")
	rxp.tracker:CreateLevelSplits()
	assert(not K.Skin.IsSkinned(rxp.tracker.levelSplits, "Backdrop"), "or while the module is off")
	K.Modules.Enable("Skins")
	env.RunTimers()
	assert(not K.Skin.IsSkinned(rxp.tracker.levelSplits, "Backdrop"), "the module on with the switch still off skins nothing")
	K.Options.Write("Skins", "restedXP.enabled", true)
	env.RunTimers()
	assert(K.Skin.IsSkinned(rxp.tracker.levelSplits, "Backdrop"), "switching on again skins what RestedXP made meanwhile")
	assert(K.Skin.IsSkinned(rxp.RXPFrame.CurrentStepFrame.framePool[1], "Backdrop"))
	K.Modules.Disable("Skins")
	rxp.SetStep(2)
	K.Modules.Enable("Skins")
	assert(K.Skin.IsSkinned(rxp.RXPFrame.CurrentStepFrame.framePool[2], "Backdrop"), "and so does turning the module on again")
	Clean(env, rxp)
end

print("skins restedxp windows ok")
