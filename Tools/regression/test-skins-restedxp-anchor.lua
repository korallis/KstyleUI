-- test-skins-restedxp-anchor.lua: with RestedXP's active steps anchored under its window (its "bottom" orientation, or its own flip when the steps' top passes the screen's top, GuideWindow.lua 353-391), the story rail still shows the current step whole, top-aligned under the guide's cap, as when RestedXP keeps them above its header: the owner's v0.1.2 report of 2026-11-15, the Tirisfal Glades guide's step 11 drawn as a blank card with only its last line and "1 more", at 3456x2234, 1920x1080 and 5120x1440, RestedXP's boxes up and down.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")

local HOOKED = { SetAlpha = true, SetVertexColor = true, SetColorTexture = true, SetChecked = true, SetFont = true, SetFontObject = true, SetText = true, Show = true, Hide = true, SetShown = true, UpdateVisuals = true, SetMinMaxValues = true, SetStep = true, SetScale = true, StopMovingOrSizing = true, SetTexture = true, SetRotation = true, SetTexCoord = true }
-- Each screen at the Interface size KstyleUI shipped before its automatic size and at the automatic size that ships
-- now; test-skins-restedxp-whole-step.lua covers every screen the crew checks.
local SCREENS = { { 3456, 2234, 768 / 1080, { 16 / 19, "auto" } }, { 1920, 1080, 1, { 16 / 19, "auto" } }, { 5120, 1440, 1, { 16 / 19, "auto" } } }
local LINES = { "Talk to", "Buy", "Refreshing Spring Water" }

-- Step 11 of RestedXP's "1-6 Tirisfal Glades" for an Undead warlock (Guides/forever/Horde-01-14_Undead.lua), the
-- owner's step when he reported it: two waypoints and a target with no text of their own, his two ">>" lines, the
-- water to collect, and the quest check.
local STEP = { index = 11, elements = {
	{}, {},
	{ text = "|Tinterface/worldmap/chatbubble_64grey.blp:20|tTalk to |cRXP_FRIENDLY_Joshua|r", textOnly = true },
	{ text = "|cRXP_BUY_Buy|r |T132794:0|t[Refreshing Spring Water] |cRXP_BUY_from him|r", textOnly = true },
	{ text = "Refreshing Spring Water: 0/5" },
	{}, {},
} }

local function Boot(screen, boxes, below, size)
	local rxp
	local saved = { version = 12, profiles = { Default = { Appearance = size == "auto" and {} or { uiScale = size, uiScaleAuto = false }, Layout = { preset = "DPS" } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = S.New({
		width = screen[1], height = screen[2], uiScale = screen[3], saved = saved,
		setup = function(e)
			e._textWidth = Measure.TextWidth
			Quests.Install(e, Quests.List(2))
			rxp = Fake.Install(e, {})
		end,
		before = function(e)
			Quests.Tracker(e, S.Blizzard(e))
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	rxp.fake.guide({ STEP })
	rxp.SetStep()
	rxp.targeting:UpdateTargetFrame(0, boxes and 1 or 0)
	rxp.UpdateItemFrame(nil, boxes and 1 or 0)
	env.RunTimers()
	if below then
		rxp.settings.profile.anchorOrientation = "bottom"
		rxp.RXPFrame.SetStepFrameAnchor()
		rxp.RXPFrame.CurrentStepFrame.UpdateText()
	end
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	return env, K, ns, rxp
end

local function Rect(K, region)
	local root = K.Scale.Root()
	return Geometry.ScaledRect(region, root._env.UIParent, root)
end

local function Plain(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end

-- Card(K, ns, rxp) -> the card's glass, its cap row, and each of the step's lines that shows, by LINES.
local function Card(K, ns, rxp)
	local f = rxp.RXPFrame
	local path = ns.RestedXP.Chrome.Path(f)
	local card = { glass = Rect(K, K.Skin.Parts(f).backdrop), cap = Rect(K, path.cap), lines = {} }
	local step = f.CurrentStepFrame.framePool[1]
	for _, element in ipairs(step.elements) do
		local value = element:IsShown() and element.text:GetText()
		if type(value) == "string" and element:GetAlpha() > 0 and step:GetAlpha() > 0 and not ns.RestedXP.Rail.Cut(element) then
			for i, want in ipairs(LINES) do
				if Plain(value):find(want, 1, true) == 1 then
					card.lines[i] = Rect(K, element)
				end
			end
		end
	end
	return card
end

local function Case(screen, boxes, size)
	local what = string.format("%dx%d at Interface size %s, RestedXP's boxes %s", screen[1], screen[2], tostring(size), boxes and "up" or "down")
	local _, aK, ans, arxp = Boot(screen, boxes, false, size)
	local above = Card(aK, ans, arxp)
	local env, K, ns, rxp = Boot(screen, boxes, true, size)
	local card = Card(K, ns, rxp)
	local px = K.Scale.Pixel(1) + 0.01
	local band = ns.RestedXP.Rail.Band()
	-- At the automatic size the Medallions guide element is shorter than this step (a recorded limit, as staging's
	-- Medallions drew it): the card still holds the whole step and runs past the element's foot.
	local roomy = size ~= "auto"
	assert(not roomy or band.top - band.bottom >= (ns.RestedXP.Rail.Need and ns.RestedXP.Rail.Need() or 0) - px, what .. ": the step fits its element, the boxes taking only the room it leaves")
	local lowest
	for i, want in ipairs(LINES) do
		local line = card.lines[i]
		assert(line, string.format("%s: the step's line %q shows", what, want))
		assert(line.top <= card.glass.top + px and line.bottom >= card.glass.bottom - px, string.format("%s: the line %q sits inside the card", what, want))
		assert(above.lines[i] and math.abs(line.top - above.lines[i].top) <= px, string.format("%s: the line %q stands where it does with RestedXP's steps above its header, got %.1f for %.1f", what, want, line.top, above.lines[i] and above.lines[i].top or -1))
		lowest = line
	end
	local gap = card.cap.bottom - card.lines[1].top
	assert(gap >= 0 and gap <= 6, string.format("%s: the step's first line stands right under the cap, %.1f units under it", what, gap))
	assert(not roomy or lowest.bottom >= band.bottom - px, string.format("%s: the step stays inside its element, its last shown line at %.1f for a foot at %.1f", what, lowest.bottom, band.bottom))
	assert(ns.RestedXP.Rail.Hidden() == 0, string.format("%s: no \"more\" line, %d of the step rest under one", what, ns.RestedXP.Rail.Hidden()))
	for _, edge in ipairs({ "top", "bottom", "left", "right" }) do
		assert(math.abs(card.glass[edge] - above.glass[edge]) <= px, string.format("%s: the card's %s is where it is with RestedXP's steps above its header, got %.1f for %.1f", what, edge, card.glass[edge], above.glass[edge]))
	end
	assert(rxp.RXPFrame.CurrentStepFrame.anchor == "TOP", what .. ": the rail keeps RestedXP's steps above its header while it holds the window")
	rxp.fake.check(HOOKED)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	K.Options.Write("Skins", "restedXP.rail", false)
	env.RunTimers()
	assert(rxp.RXPFrame.CurrentStepFrame.anchor == "BOTTOM", what .. ": with the rail off, RestedXP anchors its steps as it chose again")
end

for _, screen in ipairs(SCREENS) do
	for _, boxes in ipairs({ true, false }) do
		for _, size in ipairs(screen[4]) do
			Case(screen, boxes, size)
		end
	end
end

print("skins restedxp anchor ok")
