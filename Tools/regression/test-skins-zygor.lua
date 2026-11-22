-- test-skins-zygor.lua: Zygor Guides Viewer's guide window hung in the guide card in the top left corner, sized to it or to its steps, painted without writing Zygor's settings, handed back where the player left it, and beaten by the guide shown last when RestedXP is loaded too.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/zygor_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")

local function Boot(opts)
	opts = opts or {}
	local zygor
	local saved = {
		version = 12,
		profiles = { Default = { Layout = { preset = "DPS" }, Skins = opts.skins } },
		characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
	}
	local env, K, ns = S.New({
		width = opts.width or 1920, height = opts.height or 1080, size = opts.size, saved = saved,
		setup = function(e)
			if opts.auto then e._size, e._fitScale = "auto", true end
			e._textWidth = Measure.TextWidth
			Quests.Install(e, Quests.List(8))
			zygor = Fake.Install(e, { natural = opts.natural, allsteps = opts.allsteps, late = opts.late })
		end,
		before = function(e)
			Quests.Tracker(e, S.Blizzard(e))
		end,
	})
	K.Modules.Enable("Skins")
	env.RunTimers()
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	if opts.late then
		env.ZygorGuidesViewer:SetSkin()
	end
	zygor.Show()
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	return env, K, ns, zygor
end

local function Rect(K, region)
	return Geometry.ScaledRect(region, K.Scale.Root()._env.UIParent, K.Scale.Root())
end

local function Describe(r)
	return string.format("%.1f..%.1f x %.1f..%.1f", r.left, r.right, r.bottom, r.top)
end

-- Two guides offered, the one shown last holding the slot.
do
	local _, _, ns = Boot()
	local Guide = ns.Guide
	local shown = { a = false, b = false }
	Guide.Add("testA", {
		Enabled = function() return true end,
		Visible = function() return shown.a end,
	})
	Guide.Add("testB", {
		Enabled = function() return true end,
		Visible = function() return shown.b end,
	})
	shown.b = true
	Guide.Touch("testB")
	assert(Guide.Key() == "testB" and Guide.Visible(), "a lone shown guide holds the slot")
	shown.a = true
	Guide.Touch("testA")
	assert(Guide.Key() == "testA", "the guide shown last takes the slot from the one shown before it")
	shown.a = false
	assert(Guide.Key() == "testB" and Guide.Visible(), "hiding the owner hands the slot back to the other guide")
	shown.b = false
	assert(Guide.Key() == "zygor" and Guide.Visible(), "with both test guides hidden the shown Zygor guide holds the slot")
	assert(Guide.Is("zygor"), "the guide on screen holds the slot")
	shown.a = true
	Guide.Touch("testA")
	assert(Guide.Key() == "testA" and not Guide.Is("zygor"), "a guide shown after Zygor takes the slot from it")
end

-- The window hangs in the card at the card's width and sits at its top, its height its own steps' until Fit goes off.
do
	local env, K, ns, zygor = Boot({ natural = 20 })
	local px = K.Scale.Pixel(1) + 0.01
	local steps = (20 + 91.5) * K.Widgets.ScaleFactor(zygor.frame)
	local band = K.Setup.Story("DPS", true).guide
	local window = Rect(K, zygor.frame)
	assert(math.abs((window.right - window.left) - (band.right - band.left)) <= 2 * px, string.format("the window takes the card's width: %s for %s", Describe(window), Describe(band)))
	assert(math.abs(window.top - band.top) <= 2 * px, string.format("the window hangs from the card's top: %s in %s", Describe(window), Describe(band)))
	assert(math.abs((window.top - window.bottom) - steps) <= 2 * px, string.format("with Fit on the window is its own steps tall, %s", Describe(window)))
	assert(not zygor.master._clamped, "the card's window is not clamped to the screen")
	assert(zygor.profile.frame_anchor[1] == "CENTER", "the rail writes no anchor of its own into Zygor's settings")
	assert(zygor.saves == 0, string.format("the rail holds the window, so Zygors own anchor save stays quiet, got %d", zygor.saves))
	assert(zygor.style.WindowBackdropColor[4] == 0, "Zygor's own window fill steps aside for the KstyleUI card")
	local card = K.Skin.Parts(zygor.frame.Border).backdrop
	assert(card and card:IsShown(), "the window wears KstyleUI's window card, forged by default, as RestedXP's does")
	assert(ns.Skins and K.Skin.Parts(zygor.frame.Border).backdrop, "card present")
	local caption
	for _, region in ipairs({ zygor.frame.Border.TitleBar:GetRegions() }) do
		if region.GetText and region:GetText() == "SKYBORNE STARTER (1-13)" then caption = region end
	end
	assert(caption and caption:IsShown(), "the title bar carries the guide's name as a caps caption, as RestedXP's card does")
	local gem = ns.Parts.HeadingOf(caption).gem
	assert(gem:GetLeft() >= zygor.frame.Controls.MenuSettingsButton:GetRight(), string.format("the heading gem sits after Zygor's menu button, %.1f < %.1f", gem:GetLeft(), zygor.frame.Controls.MenuSettingsButton:GetRight()))
	assert(not zygor.frame.Controls.Logo:IsShown() or zygor.frame.Controls.Logo:GetAlpha() == 0, "Zygor's logo steps aside for the caption")
	assert(zygor.frame.Controls.StepNum.Step:GetFont() == ns.Style.Font("body"), "the step number takes the theme's body face")
	local next, report = zygor.frame.Controls.NextButton, zygor.frame.Controls.ReportStep
	next:AssignTextures()
	report:AssignTextures()
	assert(next:GetNormalTexture():GetAlpha() == 0, "Zygor's next arrow gives way to KstyleUI's chevron after every skin pass")
	local r = report:GetNormalTexture():GetVertexColor()
	assert(math.abs(r - (K.Tokens.Color("muted"))) < 0.01, "Zygor's other icons take the theme's muted ink after every skin pass")
	local arrow = zygor.arrow
	arrow:ShowTraveling()
	local ar, ag = arrow.arrow.arr:GetVertexColor()
	assert(math.abs(ar - (K.Tokens.Color("textEmphasis"))) < 0.01 and ag > 0.5, "the waypoint arrow is drawn in the theme's ink, not Zygor's red-to-green")
	assert(arrow.arrow.arrspecular:GetAlpha() == 0, "Zygor's arrow sheen is off")
	env.ZygorGuidesViewer.Pointer:SetFontSize(14)
	local face, height = arrow.title:GetFont()
	assert(face == ns.Style.Font("body") and math.abs(height - 14) < 0.5, "the arrow's text keeps Zygor's size in the theme's face")
	-- Zygor's step and line fills come from its own opacity and goal-colour settings, so they are quieted after it paints, never by writing those settings.
	local step = zygor.step
	zygor.frame:AddStep()
	assert(step.backdrop[4] == 0, "a repainted step lets the card show through")
	step.lines[1].back:SetBackdropColor(0.5, 0, 0, 1)
	local _, _, _, lineAlpha = step.lines[1].back.Center:GetVertexColor()
	assert(lineAlpha and lineAlpha < 0.5, "a goal colour stays as a faint tint, not a solid bar: " .. tostring(lineAlpha))
	assert(zygor.applied >= 1, "Zygors skin is applied after the rail's colours go in")
	assert(zygor.profile.fullheight == nil, "the window's own height save is not written while the rail holds it")
	-- Every step change brings the window back to the card, whatever Zygor's resize did to it.
	zygor.Step()
	env.RunTimers()
	S.W.Settle(env)
	local again = Rect(K, zygor.frame)
	assert(math.abs((again.top - again.bottom) - steps) <= 2 * px, string.format("after a step the window is its steps tall again, %s", Describe(again)))
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- The step text is in KstyleUI's face at Zygor's own size, so neither fights the other on Zygor's redraws; name colours stay, as RestedXP's do.
do
	local env, K, ns, zygor = Boot({})
	local label = zygor.label
	local path = ns.Style.Font("body")
	local font, height = label:GetFont()
	assert(font == path, string.format("the step text takes KstyleUI's face, %s", tostring(font)))
	assert(math.abs(height - 16) <= 0.5, string.format("the step text keeps Zygor's size, %s", tostring(height)))
	-- A repaint sets nothing already set: Zygor applies its skin whenever it resizes.
	local fonts, texts = zygor.writes.font, zygor.writes.text
	for _ = 1, 3 do
		env.ZygorGuidesViewer:ApplySkin()
	end
	env.RunTimers()
	assert(zygor.writes.font == fonts, string.format("a repaint sets no font again, %d new", zygor.writes.font - fonts))
	assert(zygor.writes.text == texts, string.format("a repaint rewrites no text, %d new", zygor.writes.text - texts))
	-- Zygor re-anchors its tabs on a 0.01 s timer (Tabs.lua:19): a hundred passes write no font.
	local tab = env.ZygorGuidesViewer.Tabs.Pool[1].Text
	local tabFont = tab:GetFont()
	assert(tabFont == path, "a guide tab takes KstyleUI's face")
	local before = tab._fontWrites
	for _ = 1, 100 do
		env.ZygorGuidesViewer.Tabs:ReanchorTabs()
	end
	assert(tab._fontWrites == before, string.format("Zygor's tab timer causes no font writes, %d new", tab._fontWrites - before))
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- Zygor makes its window after KstyleUI saw it load: the skin still starts once Zygor's SetSkin makes it.
do
	local env, K, _, zygor = Boot({ late = true })
	local card = K.Skin.Parts(zygor.frame.Border).backdrop
	assert(card and card:IsShown(), "a window Zygor makes late still wears the KstyleUI card")
	assert(zygor.style.WindowBackdropColor[4] == 0, "a window Zygor makes late is still painted")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- The rail settles: placing the guide does not queue another placement. Before, the holder took its unsnapped size on
-- every Place, Layout snapped it and queued a scoped restyle, whose tracked Restyle scheduled Place again, forever
-- (904 placements in 30 s in game, 38 ms of Lua a second). At 1600x900 and size 0.53 the stub's timer guard caught it.
do
	local env, K = Boot({ width = 1600, height = 900, size = 0.53 })
	local z, resized = env.ZygorGuidesViewer, 0
	local resize = z.ResizeFrame
	z.ResizeFrame = function(...)
		resized = resized + 1
		return resize(...)
	end
	for _ = 1, 30 do
		env.RunTimers()
	end
	assert(resized == 0, string.format("an idle rail re-places the guide: %d Zygor resizes in 30 timer passes", resized))
	-- Another module's scoped restyles reach the rail's region-less tracked Restyle; with nothing moved, none resizes Zygor.
	for _ = 1, 30 do
		K.Widgets.RestyleUnder({ [K.Scale.Root()] = true })
		env.RunTimers()
	end
	assert(resized == 0, string.format("other modules' restyles re-place the guide: %d Zygor resizes", resized))
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- Switching the skin off hides the card and gives Zygor its own window colours back.
do
	local env, K, _, zygor = Boot({})
	K.Options.Write("Skins", "zygor.enabled", false)
	env.RunTimers()
	assert(not K.Skin.Parts(zygor.frame.Border).backdrop:IsShown(), "the KstyleUI card goes when the skin is switched off")
	assert(zygor.style.WindowBackdropColor[1] == 1, "Zygor's own window colour is put back")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- Steps taller than the card leave the window the card's height, so it never runs over the party frames under the
-- card (the review of #713: at 1920x1080 and the automatic size the fixture's window covered 115 units of them).
do
	local env, K, _, zygor = Boot({ natural = 600, auto = true })
	local px = K.Scale.Pixel(1) + 0.01
	local band = K.Setup.Story("DPS", true).guide
	local rw, rh = K.Layout.RootSize()
	local _, partyHeight = K.Setup.Layouts.Footprint("DPS", "groupframes.party")
	local _, _, _, partyTop = K.Setup.Layouts.Rect({ width = 1, height = partyHeight }, K.Setup.Layouts.Get("DPS")["groupframes.party"], rw, rh)
	local function Check(what)
		local window = Rect(K, zygor.frame)
		assert(math.abs(window.top - band.top) <= 2 * px and math.abs(window.bottom - band.bottom) <= 2 * px, string.format("%s: the window fills the card and stops at its foot, %s in %s", what, Describe(window), Describe(band)))
		assert(window.bottom > partyTop, string.format("%s: clear of the party frames' top %.1f, %s", what, partyTop, Describe(window)))
	end
	Check("a tall step")
	for i = 1, 3 do
		zygor.Step()
		env.RunTimers()
		S.W.Settle(env)
		Check("after step " .. i)
	end
	local parts = K.Skin.Parts(zygor.frame)
	assert(not (parts and parts.backdrop), "the rail draws no panel of its own over Zygor's border")
	assert(zygor.frame:GetScript("OnSizeChanged"), "Zygors own size script goes back after the rail sizes the window")
	assert(zygor.profile.fullheight == nil, "the tall step writes no height into Zygors settings")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- In all-steps mode Zygor keeps its own minimum height; the rail only places it, never resizes it.
do
	local _, K, _, zygor = Boot({ natural = 20, allsteps = true })
	local floor = (91.5 + 80) * K.Widgets.ScaleFactor(zygor.frame)
	local px = K.Scale.Pixel(1) + 0.01
	local band = K.Setup.Story("DPS", true).guide
	local window = Rect(K, zygor.frame)
	assert(math.abs((window.top - window.bottom) - floor) <= 2 * px, string.format("in all-steps mode the window keeps Zygors own minimum, %s", Describe(window)))
	assert(math.abs(window.top - band.top) <= 2 * px, string.format("and still hangs from the card's top, %s in %s", Describe(window), Describe(band)))
end

-- Fit off stretches the window over the whole slot.
do
	local _, K, _, zygor = Boot({ natural = 120, skins = { zygor = { fit = false } } })
	local px = K.Scale.Pixel(1) + 0.01
	local band = K.Setup.Story("DPS", true).guide
	local window = Rect(K, zygor.frame)
	assert(math.abs((window.top - window.bottom) - (band.top - band.bottom)) <= 2 * px, string.format("with Fit off the window fills the slot: %s in %s", Describe(window), Describe(band)))
end

-- Dragging the window away turns the rail off for that character and hands Zygor's anchor back.
do
	local env, K, _, zygor = Boot()
	zygor.master:ClearAllPoints()
	zygor.master:SetPoint("TOPLEFT", env.UIParent, "BOTTOMLEFT", 20, 900)
	zygor.Step()
	env.RunTimers()
	S.W.Settle(env)
	assert(K.Options.Read("Skins", "zygor.rail") == false, "a moved window turns Story rail off")
	assert(zygor.master._clamped, "the moved window is Zygor's own again, clamped to the screen")
end

-- With RestedXP loaded too, the guide window shown last owns the card and the other goes back where it came from.
do
	local RestedXP = dofile("Tools/regression/restedxp_fake.lua")
	local zygor, rxp
	local saved = {
		version = 12,
		profiles = { Default = { Layout = { preset = "DPS" } } },
		characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
	}
	local env, K, ns = S.New({
		width = 1920, height = 1080, saved = saved,
		setup = function(e)
			e._textWidth = Measure.TextWidth
			Quests.Install(e, Quests.List(8))
			zygor = Fake.Install(e, { natural = 20 })
			rxp = RestedXP.Install(e, {})
			rxp.currentGuide = { name = "1-6 Tirisfal Glades", subgroup = "Horde Undead" }
		end,
		before = function(e)
			Quests.Tracker(e, S.Blizzard(e))
		end,
	})
	local function Settle()
		env.RunTimers()
		S.W.Settle(env)
		env.RunTimers()
	end
	K.Modules.Enable("Skins")
	Settle()
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	Settle()
	rxp.RXPFrame.GuideName.text:SetText("1-6 Tirisfal Glades\nHorde Undead")
	rxp.fake.guide({ { index = 11, elements = { { text = "Talk to Joshua", textOnly = true } } } })
	rxp.SetStep()
	Settle()
	assert(ns.Guide.Key() == "restedXP", "the RestedXP guide holds the card while it is the only one open")
	zygor.Show()
	Settle()
	assert(ns.Guide.Key() == "zygor", "showing Zygor after it takes the card from RestedXP")
	assert(not ns.RestedXP.Rail.Placed(), "RestedXP's window leaves the card when Zygor takes it")
	rxp.RXPFrame:Hide()
	rxp.RXPFrame:Show()
	Settle()
	assert(ns.Guide.Key() == "restedXP", "showing RestedXP again takes the card back")
	assert(zygor.master._clamped, "Zygors window is its own again once RestedXP holds the card")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- Zygor's action bar is Zygor's to place, and it comes back above the window the rail moved.
do
	local env, K, _, zygor = Boot()
	local z = env.ZygorGuidesViewer
	zygor.bar:ClearAllPoints()
	zygor.bar:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 30, 40)
	z.F.SetFrameAnchor(zygor.bar, zygor.profile.actionbar_anchor)
	local _, _, _, x, y = zygor.bar:GetPoint(1)
	assert(x == 100 and y == 100, "the rail leaves the anchors of Zygor's own frames alone")
	zygor.profile.actionbar_anchor = nil
	z.F.SaveFrameAnchor(zygor.bar, "actionbar_anchor")
	assert(type(zygor.profile.actionbar_anchor) == "table", "the rail lets Zygor save the action bar's place")
	zygor.Step()
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	local r = Rect(K, zygor.frame)
	local top = zygor.bar:GetBottom()
	assert(zygor.positions and top, "the rail asks Zygor to place its action bar")
	assert(top * K.Widgets.ScaleFactor(zygor.bar) > r.top, "Zygor's action bar sits above the window once the rail has placed it")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
