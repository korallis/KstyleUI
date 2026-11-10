-- test-skins-restedxp-windows.lua: the RestedXP skin puts KstyleUI's chrome on every RestedXP window as RestedXP makes it, through KstyleUI's skin kit, without writing onto RestedXP's frames: the guide as one card with one cap, and the other windows on their own glass.
local S = dofile("Tools/regression/skins_env.lua")

local function FontSize(K, text, actual, requested)
	local factor = type(text.GetEffectiveScale) == "function" and K.Widgets.ScaleFactor(text) or 1
	local pixels = actual * factor / K.Scale.Pixel(1)
	return math.abs(actual - K.Widgets.FontSize(text, requested)) < 1e-8
		and math.abs(pixels - math.floor(pixels + 0.5)) < 1e-8
end
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local W = S.W

-- Methods KstyleUI may replace on RestedXP's objects with hooksecurefunc.
local HOOKED = { SetAlpha = true, SetChecked = true, SetFont = true, SetFontObject = true, SetText = true, SetStatusBarColor = true, UpdateVisuals = true, SetMinMaxValues = true, DoLayout = true }
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

-- A window's or a panel's title wears the caps role in the picture's muted gold (the Captain's ruling on type roles
-- beyond the HUD, 2026-11-10, after handoffs/reference-diff/DIFF-acceptance-1.md found RestedXP's configurator title
-- on "title" and its report heading on "heading"): a caption of KstyleUI's own stands over RestedXP's hushed title, in
-- capitals, and RestedXP's own text takes the caption's font so whatever RestedXP lays out from it measures the caption.
local function Capped(K, ns, text, what)
	local caption = ns.RestedXP.Chrome.Caption(text)
	assert(caption, what .. ": the title has a caption of KstyleUI's own")
	assert(caption:GetFont() == (ns.Style.Font("caps")) and Colored(caption, K.Tokens.Color("capsGold")), what .. ": the caption wears the caps role in the picture's muted gold, got " .. tostring(caption:GetFont()))
	assert(text:GetAlpha() == 0, what .. ": RestedXP's own title is hushed under it")
	assert((caption:GetText() or "") == K.Locale.Upper(text:GetText() or ""), what .. ": the caption says RestedXP's words in capitals, got " .. tostring(caption:GetText()))
	local path, size = caption:GetFont()
	local own, ownSize = text:GetFont()
	assert(own == path and ownSize == size, what .. ": RestedXP's text measures as the caption does, got " .. tostring(own) .. " " .. tostring(ownSize))
end

local newFailures = {}
local function NewCheck(ok, message)
	if not ok then
		newFailures[#newFailures + 1] = message
		print("NEW WINDOW CHECK FAILED: " .. message)
	end
	return ok
end

local function Proxy(K, source, kind)
	for _, child in ipairs({ source:GetChildren() }) do
		if K.Skin.IsSkinned(child, kind) then return child end
	end
end

local function Replacement(text)
	for _, child in ipairs({ text:GetParent():GetChildren() }) do
		if child.label and child:GetNumPoints() > 0 and select(2, child:GetPoint(1)) == text then return child.label end
	end
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
	assert(glass.chrome.gilt ~= nil, "the story card wears gilt L-ticks: the owner's picture of 2026-11-09 reverses #205's thin rim and nothing else")
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
	local gr, gg, gb = K.Tokens.Color("capsGold")
	assert(Colored(path.cap.title, gr, gg, gb), "in the picture's muted gold")
	assert(path.cap.title:GetFont() == (ns.Style.Font("caps")), "in the caps face, as the Quests cap")
	assert(path.cap.trail:GetText() == "", "with no active step there is no trail")
	f.GuideName.text:SetText("Durotar, 6 to 10")
	assert(Title() == "DUROTAR, 6 TO 10", "a guide change follows RestedXP's title")
	assert(not path.meta:IsShown(), "a one-line title shows no route row")
	-- One fact, one place (owner, 2026-11-09): RestedXP appends the guide's group to its name
	-- (GuideWindow.lua: guidename .. "\n" .. guide.subgroup); the cap already names the guide, so the group line
	-- is hushed. A guide whose own name runs to two lines (no subgroup) keeps its second line as a caption row.
	rxp.currentGuide = { name = "6-10 Durotar", subgroup = "Speedrun Guide 1-22" }
	f.GuideName.text:SetText("6-10 Durotar\nSpeedrun Guide 1-22")
	assert(Title() == "6-10 DUROTAR", "a title with the guide's group on a second line keeps the first line as the cap")
	assert(not path.meta:IsShown(), "and the group line, which repeats the guide head, is hushed")
	assert(path.height < 18, "so the header band closes up, got " .. tostring(path.height))
	rxp.currentGuide = { name = "Elwynn Forest\\n1-10 Human" }
	f.GuideName.text:SetText("Elwynn Forest\n1-10 Human")
	assert(Title() == "ELWYNN FOREST" and path.meta:IsShown() and path.meta:GetText() == "1-10 Human", "a guide's own two-line name keeps its second line")
	assert(FontSize(K, path.meta, select(2, path.meta:GetFont()), select(2, ns.Style.Font("caption"))) and Colored(path.meta, K.Tokens.Color("text")), "a caption in the body grey")
	rxp.currentGuide = { name = "6-10 Durotar", subgroup = "Speedrun Guide 1-22" }
	f.GuideName.text:SetText("6-10 Durotar\nSpeedrun Guide 1-22")
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
	assert(W.Near(f.GuideName:GetHeight(), K.Widgets.Snap(f.GuideName, path.height)), "RestedXP's 35-unit header band shrinks to what is left in it, since the cap left it, got " .. tostring(f.GuideName:GetHeight()))
	assert(path.height < 18 and path.capHeight > 16, "the head reports the band's height and the cap holder's")
	K.Options.Write("Skins", "text.size", 1.5)
	env.RunTimers()
	assert(FontSize(K, path.cap.title, select(2, path.cap.title:GetFont()), ns.Lumen.CAP_SIZE * 1.5 / K.Widgets.ScaleFactor(path.cap.row)), "a text size change reaches the cap, whose 12 root units are the same pixels in RestedXP's window as in KstyleUI's own")
	K.Options.Write("Skins", "text.size", 1)
	env.RunTimers()
	assert(Alpha(f.Footer.text) == 0, "the footer's version line (RestedXP Guides v4.11.35) is hushed: it tells the player nothing while they play")
	f.Footer.text:SetAlpha(1)
	assert(Alpha(f.Footer.text) == 0, "and stays hushed when RestedXP's timer bar gives the footer back (Timers.lua)")
	assert(Alpha(f.Footer.cog) == 0 and Alpha(f.Footer.icon) == 0, "in the story rail the cog and the grip rest too, as the picture draws the card (LEE-20); a right click on the cap opens RestedXP's menu")
	assert(K.Skin.IsSkinned(f.ScrollFrame.ScrollBar, "ScrollBar"), "the step list's scroll bar is KstyleUI's")
	f:UpdateVisuals()
	assert(Hushed(f.BottomFrame) and Alpha(f.GuideName._pieces[1]) == 0, "RestedXP's redraw keeps the glass")
	local row = f.ScrollChild.framePool[1]
	assert(Alpha(row._pieces[1]) == 1 and not K.Skin.IsSkinned(row, "Backdrop"), "step rows keep RestedXP's fill in the theme's colours")

	-- RestedXP's text cannot move, so the glass grows outward instead: RestedXP keeps its content 4 units from
	-- its frames' sides (a step's check box, the list's rows, the footer's cog), and the glass reaches one content
	-- inset (the rule every text panel follows, at the window cut) past that on the left and the right, so every
	-- check box and line clears the corner cuts and the light line. Top and bottom stay the card's.
	local reach = ns.Lumen.Inset(f.GuideName) - 4
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
		assert(Alpha(step.elements[1].button) == 0, "and they rest unseen until the pointer is over the step: the picture's steps are plain lines")
	end
	assert(path.cap.trail:GetText() == f.CurrentStepFrame.framePool[1].number.text:GetText(), "the cap's trail is the first shown step's plate text, as RestedXP wrote it: " .. tostring(path.cap.trail:GetText()))
	holderBottom = path.holder._points[1]
	assert(holderBottom[1] == "BOTTOMLEFT" and holderBottom[2] == f.CurrentStepFrame and holderBottom[3] == "TOPLEFT", "with steps above the header the cap holder stands on the steps")
	assert(W.Near(holderBottom[5], -K.Widgets.Snap(path.holder, 12)), "12 under their top: RestedXP's step frame keeps 10 empty units where its hushed Step plate hung and starts its text 2 lower, so the cap reads right over the first line, as the picture draws it, got " .. tostring(holderBottom[5]))
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

	-- GetName may answer a secret (SimpleFrameScriptObjectAPIDocumentation.lua:107-119, ObjectName). A secret is no
	-- key into _G: the menu takes its glass and skips only the lookups by name.
	do
		local meta = getmetatable(env)
		local index = meta.__index
		meta.__index = function(t, key)
			if env.issecretvalue(key) then
				error("a secret name was used as a key into _G", 2)
			end
			if type(index) == "function" then
				return index(t, key)
			end
			return index[key]
		end
		rawset(list, "GetName", function()
			return env.Secret("L_DropDownList1")
		end)
		rxp:ShowMenu()
		rawset(list, "GetName", nil)
		meta.__index = index
		assert(#env._errors == 0 and not S.Logged(env, "secret name"), "a secret menu name is never used as a key: " .. tostring(env._errors[1] or S.Logged(env, "secret name")))
		assert(ns.RestedXP.Chrome.MenuPanel(list):IsShown() and menuArt:GetAlpha() == 1, "the menu still takes its glass; the art found by name keeps its look")
		rxp.fake.close(list)
	end
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
		assert(not K.Skin.IsSkinned(f.title, "Backdrop") and Hushed(f.title), "its title plate draws nothing of its own: the title reads on the card's glass")
		local caption = assert(ns.RestedXP.Chrome.Caption(f.title.text), "its title is a caption of KstyleUI's own, so RestedXP's font string carries no wrapped method")
		assert(f.title.text:GetAlpha() == 0 and caption:GetText() == f.title.text:GetText():upper(), "RestedXP's title rests and the caption says it in capitals, got " .. tostring(caption:GetText()))
		assert(Colored(caption, K.Tokens.Color("capsGold")), "in the picture's muted gold")
		assert(caption:GetFont() == (ns.Style.Font("caps")) and FontSize(K, caption, select(2, caption:GetFont()), ns.Lumen.CAP_SIZE / K.Widgets.ScaleFactor(caption:GetParent())), "in the tracked caps role, as the guide's and the quests' captions, never RestedXP's 9")
		assert(rawget(f.title.text, "SetPoint") == nil, "the caps role's anchor wrapping stays off RestedXP's own font string")
		local point, on, onPoint, x = caption:GetPoint(1)
		assert(point == "LEFT" and on == f.title and onPoint == "LEFT" and x == 5, "the caption starts where RestedXP's plate starts its words, 5 in from the plate's left, however wide the plate was when the skin met it, got " .. tostring(point) .. " " .. tostring(x))
	end
	-- RestedXP sizes the plate and the frame from its own 9-unit title (Targeting.lua 818, 1112). The caps caption is
	-- wider, so a frame of three targets was narrower than its caption and the caption left the glass: the glass
	-- now reaches as far right of the caption as the caption starts from the left.
	do
		local Scene = dofile("Tools/render/scene.lua")
		env._textWidth = function(value, _, size)
			return #value * size * 0.7
		end
		targets:ClearAllPoints()
		targets:SetPoint("CENTER", env.UIParent, "CENTER", 0, -200)
		targets:SetSize(91, 43)
		targets.title:ClearAllPoints()
		targets.title:SetPoint("TOPLEFT", targets, "TOPLEFT", 5, 8)
		targets:UpdateVisuals()
		env.RunTimers()
		local caption = ns.RestedXP.Chrome.Caption(targets.title.text)
		local words = K.Widgets.TextWidth(caption, 0)
		assert(words + 20 > 91, "the caption is wider than the frame in this block, got " .. words)
		local gx, _, gw = Scene.Rect(env, K.Skin.Parts(targets).backdrop)
		local tx, _, tw = Scene.Rect(env, targets)
		local unit = tw / targets:GetWidth()
		assert(gx and tx and gx <= tx + 0.5 and gx + gw >= tx + (20 + words) * unit - 0.5, string.format("the glass holds the whole caption: glass %.1f..%.1f, caption to %.1f", gx, gx + gw, tx + (10 + words) * unit))
		targets:SetSize(20 + words + 30, 43)
		targets:UpdateVisuals()
		local wx, _, ww = Scene.Rect(env, K.Skin.Parts(targets).backdrop)
		local nx, _, nw = Scene.Rect(env, targets)
		assert(math.abs(wx + ww - (nx + nw)) <= 0.5, "a frame wide enough for its caption keeps the glass on its own edge")
		env._textWidth = nil
	end
	-- RestedXP hangs the title plate from the frame's top edge (TOPLEFT at 5, 10, 19 tall), so the plate straddled
	-- the glass (Opus #5, R4a). The card's glass now rises over the plate, so the title sits inside one card.
	do
		local Scene = dofile("Tools/render/scene.lua")
		items:ClearAllPoints()
		items:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
		items:SetSize(100, 43)
		items.title:ClearAllPoints()
		items.title:SetPoint("TOPLEFT", items, "TOPLEFT", 5, 10)
		items.title:SetSize(60, 19)
		rxp.UpdateItemFrame(items, 1)
		env.RunTimers()
		local glass = K.Skin.Parts(items).backdrop
		local gx, gy, gw, gh = Scene.Rect(env, glass)
		local tx, ty, tw, th = Scene.Rect(env, items.title)
		assert(gx and tx, "the glass and the title plate resolve")
		assert(ty >= gy - 0.5 and tx >= gx - 0.5 and tx + tw <= gx + gw + 0.5 and ty + th <= gy + gh + 0.5,
			string.format("the title plate lies on the card's glass: plate %.1f..%.1f x %.1f..%.1f, glass %.1f..%.1f x %.1f..%.1f", tx, tx + tw, ty, ty + th, gx, gx + gw, gy, gy + gh))
		local ix, iy, iw, ih = Scene.Rect(env, items)
		assert(ix and iy + ih <= gy + gh + 0.5 and ix >= gx - 0.5 and ix + iw <= gx + gw + 0.5, "the frame's own rect stays on the glass")
	end
	rxp.UpdateItemFrame(items, 2)
	rxp.targeting:UpdateTargetFrame(2)
	for _, button in ipairs({ items.buttonList[1], items.buttonList[2], targets.enemyTargetButtons[1] }) do
		assert(ns.Parts.RimOf(button), "each icon button made later sits on a KstyleUI rim")
	end
	local wash = items.buttonList[1]:GetHighlightTexture()
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

-- RestedXP makes no item or target button in combat (ActiveItemFrame.lua 351, Targeting.lua 1129), so the skin meets a
-- secure button in combat only when it starts there: it waits, and skins the button when combat ends.

do
	local rxp
	local env, K, ns = S.New({
		setup = function(env)
			rxp = Fake.Install(env, {})
			rxp.UpdateItemFrame(rxp.activeItemFrame, 1)
		end,
	})
	env.SetCombat(true)
	K.Modules.Enable("Skins")
	env.RunTimers()
	local button = rxp.activeItemFrame.buttonList[1]
	assert(button and not ns.Parts.RimOf(button), "a secure button the skin finds in combat waits")
	rxp.UpdateItemFrame(rxp.activeItemFrame, 2)
	assert(rxp.activeItemFrame.buttonList[2] == nil, "RestedXP itself lists no item in combat")
	env.SetCombat(false)
	assert(ns.Parts.RimOf(button), "and is skinned when combat ends")
	Clean(env, rxp)
end

-- The leveling report and level splits ---------------------------------------------------------------------------

do
	local env, K, ns, rxp = Boot()
	local report = rxp.tracker.ui.CharacterFrame
	assert(Glass(K, report.frame) and Hushed(report.frame), "the leveling report sits on glass")
	local reportInset = K.Skin.Parts(report.frame).backdrop.inset
	assert(type(reportInset) == "table" and reportInset.top == -K.Tokens.Size("gapMedium"), "the glass rises a medium gap over the report: AceGUI hangs the title 2 under the frame's top (AceGUIContainer-Frame.lua 226, 237), so it would touch the rim")
	Capped(K, ns, report.titletext, "the leveling report")
	local close
	for _, child in ipairs({ report.frame:GetChildren() }) do
		if child.obj == report and child:GetObjectType() == "Button" and child._template == "UIPanelButtonTemplate" then
			close = child
		end
	end
	assert(K.Skin.IsSkinned(close, "Button"), "its close button is a KstyleUI button")
	assert(K.Skin.IsSkinned(report.scrollContainer.scrollbar, "ScrollBar"), "its scroll bar is KstyleUI's")
	assert(K.Skin.IsSkinned(report.levelButton.frame, "Button"), "its level button is a KstyleUI button")
	local inspect = env.CreateFrame("Frame", "InspectFrame", env.UIParent)
	rxp.tracker:CreateGui(inspect, "Another player")
	local other = rxp.tracker.ui.InspectFrame
	assert(other and env.RESTEDXP_TRACKER_SUMMARY_WINDOW == other.frame, "CreateGui keys each report by its attachment's name")
	NewCheck(Glass(K, other.frame), "reports created after startup sit on glass")
	NewCheck(K.Skin.IsSkinned(other.scrollContainer.scrollbar, "ScrollBar"), "inspection report scroll bars are skinned")
	local heading, data = Replacement(other.reachedContainer.label.label), Replacement(other.reachedContainer.data.label)
	NewCheck(heading and data and heading:GetFont() == (ns.Style.Font("caps")) and Colored(heading, K.Tokens.Color("capsGold")) and data:GetFont() == (ns.Style.Font("body")), "report headings wear the caps role in the muted gold and data the body face")
	NewCheck(heading and heading:GetText() == K.Locale.Upper(other.reachedContainer.label.label:GetText()), "a report heading reads in capitals")
	-- AceGUI lays the report out from its own labels (a Heading's rules hang 5 units off its label's ends, a Label's
	-- frame is as tall as its label's string: AceGUIWidget-Heading.lua 29 and 53-60, AceGUIWidget-Label.lua 49-56), so
	-- while RestedXP shows the report each of its texts takes the font of the label drawn over it.
	for what, widget in pairs({ heading = other.reachedContainer.label, data = other.reachedContainer.data }) do
		local over = Replacement(widget.label)
		local path, size = over:GetFont()
		local own, ownSize = widget.label:GetFont()
		NewCheck(own == path and ownSize == size, "the report's own " .. what .. " text measures as the label drawn over it, got " .. tostring(own) .. " " .. tostring(ownSize) .. " for " .. tostring(path) .. " " .. tostring(size))
	end
	do
		-- RestedXP's OnShow callback fills and lays the report out in its own fonts before the skin's hook leases the
		-- kit's (LevelingTracker.lua 463-467 and 850), so after leasing the skin has AceGUI measure each label again
		-- (the widget's SetText, AceGUIWidget-Label.lua 98-101) and lay the list out (DoLayout), as UpdateReport does.
		local row = other.reachedContainer.data
		local body = (ns.Style.Font("body"))
		NewCheck(row.measuredFont and row.measuredFont[1] == body and other.scrollContainer.layouts > 0, "after leasing, the report's labels are measured again in the font drawn and the list is laid out, got " .. tostring(row.measuredFont and row.measuredFont[1]))
		rxp.fake.close(other.frame)
		local hiddenFont, hiddenSize = row.label:GetFont()
		NewCheck(hiddenFont == "Fonts\\FRIZQT__.TTF" and hiddenSize == 12 and row.label:GetFontObject() == row.fontObject, "a hidden report's label has RestedXP's font object back, got " .. tostring(hiddenFont) .. " " .. tostring(hiddenSize))
		row:SetText("In-progress")
		NewCheck(row.measuredFont[1] == "Fonts\\FRIZQT__.TTF", "RestedXP measures a hidden report in its own font")
		local layouts = other.scrollContainer.layouts
		rxp.fake.open(other.frame)
		NewCheck(row.measuredFont[1] == body and other.scrollContainer.layouts > layouts, "a reopened report is measured and laid out again after the lease, got " .. tostring(row.measuredFont[1]))
		-- A text size change while the report is open changes the leased fonts, so the rows are measured again then too.
		local sized = row.measuredFont[2]
		layouts = other.scrollContainer.layouts
		K.Options.Write("Skins", "text.size", 1.5)
		env.RunTimers()
		NewCheck(row.measuredFont[2] > sized and row.measuredFont[2] == select(2, row.label:GetFont()) and other.scrollContainer.layouts > layouts, "an open report is measured and laid out again when the text size changes, got " .. tostring(row.measuredFont[2]) .. " after " .. tostring(sized))
		K.Options.Write("Skins", "text.size", 1)
		env.RunTimers()
		heading = Replacement(other.reachedContainer.label.label)
	end
	do
		local point, on, onPoint = heading:GetPoint(1)
		NewCheck(heading:GetNumPoints() == 1 and point == "CENTER" and on == other.reachedContainer.label.label and onPoint == "CENTER" and W.LastCall(heading, "SetWordWrap")[1] == false, "a heading's caption hangs on one point and never wraps, so a label narrower than its capitals cannot cut it")
	end
	assert(other.scrollContainer.scrollbar:GetParent() == other.scrollContainer.scrollframe, "AceGUI's scroll bar belongs to its scroll frame")

	assert(rxp.tracker.levelSplits == nil)
	rxp.tracker:CreateLevelSplits()
	local splits = rxp.tracker.levelSplits
	assert(Glass(K, splits) and Hushed(splits), "level splits are skinned when RestedXP makes them")
	assert(not K.Skin.IsSkinned(splits.title, "Backdrop") and Colored(ns.RestedXP.Chrome.Caption(splits.title.text), K.Tokens.Color("capsGold")), "its title is a caption on the card's glass, as the icon frames'")
	assert(splits:GetParent() == env.UIParent and splits.title.splitsMenuFrame:GetName() == "RXPG_SplitsMenuFrame")
	for _, key in ipairs({ "history", "current", "total" }) do
		NewCheck(splits[key].label:GetFont() == (ns.Style.Font("body")), "splits " .. key .. " uses the kit body face")
	end
	-- RestedXP refreshes the splits once a second and sets its own font back whenever the label's size is not its
	-- size setting (LevelingTracker.lua 1319-1326), so the kit's face has to come back with every such call, at the
	-- size RestedXP asks for or the readable floor, whichever is larger.
	rxp.tracker:UpdateLevelSplits()
	for _, key in ipairs({ "history", "current", "total" }) do
		NewCheck(splits[key].label:GetFont() == (ns.Style.Font("body")), "splits " .. key .. " keeps the kit body face through RestedXP's refresh, got " .. tostring(splits[key].label:GetFont()))
	end
	rxp.settings.profile.levelSplitsFontSize = 20
	rxp.tracker:UpdateLevelSplits()
	for _, key in ipairs({ "history", "current", "total" }) do
		local path, size = splits[key].label:GetFont()
		NewCheck(path == (ns.Style.Font("body")) and FontSize(K, splits[key].label, size, 20), "splits " .. key .. " follows RestedXP's size setting in the kit's face, got " .. tostring(path) .. " " .. tostring(size))
	end
	rxp.settings.profile.levelSplitsFontSize = 11
	rxp.tracker:UpdateLevelSplits()
	NewCheck(K.Skin.IsSkinned(splits.title.cog, "Button"), "splits cog is a kit button")
	local cogPoint, cogOn, cogOnPoint, cogX, cogY = splits.title.cog:GetPoint(1)
	assert(cogPoint == "TOPRIGHT" and cogOn == splits and cogOnPoint == "TOPRIGHT" and cogX == -8 and W.Near(cogY, 5.5), "the cog stands at the right end of the title's row, inside the glass and clear of the gilt tick: RestedXP hangs it off the top left corner (LevelingTracker.lua 1057), got " .. tostring(cogPoint) .. " " .. tostring(cogX) .. " " .. tostring(cogY))
	rxp.settings.profile.hideSplitsBackground = true
	rxp.tracker:RenderSplitsBackground()
	assert(not Glass(K, splits), "the splits' hide-background setting hides the glass")
	Clean(env, rxp)
end

do
	local rxp
	local env, K = S.New({ setup = function(environment)
		rxp = Fake.Install(environment, { windows = false })
		rxp.settings.profile.enableTracker = false
		Fake.Windows(environment, rxp)
	end })
	K.Modules.Enable("Skins")
	env.RunTimers()
	assert(next(rxp.tracker.ui) == nil, "the disabled tracker makes no startup character report")
	K.Options.Write("Skins", "restedXP.enabled", false)
	local attachment = env.CreateFrame("Frame", "LaterCharacterFrame", env.UIParent)
	rxp.tracker:CreateGui(attachment, "Tester")
	assert(not Glass(K, rxp.tracker.ui.LaterCharacterFrame.frame), "CreateGui hooks do nothing while the skin is off")
	K.Options.Write("Skins", "restedXP.enabled", true)
	env.RunTimers()
	NewCheck(Glass(K, rxp.tracker.ui.LaterCharacterFrame.frame), "enabling the skin reaches every report created while off")
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
	assert(K.Skin.Parts(ui.frame).backdrop.inset.top == -K.Tokens.Size("gapMedium"), "its glass rises a medium gap over the window: RestedXP hangs the title 1 under the frame's top (GuideConfigurator.lua 485), where its capitals would touch the rim")
	-- The title and the buttons use the kit's text roles: the title a caps caption in the picture's muted gold, as
	-- every window title is since the Captain's ruling of 2026-11-10 (it was the title role in the emphasised text
	-- before); each button label in the body role in the kit button's own text colour (the kit paints it on every show,
	-- hover and enable, so a colour of the skin's own lasted only until the first of those), and RestedXP's own flat button wash
	-- hushed; RestedXP's UpdateTheme re-fonts all of them from its theme, so the skin applies the roles again after it.
	local function Roles()
		Capped(K, ns, ui.titletext, "the guide configurator")
		for _, key in ipairs({ "backbutton", "resetbutton", "submitbutton" }) do
			local button = ui[key]
			assert(K.Skin.IsSkinned(button, "Button") and Alpha(button.configuratorBackground) == 0 and Alpha(button.rxpBorder.textures[1]) == 0, key .. " is a KstyleUI button")
			local label = button:GetFontString()
			assert(label:GetFont() == (ns.Style.Font("body")) and FontSize(K, label, select(2, label:GetFont()), select(2, ns.Style.Font("body"))), key .. "'s label is in the body role, got " .. tostring(select(2, label:GetFont())))
			assert(Colored(label, K.Tokens.Color("text")), key .. "'s label is the kit button's text colour")
		end
	end
	Roles()
	NewCheck(ui.description:GetFont() == (ns.Style.Font("body")), "configurator description uses the body face")
	local closeCount, headerCount = 0, 0
	for _, child in ipairs({ ui.frame:GetChildren() }) do
		if child:GetObjectType() == "Button" and child:GetNormalTexture() then
			if tostring(child:GetNormalTexture():GetTexture()):find("rxp%-btn%-close") then
				if K.Skin.IsSkinned(child, "CloseButton") then closeCount = closeCount + 1 end
			elseif K.Skin.IsSkinned(child, "Button") then headerCount = headerCount + 1 end
		end
	end
	NewCheck(closeCount == 1, "configurator anonymous close button is skinned")
	NewCheck(headerCount == 3, "configurator settings import and help buttons are skinned")
	configurator:UpdateTheme()
	Roles()
	assert(K.Skin.IsSkinned(ui.scrollContainer.scrollbar, "ScrollBar"))
	local intro = ui.scrollContainer.children[1]
	local introTitle, introDescription = Replacement(intro.titleLabel.label), Replacement(intro.descriptionLabel.label)
	NewCheck(introTitle and introDescription and introTitle:GetFont() == (ns.Style.Font("body")) and introDescription:GetFont() == (ns.Style.Font("body")), "configurator page intro labels use kit faces")
	rxp.fake.close(intro.titleLabel.frame)
	if introTitle then NewCheck(intro.titleLabel.label:GetAlpha() == 1 and not introTitle:GetParent():IsShown(), "released configurator labels return their own font and visibility") end
	-- The option rows (RXPV2GuideConfiguratorOption widgets, some inside padding containers): each row sits on
	-- a surface tile, its check is the kit's Lumen ring (gilt fill while checked) in place of RestedXP's cyan
	-- square, its label is in the body role, and its "Recommended" line takes the accent role, not RestedXP's
	-- cyan (round 5, Opus #4). RestedXP re-renders the rows on every page, so the skin follows the container's
	-- layout, and a later theme redraw keeps the treatment.
	local options = Fake.ConfiguratorOptions(ui)
	assert(#options == 3, "the fake renders three option rows, got " .. #options)
	local function Rows()
		for i, option in ipairs(options) do
			assert(Glass(K, option.frame), "option " .. i .. " sits on a tile")
			assert(Alpha(option.frame.configuratorBackground) == 0 and Alpha(option.frame.rxpBorder.textures[1]) == 0, "RestedXP's row wash and border go")
			local ring = ns.Lumen.RingOf(option.checkbg)
			assert(ring, "option " .. i .. " wears a Lumen ring check")
			assert(Alpha(option.checkbg.configuratorBackground) == 0 and Alpha(option.checkedFill[1]) == 0 and Alpha(option.checkShort) == 0, "RestedXP's square and its cyan fill go")
			assert(ring.fill:IsShown() == (option.checked == true), "the ring shows the option's state: " .. tostring(option.checked))
			if option.checked then
				local fr, fg, fb = ring.fill:GetVertexColor()
				local gr, gg, gb = ns.Lumen.Color("gilt")
				assert(W.Near(fr, gr) and W.Near(fg, gg) and W.Near(fb, gb), "the checked fill is gilt")
			end
			assert(option.text:GetFont() == (ns.Style.Font("body")), "the label is in the body role")
			if option.recommendation:IsShown() then
				assert(Accented(ns, option.recommendation), "the Recommended line takes the accent")
				assert(option.recommendation:GetFont() == (ns.Style.Font("caption")), "in the caption role")
			end
		end
	end
	Rows()
	K.Options.Write("Skins", "restedXP.enabled", false)
	options[1]:SetChecked(false)
	NewCheck(ns.Lumen.RingOf(options[1].checkbg).fill:IsShown(), "option hooks do not repaint while the skin is off")
	K.Options.Write("Skins", "restedXP.enabled", true)
	env.RunTimers()
	NewCheck(not ns.Lumen.RingOf(options[1].checkbg).fill:IsShown(), "reenabling resynchronizes existing configurator option rings")
	options[1]:SetChecked(true)
	assert(options[1].checked and options[1].recommendation:IsShown() and not options[3].checked, "the fake's first option is checked and recommended, the third unchecked")
	options[1]:SetChecked(false)
	assert(not ns.Lumen.RingOf(options[1].checkbg).fill:IsShown(), "unchecking the option empties the ring")
	options[1]:SetChecked(true)
	configurator:UpdateTheme()
	Rows()
	-- A new page renders new rows; the skin reaches them as RestedXP lays the container out.
	configurator:LoadPages()
	local again = Fake.ConfiguratorOptions(ui)
	assert(again[1] ~= options[1], "the page re-rendered its rows")
	options = again
	Rows()

	rxp.guideImporter:Open()
	local widgets = rxp.guideImporter.widgets
	assert(Glass(K, widgets.import.frame) and Hushed(widgets.import.frame), "the guide importer is skinned when it is made")
	assert(K.Skin.Parts(widgets.import.frame).backdrop.inset.top == -K.Tokens.Size("gapMedium"), "its glass rises a medium gap over the window too: RestedXP hangs the title 4 under the frame's top (GuideImporter.lua 273)")
	assert(K.Skin.IsSkinned(widgets.import.closebutton, "CloseButton"))
	local function InCorner(button, owner, what)
		local point, on, onPoint, x, y = button:GetPoint(1)
		assert(point == "TOPRIGHT" and on == owner and onPoint == "TOPRIGHT" and x == 0 and y == 0, what .. ": the close button stands in the window's corner, inside the glass; RestedXP hangs it 6 off the corner (GuideImporter.lua 271, Core.lua 200), got " .. tostring(x) .. ", " .. tostring(y))
	end
	InCorner(widgets.import.closebutton, widgets.import.frame, "importer")
	for _, key in ipairs({ "purgeConfirmation", "deleteConfirmation" }) do
		local found
		for _, child in ipairs({ widgets[key].frame:GetChildren() }) do
			if K.Skin.IsSkinned(child, "CloseButton") then
				found = child
			end
		end
		InCorner(assert(found, key .. " has a kit close button"), widgets[key].frame, key)
	end
	Capped(K, ns, widgets.import.title, "the guide importer")
	assert(K.Skin.IsSkinned(widgets.importButton.frame, "Button") and K.Skin.IsSkinned(widgets.deleteButton.frame, "Button"))
	assert(K.Skin.IsSkinned(widgets.importBox.editBox, "EditBox") and Alpha(widgets.importBox.background.rxpBackground.textures[1]) == 0, "the import box is a KstyleUI edit box")
	for _, key in ipairs({ "importLabel", "guidesLabel", "progressLabel", "progressText", "history" }) do
		NewCheck(widgets[key]:GetFont() == (ns.Style.Font("caption")), "importer " .. key .. " uses the caption face")
	end
	NewCheck(widgets.import.description:GetFont() == (ns.Style.Font("body")), "importer description uses the body face")
	NewCheck(Proxy(K, widgets.currentGuides.frame, "EditBox") ~= nil and widgets.currentGuides.text:GetAlpha() == 0, "importer dropdown is temporarily dressed")
	rxp.fake.close(widgets.import.frame)
	local dropdownPanel = Proxy(K, widgets.currentGuides.frame, "EditBox")
	if dropdownPanel then NewCheck(not dropdownPanel:IsShown() and widgets.currentGuides.text:GetAlpha() == 1, "importer returns shared dropdown chrome on hide") end
	rxp.fake.open(widgets.import.frame)
	NewCheck(dropdownPanel and dropdownPanel:IsShown() and widgets.currentGuides.text:GetAlpha() == 0, "importer redresses the shared dropdown on show")
	-- The kit hushes every region of a button it skins again whenever the button shows (Core/Skin.lua, StripOwn), so
	-- the arrow drawn over the dropdown's kit button lives on a frame of its own, as the icon controls' does.
	do
		local arrow = Proxy(K, widgets.currentGuides.button, "Button")
		local drawn
		for _, holder in ipairs(arrow and { arrow:GetChildren() } or {}) do
			for _, region in ipairs({ holder:GetRegions() }) do
				if region.GetTexture and tostring(region:GetTexture()):find("scrollbar_down", 1, true) then drawn = region end
			end
		end
		NewCheck(drawn and drawn:GetAlpha() == 1 and drawn:IsShown(), "the importer dropdown's arrow is still drawn over its kit button after the window shows again")
	end
	NewCheck(Accented(ns, { GetTextColor = function() return widgets.progress:GetStatusBarColor() end }), "importer progress uses the accent")
	widgets.import:UpdateSubTheme()
	Capped(K, ns, widgets.import.title, "the guide importer after RestedXP redraws its theme")
	NewCheck(widgets.import.frame.importerBody:GetAlpha() == 0 and widgets.import.frame.importerHeader:GetAlpha() == 0, "importer body and header stay hushed after redraw")
	for _, key in ipairs({ "purgeConfirmation", "deleteConfirmation" }) do
		local popup = widgets[key]
		assert(Glass(K, popup.frame) and K.Skin.IsSkinned(popup.buttons[1], "Button"), key .. " is a KstyleUI dialog")
		assert(popup.frame.rxpBackground, "OnAcquire applies the popup's RestedXP backdrop after its bare constructor")
		Capped(K, ns, popup.title, key)
		NewCheck(popup.message:GetFont() == (ns.Style.Font("body")), key .. " message uses the body face")
		popup:Show()
		Capped(K, ns, popup.title, key .. " after its theme redraw on show")
		NewCheck(popup.message:GetFont() == (ns.Style.Font("body")), key .. " theme redraw on show preserves the body face")
		local closes = 0
		for _, child in ipairs({ popup.frame:GetChildren() }) do if K.Skin.IsSkinned(child, "CloseButton") then closes = closes + 1 end end
		NewCheck(closes == 1, key .. " anonymous close button is skinned")
	end
	Clean(env, rxp)
end

-- The feedback form and the export box: AceGUI frames that other addons may use after RestedXP --------------------

do
	local env, K, ns, rxp = Boot()
	local previous
	for _, key in ipairs({ "OpenBugReport", "OpenBrandedExport" }) do
		if key == "OpenBugReport" then rxp.comms.OpenBugReport({ arg1 = 12 })
		else rxp.comms.OpenBrandedExport("Test export", "Copy this text", "Export content", 480, 240, function() end) end
		local frame = key == "OpenBugReport" and env.RESTEDXP_BUG_REPORT_WINDOW or env.RESTEDXP_BRANDED_EXPORT
		local title = frame.obj.titletext
		-- AceGUI makes the title on GameFontNormal (AceGUIContainer-Frame.lua:236), Friz Quadrata at 12.
		local titleOwn = { "Fonts\\FRIZQT__.TTF", 12 }
		if previous then assert(previous ~= frame, "feedback does not release its AceGUI frame on close") end
		previous = frame
		local panel = ns.RestedXP.Chrome.DressPanel(frame)
		assert(panel and panel:IsShown(), "RestedXP's dialog sits on glass while RestedXP shows it")
		local panelPoint, panelOn, _, _, panelY = panel:GetPoint(1)
		assert(panelPoint == "TOPLEFT" and panelOn == frame and W.Near(panelY, K.Widgets.Snap(panel, K.Tokens.Size("gapMedium"))), "the dialog's glass rises a medium gap over AceGUI's title too, got " .. tostring(panelY))
		assert(Alpha(frame._pieces[1]) == 0 and Alpha(frame.obj.titlebg) == 0, "its backdrop and title art are hidden")
		local replacement = Replacement(title)
		NewCheck(replacement and replacement:GetFont() == (ns.Style.Font("caps")) and Colored(replacement, K.Tokens.Color("capsGold")), key .. " title is a caps caption in the muted gold while leased")
		NewCheck(replacement and replacement:GetText() == K.Locale.Upper(title:GetText()), key .. " title reads in capitals")
		local titleFont, titleSize = title:GetFont()
		NewCheck(replacement and titleFont == (replacement:GetFont()) and titleSize == select(2, replacement:GetFont()), key .. " title's own text measures as its caption while leased")
		local child = frame.obj.children[1]
		local edit = child.type == "ScrollFrame" and child.children[1] or child
		assert(edit.type == "MultiLineEditBox" and edit.editBox:GetParent() == edit.scrollFrame)
		local oldFont = "Fonts\\ARIALN.TTF"
		NewCheck(edit.editBox:GetFont() == (ns.Style.Font("body")), key .. " edit text uses the body face while leased")
		NewCheck(Proxy(K, edit.editBox, "EditBox") ~= nil and Proxy(K, edit.button, "Button") ~= nil and Proxy(K, edit.scrollBar, "ScrollBar") ~= nil, key .. " edit box accept button and scroll bar use temporary kit chrome")
		local label = Replacement(edit.label)
		NewCheck(label and label:GetFont() == (ns.Style.Font("body")), key .. " edit label uses the body face while leased")
		NewCheck(label and edit.label:GetFont() == (label:GetFont()) and select(2, edit.label:GetFont()) == select(2, label:GetFont()), key .. " edit label's own text measures as the label drawn over it while leased")
		local accept = Replacement(edit.button:GetFontString())
		NewCheck(accept and accept:GetNumPoints() == 1 and W.LastCall(accept, "SetWordWrap")[1] == false, key .. " accept button's label hangs on one point and never wraps, so the button's own narrower text cannot cut it")
		NewCheck(edit.button:GetFontString():GetFont() == "Fonts\\FRIZQT__.TTF", key .. " accept button's own text keeps the font its button states give it")
		-- AceGUI disables Accept until the text is edited (AceGUIWidget-MultiLineEditBox.lua, DisableButton): the kit
		-- button drawn over it and its label follow, so a button that cannot be pressed does not look as if it can.
		do
			local over = Proxy(K, edit.button, "Button")
			NewCheck(over and over:IsEnabled() and accept and Colored(accept, K.Tokens.Color("text")), key .. " accept button's label is the kit button's text colour while it can be pressed")
			edit.button:Disable()
			NewCheck(over and not over:IsEnabled() and accept and Colored(accept, K.Tokens.Color("textDisabled")), key .. " a disabled accept button's kit chrome and label are disabled too")
			edit.button:Enable()
			NewCheck(over and over:IsEnabled() and accept and Colored(accept, K.Tokens.Color("text")), key .. " and enabled again with it")
		end
		K.Options.Write("Skins", "text.size", 1.5)
		env.RunTimers()
		NewCheck(select(2, edit.editBox:GetFont()) == select(2, ns.Style.Font("body")), key .. " edit text follows a text size change while leased, got " .. tostring(select(2, edit.editBox:GetFont())) .. " for " .. tostring(select(2, ns.Style.Font("body"))))
		K.Options.Write("Skins", "text.size", 1)
		env.RunTimers()
		rxp.fake.close(frame)
		assert(not panel:IsShown() and Alpha(frame._pieces[1]) == 1 and Alpha(frame.obj.titlebg) == 1, "closing it gives the shared frame its own look back")
		local r, g, b = title:GetTextColor()
		assert(W.Near(r, 1) and W.Near(g, 0.82) and W.Near(b, 0), "and its title keeps its own colour")
		NewCheck(title:GetFont() == titleOwn[1] and select(2, title:GetFont()) == titleOwn[2], key .. " title's own font is returned on hide, got " .. tostring(title:GetFont()))
		NewCheck(edit.editBox:GetFont() == oldFont, key .. " edit font is returned on hide")
		NewCheck(edit.label:GetFont() == "Fonts\\FRIZQT__.TTF" and select(2, edit.label:GetFont()) == 10, key .. " edit label's own font is returned on hide, got " .. tostring(edit.label:GetFont()) .. " " .. tostring(select(2, edit.label:GetFont())))
		NewCheck(edit.label:GetAlpha() == 1 and edit.scrollBar:GetThumbTexture():GetAlpha() == 1 and edit.button.Left:GetAlpha() == 1, key .. " original label button and thumb art are returned on hide")
		local proxy = Proxy(K, edit.editBox, "EditBox")
		if proxy then NewCheck(not proxy:IsShown(), key .. " temporary controls hide on release") end
		K.Options.Write("Skins", "text.size", 1.2)
		env.RunTimers()
		NewCheck(edit.editBox:GetFont() == oldFont, key .. " released edit font stays untouched by later skin restyles")
		K.Options.Write("Skins", "text.size", 1)
		env.RunTimers()
	end
	local frame = env.RESTEDXP_BRANDED_EXPORT
	assert(not K.Skin.IsSkinned(frame, "Backdrop"), "the shared frame is never skinned for good")
	rxp.fake.open(frame)
	assert(Alpha(frame._pieces[1]) == 1, "another addon showing the frame sees its own look")
	frame._pieces[1]:SetAlpha(0.5)
	rxp.fake.close(frame)
	assert(Alpha(frame._pieces[1]) == 0.5, "and KstyleUI leaves it alone when that addon hides it")
	local export = frame
	rxp.comms.OpenBrandedExport("Again", "Still editable", "Content", nil, nil, function() end)
	assert(env.RESTEDXP_BRANDED_EXPORT == export, "AceGUI reuses the frame released by the export box")
	local edit = export.obj.children[1]
	NewCheck(Proxy(K, edit.editBox, "EditBox") and Proxy(K, edit.editBox, "EditBox"):IsShown(), "a pooled edit widget is redressed on RestedXP reuse")
	rxp.fake.close(export)
	Clean(env, rxp)
end

-- RestedXP's quest log button, made after login ---------------------------------------------------------------------

do
	local env, K, _, rxp = Boot()
	assert(rxp.CreateCleanupButton == nil and rxp.cleanupBtn == nil, "the real cleanup constructor is local and runs after the event")
	env.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	env.RunTimers()
	local button = rxp.cleanupBtn
	assert(button and button:GetParent() == env.QuestMapFrame.DetailsFrame and env.RXPQuestLogCleanupButton == button, "cleanup uses the quest detail parent and real global name")
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

assert(#newFailures == 0, table.concat(newFailures, "\n"))
print("skins restedxp windows ok")
