-- test-skins-restedxp-rest.lua: the RestedXP guide at rest, as the owner's picture draws it (LEE-20): the active steps are plain lines under the cap's title in the quest lines' size, RestedXP's default colours swapped for KstyleUI's and its inline icons dropped, the check rings shown only under the pointer; in the story rail the footer's cog and grip rest through everything RestedXP does to them, the quests start right under the last step with no footer band between, a timer bar brings the band back while it runs, a right click on the cap opens RestedXP's menu, and RestedXP's own save of its windows never takes the rail's placement; the arrow's text and the icon frames' titles read in KstyleUI's faces.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")
local W = S.W

local HOOKED = {
	SetAlpha = true, SetChecked = true, SetFont = true, SetText = true, UpdateVisuals = true, SetMinMaxValues = true,
	SetStep = true, UpdateText = true, SortTimers = true, SetStatusBarColor = true, DoLayout = true,
}

-- The owner's live step (Guides/forever/RestedXP-Skyborne.lua 1220-1221): a line of text with an inline icon, a
-- colour token and an npc id, then a trainer line with its tag icon.
local STEP = {
	{
		title = "Step 134",
		elements = {
			{ text = "|Tinterface/worldmap/chatbubble_64grey.blp:20|tTalk to |cRXP_FRIENDLY_Aarnor Galestrike::254082|r", textOnly = true },
			{ text = "Train your class spells", tag = "train" },
		},
	},
}

local function Sized(size)
	return { version = 9, profiles = { Default = { Appearance = { uiScale = size } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

-- Boot(opts) -> env, K, ns, rxp at the shipped Interface size, Skins on. opts.quests tracks that many quests and
-- loads Blizzard's tracker, so the quest card shares the story slot with the guide; opts.measure gives the font
-- strings the kit fonts' glyph widths, so a line wraps where the game wraps it.
local function Boot(opts)
	opts = opts or {}
	local rxp
	local env, K, ns = S.New({
		saved = Sized(16 / 19),
		setup = function(env)
			if opts.quests then
				Quests.Install(env, Quests.List(opts.quests))
			end
			if opts.measure then
				env._textWidth = Measure.TextWidth
			end
			rxp = Fake.Install(env, {})
		end,
		before = function(env)
			if opts.quests then
				Quests.Tracker(env, S.Blizzard(env))
			end
		end,
	})
	K.Modules.Enable("Skins")
	if opts.quests then
		S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	end
	env.RunTimers()
	W.Settle(env)
	return env, K, ns, rxp
end

local function Rect(K, object)
	local env = K.Scale.Root()._env
	local r = assert(Geometry.Rect(object, env.UIParent))
	local s = env.UIParent:GetEffectiveScale() / K.Scale.Root():GetEffectiveScale()
	return { left = r.left * s, right = r.right * s, bottom = r.bottom * s, top = r.top * s }
end

-- CardRect(card) -> the quest card's top and bottom in root units: it hangs from the root's bottom left.
local function CardRect(card)
	local point, _, relativePoint, _, top = card:GetPoint(1)
	assert(point == "TOPLEFT" and relativePoint == "BOTTOMLEFT", "the quest card hangs from the root's bottom left")
	return { top = top, bottom = top - card:GetHeight() }
end

local function near(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tolerance or 0.6)
end

local function Clean(env, K, rxp)
	rxp.fake.check(HOOKED)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	local failed = S.Logged(env, "could not be restyled")
	assert(not failed, tostring(failed))
end

local function Hover(step, over)
	step._mouseOver = over
	step:GetScript(over and "OnEnter" or "OnLeave")(step)
end

local function Hex(K, token)
	local r, g, b = K.Tokens.Color(token)
	return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- The steps read as the picture's plain lines ---------------------------------------------------------------------

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	rxp.fake.guide(STEP)
	rxp.SetStep()
	env.RunTimers()
	local step = f.CurrentStepFrame.framePool[1]
	local talk, train = step.elements[1], step.elements[2]
	local path = ns.RestedXP.Chrome.Path(f)

	-- The words: no inline icon, no npc id, the name in KstyleUI's friend green.
	local line = talk.text:GetText()
	assert(not line:find("|T", 1, true), "RestedXP's inline icon is dropped from the step's text, got " .. line)
	assert(line == "Talk to " .. Hex(K, "friend") .. "Aarnor Galestrike|r", "the name is drawn in KstyleUI's friend green, not RestedXP's FF00FF25, got " .. line)
	assert(train.text:GetText() == "Train your class spells", "a plain line is left as it is")
	assert(train.icon:GetAlpha() == 0, "the element's tag icon rests: the picture's lines carry no icons")
	-- A colour the player picked in RestedXP is not one of its defaults: it stays.
	rxp.guideTextColors.RXP_FRIENDLY_ = "FF123456"
	rxp.SetStep()
	env.RunTimers()
	assert(talk.text:GetText():find("|cFF123456", 1, true), "a colour the player set in RestedXP stays, got " .. talk.text:GetText())
	rxp.guideTextColors.RXP_FRIENDLY_ = "FF00FF25"
	rxp.SetStep()
	env.RunTimers()
	for token, hex in pairs({ friend = "FF00FF25", hostile = "FFFF5722", magic = "FF00BCD4", quest = "FFFCDC00" }) do
		train.text:SetText("Kill |c" .. hex .. "them|r")
		assert(train.text:GetText() == "Kill " .. Hex(K, token) .. "them|r", "RestedXP's default " .. hex .. " reads in KstyleUI's " .. token)
	end
	train.text:SetText("Buy |cFF0E8312bread|r")
	assert(train.text:GetText() == "Buy |cFF0E8312bread|r", "a colour with no KstyleUI counterpart is left alone")
	rxp.SetStep()
	env.RunTimers()

	-- The size: the story card's one text size, 13 root units (23 px on the owner's screen, the picture's lines),
	-- the same pixels as the quest card's lines although RestedXP's window has its own scale.
	local _, size = talk.text:GetFont()
	local story = ns.Lumen.TEXT_SIZE / K.Widgets.ScaleFactor(talk)
	assert(ns.Lumen.TEXT_SIZE == 13 and K.Widgets.ScaleFactor(talk) > 1, "the guide's window is not at the root's scale in this boot, so the test can tell the two units apart")
	assert(near(size, K.Widgets.FontSize(talk.text, math.max(11, story)), 1e-6), "a step reads at the quest lines' size or at RestedXP's own (guideFontSize + 2 = 11) when that is larger, got " .. tostring(size) .. " for " .. tostring(story))
	local face = talk.text:GetFont()
	talk.text:SetFont(face, 5, "")
	local _, floor = talk.text:GetFont()
	assert(near(floor, K.Widgets.FontSize(talk.text, story), 1e-6), "under a smaller RestedXP font the step reads at the story card's size, got " .. tostring(floor))
	assert(math.abs(floor * K.Widgets.ScaleFactor(talk) - ns.Lumen.TEXT_SIZE) <= K.Scale.Pixel(1), "which is a quest line's height on screen, to the pixel, got " .. tostring(floor * K.Widgets.ScaleFactor(talk)))
	talk.text:SetFont(face, 11, "")
	assert(talk.text:GetFont() == (ns.Style.Font("body")), "in the body face")

	-- The place: the text starts under the cap's title, and the check sits left of it in the gem's column.
	local cap = path.cap
	local gemX = select(4, cap.gem:GetPoint(1))
	local titleX = select(4, cap.title:GetPoint(1))
	local want = gemX + cap.gem:GetWidth() + titleX
	for _, element in ipairs(step.elements) do
		local point, relative, relativePoint, x, y = element.text:GetPoint(1)
		assert(point == "TOPLEFT" and relative == element and relativePoint == "TOPLEFT", "a step's text hangs from its own row")
		assert(near(x, want, 0.01) and near(y, -K.Widgets.Snap(f.CurrentStepFrame, 2), 0.01), "it starts where the cap's title starts, got " .. tostring(x) .. " for " .. tostring(want))
		local _, _, _, cx = element.button:GetPoint(1)
		assert(cx + element.button:GetWidth() < x, "its check sits left of the text, got " .. tostring(cx))
	end
	local holder = path.holder._points[1]
	assert(holder[2] == f.CurrentStepFrame and near(holder[5], -K.Widgets.Snap(path.holder, 12), 0.01), "the cap reads right over the first line: its holder stands 12 inside the step frame's empty head")
	-- RestedXP lays the steps out again whenever a line changes (CurrentStepFrame.UpdateText): the place holds.
	f.CurrentStepFrame.UpdateText()
	assert(near(select(4, talk.text:GetPoint(1)), want, 0.01) and select(2, talk.text:GetPoint(1)) == talk, "RestedXP's own layout pass leaves the text under the title")
	local function LineHeight(text)
		return math.ceil(select(2, text:GetFont()) * 1.1) + 1
	end
	assert(talk:GetHeight() == LineHeight(talk.text) and step:GetHeight() == talk:GetHeight() + train:GetHeight() + 18, "and the rows keep RestedXP's own heights: a line's height times 1.1 plus 1, a step its lines plus 18")

	-- The checks: RestedXP's check buttons are KstyleUI rings, unseen until the pointer is over the step.
	assert(ns.Lumen.RingOf(train.button), "the check is a Lumen ring")
	assert(train.button:GetAlpha() == 0, "the ring rests unseen: the picture's steps have no circles")
	Hover(step, true)
	assert(train.button:GetAlpha() == 1, "the pointer over the step shows its ring, so a click on it is a seen click")
	Hover(step, false)
	assert(train.button:GetAlpha() == 0, "and it rests again when the pointer leaves")
	step._mouseOver = true
	train:GetScript("OnEnter")(train)
	assert(train.button:GetAlpha() == 1, "the pointer over a line of the step counts")
	step._mouseOver = false
	train:GetScript("OnLeave")(train)
	assert(train.button:GetAlpha() == 0)
	step._mouseOver = env.Secret(true)
	step:GetScript("OnEnter")(step)
	assert(train.button:GetAlpha() == 0, "a secret answer about the pointer shows nothing and raises nothing")
	step._mouseOver = false
	Clean(env, K, rxp)
end

-- In the story rail the footer rests ------------------------------------------------------------------------------

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	local footer = f.Footer
	local cog, grip = footer.cog, footer.icon
	rxp.SetStep(1, 2)
	env.RunTimers()
	assert(ns.RestedXP.Rail.Placed(), "the rail holds the guide")
	local function Rested(what)
		assert(cog:GetAlpha() == 0 and grip:GetAlpha() == 0 and footer.text:GetAlpha() == 0, what .. ": the cog, the grip and the version line rest, got " .. cog:GetAlpha() .. ", " .. grip:GetAlpha() .. ", " .. footer.text:GetAlpha())
	end
	Rested("placed")
	-- Everything RestedXP does to its footer, by its own code (GuideWindow.lua 52-82, 140-181; Timers.lua 18-25,
	-- 112-121, 174-176; Themes.lua's reload): none of it brings the footer back.
	f:UpdateVisuals()
	Rested("after UpdateVisuals")
	rxp.SetupGuideWindow()
	Rested("after RestedXP writes its header and footer")
	rxp:ReloadTheme()
	Rested("after a theme reload")
	rxp.StartTimer(30, "Hearthstone")
	env.RunTimers()
	Rested("while a timer bar runs")
	rxp.fake.expire("Hearthstone")
	env.RunTimers()
	Rested("after the last timer bar runs out and RestedXP sets all three to 1")
	rxp.StartTimer(30, "Flight")
	rxp.StopTimer("Flight")
	rxp.HideTimers()
	env.RunTimers()
	Rested("after StopTimer and HideTimers")
	-- At rest nothing unseen takes a click: the cog and the grip under the quests' cap would open a menu or size the
	-- window, and RestedXP's window and footer would drag the guide off the rail.
	for name, frame in pairs({ cog = cog, grip = grip, footer = footer, window = f }) do
		assert(not frame:IsMouseEnabled(), "the resting " .. name .. " takes no mouse")
	end
	assert(f.CurrentStepFrame:IsMouseEnabled() and f.GuideName:IsMouseEnabled(), "the steps and the route row keep RestedXP's drag and menu")
	-- RestedXP's menu stays one click away: a right click on the cap runs RestedXP's own header handler.
	local path = ns.RestedXP.Chrome.Path(f)
	assert(path.holder:IsMouseEnabled(), "the cap takes clicks")
	path.holder:GetScript("OnMouseUp")(path.holder, "LeftButton")
	assert(not rxp.menuLists[1]:IsShown(), "a left click on the cap opens nothing")
	path.holder:GetScript("OnMouseUp")(path.holder, "RightButton")
	assert(rxp.menuLists[1]:IsShown(), "a right click on the cap opens RestedXP's menu")
	rxp.fake.close(rxp.menuLists[1])

	-- Off the rail the footer is RestedXP's again, with what RestedXP last asked of it.
	K.Options.Write("Skins", "restedXP.rail", false)
	env.RunTimers()
	assert(cog:GetAlpha() == 1 and grip:GetAlpha() == 1, "off the rail the cog and the grip show again")
	assert(footer.text:GetAlpha() == 0, "the version line stays hushed: the cap names the guide")
	for name, frame in pairs({ cog = cog, grip = grip, footer = footer, window = f }) do
		assert(frame:IsMouseEnabled(), "off the rail the " .. name .. " takes the mouse again")
	end
	rxp.StartTimer(30, "Hearthstone")
	assert(cog:GetAlpha() == 0, "and RestedXP's timer bar hides them as ever")
	K.Options.Write("Skins", "restedXP.rail", true)
	env.RunTimers()
	K.Options.Write("Skins", "restedXP.rail", false)
	env.RunTimers()
	assert(cog:GetAlpha() == 0, "a rest that began under a timer bar gives back RestedXP's own 0")
	rxp.fake.expire("Hearthstone")
	assert(cog:GetAlpha() == 1 and grip:GetAlpha() == 1)
	Clean(env, K, rxp)
end

-- RestedXP's own save never takes the rail's placement -----------------------------------------------------------

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	local profile = rxp.settings.profile
	rxp.SetStep(1)
	env.RunTimers()
	assert(ns.RestedXP.Rail.Placed() and select(1, f:GetPoint(1)) == "TOPLEFT", "the rail holds the guide")
	assert(f.savePosition == false, "while it does, the guide carries RestedXP's own savePosition switch (SettingsPanel.lua 4343)")
	-- PLAYER_LOGOUT (RXPGuides.lua 1831), and every mouse-up on a RestedXP window (GuideWindow.lua 425, map.lua 91,
	-- ActiveItemFrame.lua 288), save every enabled frame.
	rxp.fake.logout()
	assert(profile.framePositions.RXPFrame == nil and profile.frameSizes.RXPFrame == nil, "RestedXP's logout save skips the guide: the rail's place and its 28-unit height stay out of the saved settings")
	assert(profile.framePositions.arrowFrame and profile.framePositions.activeItemFrame, "and saves its other windows as ever")
	f:GetScript("OnMouseUp")(f, "LeftButton")
	rxp.arrowFrame:GetScript("OnMouseUp")(rxp.arrowFrame, "LeftButton")
	env.RunTimers()
	assert(ns.RestedXP.Rail.Placed() and profile.framePositions.RXPFrame == nil, "a click on the guide, or a drag of the arrow, saves nothing of the rail's either")
	assert(profile.frameHeight == nil, "and no height")
	-- Off the rail the guide is back at RestedXP's place and RestedXP saves it again.
	K.Options.Write("Skins", "restedXP.rail", false)
	env.RunTimers()
	assert(f.savePosition == nil, "off the rail the switch is gone")
	rxp.fake.logout()
	local saved = profile.framePositions.RXPFrame
	assert(saved and saved[1][1] == "LEFT" and saved[1][4] == 0 and saved[1][5] == 35, "and RestedXP saves the guide's own place")
	assert(profile.frameSizes.RXPFrame[1] == 235 and profile.frameSizes.RXPFrame[2] == 125, "at its own size")
	-- A player's drag wins: the rail lets go, and the next save is the player's place.
	K.Options.Write("Skins", "restedXP.rail", true)
	env.RunTimers()
	assert(f.savePosition == false)
	f:ClearAllPoints()
	f:SetPoint("CENTER", env.UIParent, "CENTER", 120, 0)
	f.CurrentStepFrame:GetScript("OnMouseUp")(f.CurrentStepFrame, "LeftButton")
	env.RunTimers()
	assert(ns.Skins.Setting("restedXP", "rail") == false and f.savePosition == nil, "a drag turns the rail off and hands the saving back")
	rxp.fake.logout()
	saved = profile.framePositions.RXPFrame
	assert(saved[1][1] == "CENTER" and saved[1][4] == 120, "so RestedXP saves where the player put it")
	Clean(env, K, rxp)
end

-- One card with the quests: no footer band between the last step and the quests ----------------------------------

do
	local env, K, ns, rxp = Boot({ quests = 4 })
	local f = rxp.RXPFrame
	rxp:LoadGuide({ name = "1-9 Skyborne", subgroup = "Speedrun Guide 1-22" })
	rxp.fake.guide(STEP)
	rxp.SetStep()
	env.RunTimers()
	W.Settle(env)
	assert(ns.Quests.Active() and ns.RestedXP.Rail.Placed() and ns.RestedXP.Rail.Docked(), "the quest card docks into the guide's card")
	local story = K.Setup.Story("DPS", true)
	local path = ns.RestedXP.Chrome.Path(f)
	assert(not path.meta:IsShown(), "the guide's group line is hushed, so the steps are the guide's last row")
	local glass = Rect(K, K.Skin.Parts(f).backdrop)
	local steps = Rect(K, f.CurrentStepFrame)
	local quests = CardRect(ns.Quests.Card())
	assert(near(glass.top, story.story.top, 0.01), "the card starts on the slot's top, to the pixel, got " .. glass.top .. " for " .. story.story.top)
	assert(near(quests.top, steps.bottom, 1), "the quests start right under the last step: RestedXP's footer band is gone from the resting card, got " .. quests.top .. " under " .. steps.bottom)
	assert(near(f:GetHeight(), 28, 0.01), "RestedXP's window is folded to its floor behind the quests' cap")
	local foot = path.card._points[3]
	assert(foot[1] == "BOTTOM" and foot[2] == ns.Quests.Card() and not ns.Quests.Parts().glass:IsShown(), "one glass from the guide's cap to the quests' foot; the quest card's own glass yields")
	assert(quests.bottom >= story.story.bottom - 0.5, "the quests end inside the slot, got " .. quests.bottom .. " for " .. story.story.bottom)
	local shown = 0
	for _, row in ipairs(ns.Quests.Rows()) do
		if row:IsShown() then
			shown = shown + 1
		end
	end
	assert(shown == 4, "the picture's four quests fit under the guide's two lines, got " .. shown)

	-- A RestedXP timer bar draws on the footer (Timers.lua 14-16): while one runs the band is back, under the steps.
	rxp.StartTimer(30, "Hearthstone")
	env.RunTimers()
	W.Settle(env)
	local footer = Rect(K, f.Footer)
	quests = CardRect(ns.Quests.Card())
	assert(f:GetHeight() > 28 and quests.top <= footer.bottom + 0.5, "a running timer bar has the footer's row to itself: the quests start under it, got " .. quests.top .. " for " .. footer.bottom)
	rxp.fake.expire("Hearthstone")
	env.RunTimers()
	W.Settle(env)
	assert(near(CardRect(ns.Quests.Card()).top, Rect(K, f.CurrentStepFrame).bottom, 1) and near(f:GetHeight(), 28, 0.01), "and when it runs out the band closes again")

	-- A guide whose own name runs to two lines keeps its route row: the quests start under that row.
	rxp.currentGuide = { name = "Elwynn Forest\\n1-10 Human" }
	f.GuideName.text:SetText("Elwynn Forest\n1-10 Human")
	env.RunTimers()
	W.Settle(env)
	assert(path.meta:IsShown(), "the route row shows")
	assert(near(CardRect(ns.Quests.Card()).top, Rect(K, f.GuideName).bottom, 1), "the quests start right under the route row, got " .. CardRect(ns.Quests.Card()).top .. " under " .. Rect(K, f.GuideName).bottom)
	Clean(env, K, rxp)
end

-- The arrow's text and the icon frames' titles ---------------------------------------------------------------------

do
	local env, K, ns, rxp = Boot()
	local arrow = rxp.arrowFrame
	rxp.SetupArrow()
	rxp.fake.arrow("Talk to |cRXP_FRIENDLY_Aarnor Galestrike|r", 1344, 0.5)
	local path, size = arrow.text:GetFont()
	assert(path == (ns.Style.Font("caption")), "the arrow's text is in KstyleUI's caption face, got " .. tostring(path))
	local caption = select(2, ns.Style.Font("caption")) / K.Widgets.ScaleFactor(arrow)
	assert(near(size, K.Widgets.FontSize(arrow.text, math.max(9, caption)), 1e-6), "at the kit's caption size in root units, or RestedXP's 9 where that is larger, got " .. tostring(size))
	arrow.text:SetFont(path, 4, "")
	assert(near(select(2, arrow.text:GetFont()), K.Widgets.FontSize(arrow.text, caption), 1e-6), "and never under the kit's caption size")
	arrow.text:SetFont(path, 9, "")
	assert(arrow.text:GetText() == "Talk to " .. Hex(K, "friend") .. "Aarnor Galestrike|r\n(1344yd)", "with RestedXP's default colours swapped for KstyleUI's, got " .. arrow.text:GetText())
	local ar, ag, ab = ns.Style.Accent()
	assert(W.SameColor(arrow.texture, ar, ag, ab), "under the accent arrow")
	rxp.UpdateItemFrame(rxp.activeItemFrame, 2)
	rxp.targeting:UpdateTargetFrame(1, 1)
	for name, frame in pairs({ ["ACTIVE ITEMS"] = rxp.activeItemFrame, ["ACTIVE TARGETS"] = rxp.targeting.activeTargetFrame }) do
		local text = assert(ns.RestedXP.Chrome.Caption(frame.title.text), name .. ": the title is a caption of KstyleUI's own")
		assert(text:GetText() == name, "the title reads in capitals, got " .. tostring(text:GetText()))
		assert(text:GetFont() == (ns.Style.Font("caps")) and near(select(2, text:GetFont()), K.Widgets.FontSize(text, ns.Lumen.CAP_SIZE / K.Widgets.ScaleFactor(text:GetParent())), 1e-6), name .. ": in the tracked caps role, as the guide's and the quests' captions")
		local r, g, b = text:GetTextColor()
		local cr, cg, cb = K.Tokens.Color("capsGold")
		assert(W.Near(r, cr) and W.Near(g, cg) and W.Near(b, cb), name .. ": in the captions' muted gold, not the accent")
		frame:UpdateVisuals()
		r, g, b = text:GetTextColor()
		assert(W.Near(r, cr) and W.Near(g, cg) and W.Near(b, cb) and text:GetFont() == (ns.Style.Font("caps")), name .. ": and stays so when RestedXP redraws the plate in its own font and colour")
		assert(frame.title.text:GetAlpha() == 0, name .. ": RestedXP's own title stays at rest through its redraw")
		local cp, cs = text:GetFont()
		local rp, rs = frame.title.text:GetFont()
		assert(rp == cp and near(rs, cs, 1e-6) and frame.title.text:GetText() == name, name .. ": RestedXP's own text, which it measures to size the plate and the frame (ActiveItemFrame.lua 223, 498), carries the caption's words and font, so the card is as wide as the caption, got " .. tostring(rs))
		assert(not K.Skin.IsSkinned(frame.title, "Backdrop"), name .. ": the plate draws no tile of its own")
		for _, piece in ipairs(frame.title._pieces) do
			assert(piece:GetAlpha() == 0, name .. ": RestedXP's plate backdrop stays hidden after its redraw")
		end
		for _, piece in ipairs(frame._pieces) do
			assert(piece:GetAlpha() == 0, name .. ": and so does the frame's")
		end
		assert(K.Skin.Parts(frame).backdrop:IsShown(), name .. ": on KstyleUI's glass")
	end
	Clean(env, K, rxp)
end

-- A tip is its own window -----------------------------------------------------------------------------------------

do
	local env, K, ns, rxp = Boot({ measure = true })
	local f = rxp.RXPFrame
	-- RestedXP keeps a tip in the steps' pool but hangs it from the screen's bottom left, 230 wide (GuideWindow.lua
	-- 1001-1012), far from the guide's cap, and leaves it out of the stack's height (1387-1391).
	-- This tip takes three lines in RestedXP's column and two in the skin's wider one, so its row changes height.
	rxp.fake.guide({ STEP[1], { tip = true, title = "Tip", elements = { { text = "Sell your grey items and repair whenever you pass", textOnly = true } } } })
	rxp.SetStep()
	env.RunTimers()
	local pool = f.CurrentStepFrame.framePool
	local step, tip = pool[1], pool[2]
	local row = tip.elements[1]
	assert(near(Rect(K, tip).left, 0, 0.01) and tip:GetWidth() == 230, "the tip stands where RestedXP put it, got " .. tostring(Rect(K, tip).left))
	local cap = ns.RestedXP.Chrome.Path(f).cap
	-- The game places a font string by its text alone; the stub wants a size, so the test gives the cap's title one
	-- and lets RestedXP lay the steps out again.
	cap.title:SetSize(cap.title:GetStringWidth(), cap.title:GetStringHeight())
	f.CurrentStepFrame.UpdateText()
	env.RunTimers()
	assert(type(cap.title:GetLeft()) == "number" and math.abs(cap.title:GetLeft() * cap.title:GetEffectiveScale() - row:GetLeft() * row:GetEffectiveScale()) > 100, "the cap's title is far from the tip on the screen, so the test can tell the two columns apart")
	local want = select(4, cap.gem:GetPoint(1)) + cap.gem:GetWidth() + select(4, cap.title:GetPoint(1))
	local point, relative, _, gutter = row.text:GetPoint(1)
	assert(point == "TOPLEFT" and relative == row and near(gutter, want, 0.01), "a tip's text starts at the step gutter of its own window, not under the guide's cap across the screen, got " .. tostring(gutter) .. " for " .. tostring(want))
	assert(select(2, row.text:GetPoint(2)) == tip, "and ends at the tip's own right edge")
	local _, _, _, cx = row.button:GetPoint(1)
	assert(cx >= 0 and cx + row.button:GetWidth() <= gutter, "its check stays left of it, inside the tip, got " .. tostring(cx))
	assert(near(select(4, step.elements[1].text:GetPoint(1)), want, 0.01), "the guide's own step still starts under the cap's title")
	local one = math.ceil(select(2, row.text:GetFont()) * 1.1) + 1
	assert(row:GetHeight() > one and tip:GetHeight() == row:GetHeight() + 18, "the tip's line wraps in its 230 units and its window grows with it, got " .. tostring(row:GetHeight()) .. " for one line of " .. tostring(one))
	assert(near(f.CurrentStepFrame:GetHeight(), step:GetHeight(), 0.01), "and the tip's change of height adds nothing to the guide's stack, as in RestedXP's own layout, got " .. tostring(f.CurrentStepFrame:GetHeight()) .. " for " .. tostring(step:GetHeight()))
	Clean(env, K, rxp)
end

print("skins restedxp rest ok")
