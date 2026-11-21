-- test-skins-zygor.lua: Zygor Guides Viewer's guide window hung in the story rail's card, sized to it or to its steps, painted without writing Zygor's settings, handed back where the player left it, and beaten by the guide shown last when RestedXP is loaded too.
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
		profiles = { Default = { Layout = { preset = "DPS" }, HudStyle = { style = opts.style or "frames" }, Skins = opts.skins } },
		characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
	}
	local env, K, ns = S.New({
		width = 1920, height = 1080, saved = saved,
		setup = function(e)
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
	local env, K, ns = Boot()
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
	-- Zygor's step and line fills come from its own opacity and goal-colour settings, so they are quieted after it paints, never by writing those settings.
	local step = zygor.step
	zygor.frame:AddStep()
	assert(step.backdrop[4] == 0, "a repainted step lets the card show through")
	step.lines[1]:SetBackColor(0.5, 0, 0, 1)
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

-- The step text is in KstyleUI's face at KstyleUI's size, and Zygor's own goal colours said in the theme's hues.
do
	local env, K, ns, zygor = Boot({})
	local label = zygor.label
	local path, size = ns.Style.Font("body")
	local font, height = label:GetFont()
	assert(font == path, string.format("the step text takes KstyleUI's face, %s", tostring(font)))
	assert(math.abs(height - size) <= 0.5, string.format("the step text takes KstyleUI's size, %s instead of %s", tostring(height), tostring(size)))
	local function Hex(name)
		local r, g, b = K.Tokens.Color(name)
		return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
	end
	local text = label:GetText()
	assert(type(text) == "string", "the step text is left readable")
	assert(text:find(Hex("nameHostile"), 1, true) ~= nil, "the monster in the step is the theme's hostile hue: " .. tostring(text))
	assert(text:find(Hex("magic"), 1, true) ~= nil, "the item in the step is the theme's magic hue: " .. tostring(text))
	assert(text:find("|cffffaaaa", 1, true) == nil, "no raw monster colour is left: " .. tostring(text))
	-- A repaint sets nothing already set: Zygor applies its skin whenever it resizes.
	local fonts, texts = zygor.writes.font, zygor.writes.text
	for _ = 1, 3 do
		env.ZygorGuidesViewer:ApplySkin()
	end
	env.RunTimers()
	assert(zygor.writes.font == fonts, string.format("a repaint sets no font again, %d new", zygor.writes.font - fonts))
	assert(zygor.writes.text == texts, string.format("a repaint rewrites no text, %d new", zygor.writes.text - texts))
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- Zygor makes its window after KstyleUI saw it load: the skin still starts once Zygor's SetSkin makes it.
do
	local env, K, ns, zygor = Boot({ late = true })
	local card = K.Skin.Parts(zygor.frame.Border).backdrop
	assert(card and card:IsShown(), "a window Zygor makes late still wears the KstyleUI card")
	assert(zygor.style.WindowBackdropColor[4] == 0, "a window Zygor makes late is still painted")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- Switching the skin off hides the card and gives Zygor its own window colours back.
do
	local env, K, ns, zygor = Boot({})
	K.Options.Write("Skins", "zygor.enabled", false)
	env.RunTimers()
	assert(not K.Skin.Parts(zygor.frame.Border).backdrop:IsShown(), "the KstyleUI card goes when the skin is switched off")
	assert(zygor.style.WindowBackdropColor[1] == 1, "Zygor's own window colour is put back")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- A step taller than the card grows the window below it rather than clipping the step.
do
	local env, K, ns, zygor = Boot({ natural = 600 })
	local px = K.Scale.Pixel(1) + 0.01
	local steps = (600 + 91.5) * K.Widgets.ScaleFactor(zygor.frame)
	local band = K.Setup.Story("DPS", true).guide
	local room = band.top - band.bottom
	local window = Rect(K, zygor.frame)
	assert((window.top - window.bottom) > room + 2 * px, string.format("a step taller than the card pushes the window past it: %s in %s", Describe(window), Describe(band)))
	assert(math.abs((window.top - window.bottom) - steps) <= 2 * px, string.format("and the window is the whole step tall, %s", Describe(window)))
	assert(math.abs(window.top - band.top) <= 2 * px, string.format("the window still hangs from the card's top, %s in %s", Describe(window), Describe(band)))
	for i = 1, 3 do
		zygor.Step()
		env.RunTimers()
		S.W.Settle(env)
		local again = Rect(K, zygor.frame)
		assert(math.abs((again.top - again.bottom) - steps) <= 2 * px, string.format("after step %d the window is still the whole step tall, %s", i, Describe(again)))
	end
	local parts = K.Skin.Parts(zygor.frame)
	assert(not (parts and parts.backdrop), "the rail draws no panel of its own over Zygor's border")
	assert(zygor.frame:GetScript("OnSizeChanged"), "Zygors own size script goes back after the rail sizes the window")
	assert(zygor.profile.fullheight == nil, "the tall step writes no height into Zygors settings")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- In all-steps mode Zygor keeps its own minimum height; the rail only places it, never resizes it.
do
	local env, K, ns, zygor = Boot({ natural = 20, allsteps = true })
	local floor = (91.5 + 80) * K.Widgets.ScaleFactor(zygor.frame)
	local px = K.Scale.Pixel(1) + 0.01
	local band = K.Setup.Story("DPS", true).guide
	local window = Rect(K, zygor.frame)
	assert(math.abs((window.top - window.bottom) - floor) <= 2 * px, string.format("in all-steps mode the window keeps Zygors own minimum, %s", Describe(window)))
	assert(math.abs(window.top - band.top) <= 2 * px, string.format("and still hangs from the card's top, %s in %s", Describe(window), Describe(band)))
end

-- Fit off stretches the window over the whole slot.
do
	local env, K, ns, zygor = Boot({ natural = 120, skins = { zygor = { fit = false } } })
	local px = K.Scale.Pixel(1) + 0.01
	local band = K.Setup.Story("DPS", true).guide
	local window = Rect(K, zygor.frame)
	assert(math.abs((window.top - window.bottom) - (band.top - band.bottom)) <= 2 * px, string.format("with Fit off the window fills the slot: %s in %s", Describe(window), Describe(band)))
end

-- Dragging the window away turns the rail off for that character and hands Zygor's anchor back.
do
	local env, K, ns, zygor = Boot()
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
		profiles = { Default = { Layout = { preset = "DPS" }, HudStyle = { style = "frames" } } },
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
	local env, K, ns, zygor = Boot()
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
