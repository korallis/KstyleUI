-- test-skins-restedxp-windows.lua: the RestedXP skin puts KstyleUI's chrome on every RestedXP window as RestedXP makes it, through KstyleUI's skin kit, without writing onto RestedXP's frames: the guide as one card with one cap, and the other windows on their own glass.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local W = S.W

-- Methods KstyleUI may replace on RestedXP's objects with hooksecurefunc.
local HOOKED = { SetAlpha = true, SetChecked = true, SetFont = true, SetText = true, UpdateVisuals = true, SetMinMaxValues = true }
local THIN_SPACE = "\226\128\137"

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

-- The v1 guide window as one card: the cap over the steps, the route's row, the folded list, the footer -------

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	assert(ns.Skins.IsApplied("restedXP"))
	local path = ns.RestedXP.Chrome.Path(f)
	assert(path and path.cap and path.card and path.holder, "a Lumen cap, a cap holder and the card frame belong to the guide")
	local card = ns.RestedXP.Chrome.Card(f)
	assert(card == path.card, "Chrome.Card names the card frame")
	assert(Glass(K, f), "the guide window sits on one KstyleUI glass")
	local glass = K.Skin.Parts(f).backdrop
	assert(glass.chrome.shapeName == "window", "window-grade glass, as the HUD's chat and tracker")
	assert(glass.target == card, "the glass follows the card frame, not RestedXP's window")
	assert(glass:GetFrameLevel() < f.GuideName:GetFrameLevel() and glass:GetFrameLevel() <= f:GetFrameLevel(), "under every RestedXP part of the window")
	assert(not K.Skin.IsSkinned(f.GuideName, "Backdrop") and not K.Skin.IsSkinned(f.BottomFrame, "Backdrop") and not K.Skin.IsSkinned(f.Footer, "Backdrop"), "the header, the list and the footer draw no glass of their own: one card, not three")
	assert(Hushed(f.BottomFrame) and Hushed(f.Footer), "RestedXP's backdrops under the list and the footer go")
	assert(Alpha(f.GuideName.bg) == 0 and Alpha(f.GuideName._pieces[1]) == 0, "the header's banner and backdrop go")
	assert(Alpha(f.GuideName.icon) == 0 and Alpha(f.GuideName.classIcon) == 0, "the logo and the class icon go too: the card has one header, the cap")
	-- The cap holder sits above the header (above the active steps once there are any), the card's top: the cap
	-- reads the guide's name as its title and the current step as its trail, one header language with the quests.
	assert(Alpha(f.GuideName.text) == 0, "RestedXP's own title is hushed")
	f.GuideName.text:SetAlpha(1)
	assert(Alpha(f.GuideName.text) == 0, "and stays hushed when RestedXP shows it again")
	local function Title()
		return (tostring(path.cap.title:GetText()):gsub(THIN_SPACE, ""))
	end
	assert(Title() == (f.GuideName.text:GetText() or ""):match("^[^\n]*"):upper(), "the cap's title is the guide's name, tracked in capitals, got " .. Title())
	local gr, gg, gb = ns.Lumen.Color("gilt")
	assert(Colored(path.cap.title, gr, gg, gb), "in gilt")
	assert(path.cap.title:GetFont() == (ns.Style.Font("title")), "in the title face, as the Quests cap")
	assert(path.cap.trail:GetText() == "", "with no active step there is no trail")
	f.GuideName.text:SetText("Durotar, 6 to 10")
	assert(Title() == "DUROTAR, 6 TO 10", "a guide change follows RestedXP's title")
	assert(not path.meta:IsShown(), "a one-line title shows no route row")
	f.GuideName.text:SetText("6-10 Durotar\nSpeedrun Guide 1-22")
	assert(Title() == "6-10 DUROTAR", "a title with the guide's route on a second line keeps the first line as the cap")
	assert(path.meta:IsShown() and path.meta:GetText() == "Speedrun Guide 1-22", "and the route becomes a caption row in RestedXP's header band")
	assert(select(2, path.meta:GetFont()) == select(2, ns.Style.Font("caption")) and Colored(path.meta, K.Tokens.Color("text")), "a caption in the body grey, as the footer")
	local holderBottom = path.holder._points[1]
	assert(holderBottom[1] == "BOTTOMLEFT" and holderBottom[2] == f.CurrentStepFrame and holderBottom[3] == "TOPLEFT", "the cap holder stands on RestedXP's active step frame, which RestedXP shows from the start")
	rxp.fake.close(f.CurrentStepFrame)
	ns.RestedXP.Chrome.Refit(f)
	holderBottom = path.holder._points[1]
	assert(holderBottom[1] == "BOTTOMLEFT" and holderBottom[2] == f.GuideName and holderBottom[3] == "TOPLEFT", "with the step frame hidden (a guide with no active step) the cap holder stands on the header's top")
	rxp.fake.open(f.CurrentStepFrame)
	ns.RestedXP.Chrome.Refit(f)
	local capTop = path.cap.row._points[1]
	assert(capTop[1] == "TOPLEFT" and capTop[2] == path.holder, "the cap row hangs from the holder")
	local cardTop, cardBottom = card._points[1], card._points[3]
	assert(cardTop[1] == "TOPLEFT" and cardTop[2] == path.holder and cardBottom[1] == "BOTTOM" and cardBottom[2] == f, "the card runs from the cap holder's top to RestedXP's window bottom, the footer")
	assert(W.Near(f.GuideName:GetHeight(), K.Widgets.Snap(f.GuideName, 18)), "RestedXP's 35-unit header band shrinks to the route's caption row, since the cap left it, got " .. tostring(f.GuideName:GetHeight()))
	assert(path.height == 18 and path.capHeight > 16, "the head reports the band's height and the cap holder's")
	K.Options.Write("Skins", "text.size", 1.5)
	env.RunTimers()
	assert(W.Near(select(2, path.cap.title:GetFont()), ns.Lumen.CAP_SIZE * 1.5), "a text size change reaches the cap")
	K.Options.Write("Skins", "text.size", 1)
	env.RunTimers()
	assert(select(2, f.Footer.text:GetFont()) == select(2, K.Tokens.Font("caption")) and Colored(f.Footer.text, K.Tokens.Color("text")), "the footer line is a caption in the body grey")
	assert(K.Skin.IsSkinned(f.ScrollFrame.ScrollBar, "ScrollBar"), "the step list's scroll bar is KstyleUI's")
	f:UpdateVisuals()
	assert(Hushed(f.BottomFrame) and Alpha(f.GuideName._pieces[1]) == 0, "RestedXP's redraw keeps the glass")
	local row = f.ScrollChild.framePool[1]
	assert(Alpha(row._pieces[1]) == 1 and not K.Skin.IsSkinned(row, "Backdrop"), "step rows keep RestedXP's fill in the theme's colours")

	-- RestedXP's text cannot move, so the glass grows outward instead: RestedXP keeps its content 4 units from
	-- its frames' sides (a step's check box, the list's rows, the footer's cog), and the glass reaches one content
	-- inset (the rule every text panel follows, at the window cut) past that on the left and the right, so every
	-- check box and line clears the corner cuts and the light line. Top and bottom stay the card's.
	local reach = K.Widgets.Inset(f.GuideName, K.Tokens.Size("chamferWindow")) - 4
	assert(reach > 6, "the glass reaches more than 6 units past RestedXP's frames, got " .. tostring(reach))
	local tl, br = glass._points[1], glass._points[2]
	assert(tl[1] == "TOPLEFT" and tl[2] == card and br[1] == "BOTTOMRIGHT" and br[2] == card, "the glass hangs from both corners of the card")
	local snapped = K.Widgets.Snap(glass, reach)
	assert(W.Near(tl[4], -snapped) and W.Near(br[4], snapped), "the glass reaches " .. reach .. " past both sides, got " .. tostring(tl[4]) .. " and " .. tostring(br[4]))
	assert(W.Near(tl[5], 0) and W.Near(br[5], 0), "the glass keeps the card's top and bottom")
	-- The cap's gem sits where the Quests cap's does: one content inset in from the glass edge.
	local gem = path.cap.gem._points[1]
	assert(W.Near(gem[4], K.Widgets.Snap(path.cap.row, 4)), "the gem sits 4 in from RestedXP's inner edge, one content inset from the glass, got " .. tostring(gem[4]))

	-- The step list's view ends wherever RestedXP's frame height lands, mid-row more often than not, so a fade on
	-- KstyleUI's own frame softens the cut line while there is more to scroll, and lifts at the end (round 1, Fable and Opus).
	local fade = ns.RestedXP.Chrome.Fade(f.BottomFrame)
	assert(fade, "a fade sits over the foot of the step list")
	assert(fade:GetParent() ~= f.BottomFrame and fade:GetParent() ~= f.ScrollFrame, "drawn on KstyleUI's own frame, not on RestedXP's")
	assert(fade:GetParent():GetFrameLevel() > f.ScrollFrame:GetFrameLevel(), "above the scroll view, so it covers the rows")
	local fadePoints = {}
	for _, p in ipairs(fade._points) do
		fadePoints[p[1]] = p
	end
	assert(fadePoints.BOTTOMLEFT and fadePoints.BOTTOMLEFT[2] == f.ScrollFrame and fadePoints.BOTTOMRIGHT and fadePoints.BOTTOMRIGHT[2] == f.ScrollFrame, "along the view's foot")
	assert(W.Near(fade:GetHeight(), K.Widgets.Snap(fade, K.Tokens.Size("gapXLarge"))), "a gapXLarge tall")
	local bar = f.ScrollFrame.ScrollBar
	f.ScrollChild:SetHeight(200)
	f.BottomFrame:SetHeight(130)
	bar:SetValue(0)
	local _, high = bar:GetMinMaxValues()
	assert(high and high >= 80, "RestedXP's range cap, plus the header reserve the skin adds back, leaves scroll room: " .. tostring(high))
	assert(fade:IsShown(), "shown while rows wait below the view")
	bar:SetValue(high)
	assert(not fade:IsShown(), "hidden at the end of the list, where the last row is whole")
	bar:SetValue(20)
	assert(fade:IsShown(), "and back while scrolled up")
	bar:SetValue(env.Secret(5))
	assert(fade:IsShown(), "a secret scroll value leaves the fade as it was")

	-- The scroll bar sits in its own gutter: a faint line, one border wide, runs the list's height a gap left
	-- of the bar, on KstyleUI's own glass frame.
	local gutter = ns.RestedXP.Chrome.Gutter(f.BottomFrame)
	assert(gutter and gutter:IsShown(), "a gutter line beside the step list's scroll bar")
	assert(gutter:GetParent() == glass, "drawn on KstyleUI's glass, not on RestedXP's frame")
	assert(W.SameColor(gutter, K.Tokens.Color("edgeFaint")), "as faint as the kit's dividers")
	assert(W.Near(gutter:GetWidth(), K.Widgets.Border(gutter)), "one border wide")
	local points = {}
	for _, p in ipairs(gutter._points) do
		points[p[1]] = p
	end
	assert(points.TOP and points.TOP[2] == f.BottomFrame and points.BOTTOM and points.BOTTOM[2] == f.BottomFrame, "from the list's top to its bottom")
	local right = points.RIGHT
	assert(right and right[2] == f.ScrollFrame.ScrollBar and right[3] == "LEFT" and W.Near(right[4], -K.Widgets.Snap(gutter, K.Tokens.Size("gapSmall") / 2)), "half a gapSmall left of the bar")

	-- The active steps are rows inside the card, not cards of their own: no glass, the Step plate hushed (the cap's
	-- trail carries the step), KstyleUI ring checks on each element.
	assert(#f.CurrentStepFrame.framePool == 0)
	rxp.SetStep(2)
	assert(#f.CurrentStepFrame.framePool == 2)
	for _, step in ipairs(f.CurrentStepFrame.framePool) do
		assert(not K.Skin.IsSkinned(step, "Backdrop") and Hushed(step), "an active step draws no glass of its own; RestedXP's backdrop goes")
		assert(not K.Skin.IsSkinned(step.number, "Backdrop") and Hushed(step.number), "its Step plate draws nothing")
		assert(Alpha(step.number.text) == 0, "and its text is hushed: the cap's trail reads the step")
		step.number.text:SetAlpha(1)
		assert(Alpha(step.number.text) == 0, "even when RestedXP shows it again")
		local ring = ns.Lumen.RingOf(step.elements[1].button)
		assert(ring and ring.box:IsShown(), "its check buttons are Lumen ring checks")
		assert(not K.Skin.IsSkinned(step.elements[1].button, "CheckBox"), "not the square kit box")
	end
	assert(path.cap.trail:GetText() == f.CurrentStepFrame.framePool[1].number.text:GetText(), "the cap's trail is the first shown step's plate text, as RestedXP wrote it: " .. tostring(path.cap.trail:GetText()))
	holderBottom = path.holder._points[1]
	assert(holderBottom[1] == "BOTTOMLEFT" and holderBottom[2] == f.CurrentStepFrame and holderBottom[3] == "TOPLEFT", "with steps above the header the cap holder stands on the steps")
	assert(W.Near(holderBottom[5], 0), "right on them: RestedXP's step frame keeps 10 units of air above its first line")
	rxp.fake.trust(function()
		f.CurrentStepFrame.anchor = "BOTTOM"
	end)()
	rxp.SetStep(2)
	holderBottom = path.holder._points[1]
	assert(holderBottom[2] == f.GuideName, "with RestedXP's steps anchored under the window the cap stands on the header again")
	assert(card._points[3][2] == f.CurrentStepFrame, "and the card runs down to the steps")
	rxp.fake.trust(function()
		f.CurrentStepFrame.anchor = "TOP"
	end)()
	rxp.SetStep(2)
	assert(card._points[3][2] == f, "back on top, the card ends at the footer")

	local list, menuArt = rxp.menuLists[1], env.L_DropDownList1MenuBackdrop
	rxp:ShowMenu()
	assert(Glass(K, list) or (ns.RestedXP.Chrome.MenuPanel(list) and ns.RestedXP.Chrome.MenuPanel(list):IsShown()), "RestedXP's guide menu sits on glass")
	assert(menuArt:GetAlpha() == 0, "the menu library's backdrop is hidden while RestedXP's menu shows")
	local menuFont = env.L_DropDownList1Button1NormalText:GetFont()
	assert(menuFont == (ns.Style.Font("body")), "menu rows use KstyleUI's font")
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
	-- The title and the buttons use the kit's text roles (round 3, Opus): the title in the heading face at its
	-- size, each button label in the body role in the emphasised text, and RestedXP's own flat button wash hushed;
	-- RestedXP's UpdateTheme re-fonts all of them from its theme, so the skin applies the roles again after it.
	local function Roles()
		assert(ui.titletext:GetFont() == (ns.Style.Font("heading")) and select(2, ui.titletext:GetFont()) == select(2, ns.Style.Font("heading")), "the title is in the kit's heading role, got " .. tostring(ui.titletext:GetFont()) .. " " .. tostring(select(2, ui.titletext:GetFont())))
		assert(Accented(ns, ui.titletext), "in the accent")
		for _, key in ipairs({ "backbutton", "resetbutton", "submitbutton" }) do
			local button = ui[key]
			assert(K.Skin.IsSkinned(button, "Button") and Alpha(button.configuratorBackground) == 0 and Alpha(button.rxpBorder.textures[1]) == 0, key .. " is a KstyleUI button")
			local label = button:GetFontString()
			assert(label:GetFont() == (ns.Style.Font("body")) and select(2, label:GetFont()) == select(2, ns.Style.Font("body")), key .. "'s label is in the body role, got " .. tostring(select(2, label:GetFont())))
			assert(Colored(label, K.Tokens.Color("textEmphasis")), key .. "'s label is the emphasised text")
		end
	end
	Roles()
	configurator:UpdateTheme()
	Roles()
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
	assert(Glass(K, rxp.RXPFrame), "the rest still skins")
	Clean(env, rxp)
end

-- Switched off: windows RestedXP makes later keep RestedXP's look ---------------------------------------------------

do
	local env, K, ns, rxp = Boot()
	K.Options.Write("Skins", "restedXP.enabled", false)
	rxp.SetStep(1)
	local step = rxp.RXPFrame.CurrentStepFrame.framePool[1]
	assert(not ns.Lumen.RingOf(step.elements[1].button) and step.number.text:GetAlpha() == 1, "nothing new is skinned while the switch is off")
	K.Modules.Disable("Skins")
	rxp.tracker:CreateLevelSplits()
	assert(not K.Skin.IsSkinned(rxp.tracker.levelSplits, "Backdrop"), "or while the module is off")
	K.Modules.Enable("Skins")
	env.RunTimers()
	assert(not K.Skin.IsSkinned(rxp.tracker.levelSplits, "Backdrop"), "the module on with the switch still off skins nothing")
	K.Options.Write("Skins", "restedXP.enabled", true)
	env.RunTimers()
	assert(K.Skin.IsSkinned(rxp.tracker.levelSplits, "Backdrop"), "switching on again skins what RestedXP made meanwhile")
	assert(ns.Lumen.RingOf(step.elements[1].button) and step.number.text:GetAlpha() == 0)
	K.Modules.Disable("Skins")
	rxp.SetStep(2)
	K.Modules.Enable("Skins")
	assert(ns.Lumen.RingOf(rxp.RXPFrame.CurrentStepFrame.framePool[2].elements[1].button), "and so does turning the module on again")
	Clean(env, rxp)
end

print("skins restedxp windows ok")
