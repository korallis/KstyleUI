-- test-skins-restedxp-whole-step.lua: on every screen the crew checks, at the automatic Interface size, the guide's card shows every line of the owner's Tirisfal Glades step 11 under its cap with no "more" line, RestedXP's boxes up and down, RestedXP's steps anchored under its window. The guide holds the story slot and the quest card its column beside it, still showing a quest; with RestedXP not loaded, or its guide closed, the quest card keeps that column, and the cards never trade places.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")

local MAC = 768 / 1080
local SCREENS = {
	{ 1280, 720, 1 }, { 1920, 1080, 1 }, { 2560, 1440, 1 }, { 3840, 2160, 1 }, { 3440, 1440, 1 }, { 5120, 1440, 1 },
	{ 3840, 1080, 1 }, { 2383, 1540, 1 }, { 2383, 1540, MAC }, { 3456, 2234, 1 }, { 3456, 2234, MAC },
}
local LINES = { "Talk to", "Buy", "Refreshing Spring Water" }
local STEP = { index = 11, elements = {
	{}, {},
	{ text = "|Tinterface/worldmap/chatbubble_64grey.blp:20|tTalk to |cRXP_FRIENDLY_Joshua|r", textOnly = true },
	{ text = "|cRXP_BUY_Buy|r |T132794:0|t[Refreshing Spring Water] |cRXP_BUY_from him|r", textOnly = true },
	{ text = "Refreshing Spring Water: 0/5" },
	{}, {},
} }

local function Boot(screen, opts)
	local rxp
	local saved = { version = 12, profiles = { Default = { Layout = { preset = "DPS" } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = S.New({
		width = screen[1], height = screen[2], uiScale = screen[3], saved = saved,
		setup = function(e)
			e._textWidth = Measure.TextWidth
			Quests.Install(e, Quests.List(3))
			if opts.rxp ~= false then
				rxp = Fake.Install(e, {})
			end
		end,
		before = function(e)
			Quests.Tracker(e, S.Blizzard(e))
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	if rxp then
		rxp.fake.guide({ STEP })
		rxp.SetStep()
		rxp.targeting:UpdateTargetFrame(0, opts.boxes and 1 or 0)
		rxp.UpdateItemFrame(nil, opts.boxes and 1 or 0)
		env.RunTimers()
		rxp.settings.profile.anchorOrientation = "bottom"
		rxp.RXPFrame.SetStepFrameAnchor()
		rxp.RXPFrame.CurrentStepFrame.UpdateText()
	end
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	return env, K, ns, rxp
end

-- Rect(K, region) -> the region's rect in root units from the root's bottom left, where Layouts.Rect measures.
local function Rect(K, region)
	local root = K.Scale.Root()
	local r = Geometry.ScaledRect(region, root._env.UIParent, root)
	local o = Geometry.ScaledRect(root, root._env.UIParent, root)
	return { left = r.left - o.left, right = r.right - o.left, bottom = r.bottom - o.bottom, top = r.top - o.bottom }
end

local function Plain(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end

local function Overlap(a, b, px)
	return a.left < b.right - px and b.left < a.right - px and a.bottom < b.top - px and b.bottom < a.top - px
end

-- Expected(K, guide) -> the rects Layouts.Story gives the guide and the quest card.
local function Expected(K, guide)
	local rw, rh = K.Layout.RootSize()
	local story = K.Setup.Layouts.Story("DPS", rh, guide, rw)
	local out = {}
	for part, card in pairs(story) do
		if type(card) == "table" then
			local l, b, r, t = K.Setup.Layouts.Rect(card, card, rw, rh)
			out[part] = { left = l, bottom = b, right = r, top = t }
		end
	end
	return out
end

local function Same(a, b, px)
	return math.abs(a.left - b.left) <= px and math.abs(a.right - b.right) <= px and math.abs(a.top - b.top) <= px and math.abs(a.bottom - b.bottom) <= px
end

local function Describe(r)
	return string.format("%.1f..%.1f x %.1f..%.1f", r.left, r.right, r.bottom, r.top)
end

local function QuestCount(ns)
	local count = 0
	for _, row in ipairs(ns.Quests.Rows()) do
		if row:IsShown() and row.questID and row:GetAlpha() > 0 then
			count = count + 1
		end
	end
	return count
end

for _, screen in ipairs(SCREENS) do
	for _, boxes in ipairs({ true, false }) do
		local what = string.format("%dx%d at UI scale %.3f, RestedXP's boxes %s", screen[1], screen[2], screen[3], boxes and "up" or "down")
		local env, K, ns, rxp = Boot(screen, { boxes = boxes })
		local px = K.Scale.Pixel(1) + 0.01
		local f = rxp.RXPFrame
		local path = ns.RestedXP.Chrome.Path(f)
		local glass, cap = Rect(K, K.Skin.Parts(f).backdrop), Rect(K, path.cap)
		local band = ns.RestedXP.Rail.Band()
		local step = f.CurrentStepFrame.framePool[1]
		local lines = {}
		for _, element in ipairs(step.elements) do
			local value = element:IsShown() and element.text:GetText()
			if type(value) == "string" and element:GetAlpha() > 0 and step:GetAlpha() > 0 and not ns.RestedXP.Rail.Cut(element) then
				for i, want in ipairs(LINES) do
					if Plain(value):find(want, 1, true) == 1 then
						lines[i] = Rect(K, element)
					end
				end
			end
		end
		for i, want in ipairs(LINES) do
			local line = lines[i]
			assert(line, string.format("%s: the step's line %q shows", what, want))
			assert(line.top <= glass.top + px and line.bottom >= glass.bottom - px, string.format("%s: the line %q sits inside the card", what, want))
		end
		assert(ns.RestedXP.Rail.Hidden() == 0, string.format("%s: no \"more\" line, %d of the step rest under one", what, ns.RestedXP.Rail.Hidden()))
		local gap = cap.bottom - lines[1].top
		assert(gap >= 0 and gap <= 6, string.format("%s: the step's first line stands right under the cap, %.1f units under it", what, gap))
		-- At the automatic size the Medallions guide element is shorter than this step (a recorded limit, as staging's
		-- Medallions drew it): the card hangs from the element's top and runs past its foot to hold the whole step.
		assert(glass.top <= band.top + px, string.format("%s: the card %s hangs from its element's top %.1f", what, Describe(glass), band.top))
		local card = ns.Quests.Fit()
		assert(card, what .. ": the quest card is up")
		local quests = Rect(K, ns.Quests.Parts().glass)
		assert(not Overlap(glass, quests, px), string.format("%s: the guide %s and the quest card %s keep apart", what, Describe(glass), Describe(quests)))
		assert(QuestCount(ns) >= 1, what .. ": the quest card still shows a quest")
		for _, box in ipairs({ rxp.targeting.activeTargetFrame, rxp.activeItemFrame }) do
			if box:IsShown() then
				local r = Rect(K, K.Skin.Parts(box).backdrop)
				assert(not Overlap(r, quests, px) and not Overlap(r, glass, px), string.format("%s: RestedXP's box %s keeps off both cards", what, Describe(r)))
			end
		end
		local want = Expected(K, true)
		assert(Same(Rect(K, ns.RestedXP.Rail.Holder()), want.guide, px), string.format("%s: the guide holds the story slot, %s for %s", what, Describe(Rect(K, ns.RestedXP.Rail.Holder())), Describe(want.guide)))
		assert(Same(Rect(K, ns.Quests.Holder()), want.quests, px), string.format("%s: the quest card holds its column beside it, %s for %s", what, Describe(Rect(K, ns.Quests.Holder())), Describe(want.quests)))
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	end
	local _, K, ns = Boot(screen, { rxp = false })
	local px = K.Scale.Pixel(1) + 0.01
	local want = Expected(K, false)
	assert(Same(Rect(K, ns.Quests.Holder()), want.quests, px), string.format("%dx%d with RestedXP not loaded: the quest card keeps its column", screen[1], screen[2]))
end

-- The cards never trade places: closing RestedXP's guide, a step change and opening the guide again leave the quest
-- card in its column.
for _, screen in ipairs({ { 1920, 1080, 1 }, { 3456, 2234, MAC } }) do
	local env, K, ns, rxp = Boot(screen, { boxes = true })
	local px = K.Scale.Pixel(1) + 0.01
	local what = string.format("%dx%d", screen[1], screen[2])
	local shown, closed = Expected(K, true), Expected(K, false)
	assert(Same(Rect(K, ns.Quests.Holder()), shown.quests, px), what .. ": with the guide up the quest card holds its column")
	rxp.fake.guide({ STEP, { index = 12, elements = { { text = "Turn in Piercing the Veil" } } } })
	rxp.SetStep()
	env.RunTimers()
	assert(Same(Rect(K, ns.Quests.Holder()), shown.quests, px) and Same(Rect(K, ns.RestedXP.Rail.Holder()), shown.guide, px), what .. ": a step change moves neither card")
	rxp.fake.close(rxp.RXPFrame)
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	assert(Same(Rect(K, ns.Quests.Holder()), closed.quests, px), string.format("%s: with the guide closed the quest card keeps its column, %s for %s", what, Describe(Rect(K, ns.Quests.Holder())), Describe(closed.quests)))
	rxp.fake.open(rxp.RXPFrame)
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	assert(Same(Rect(K, ns.Quests.Holder()), shown.quests, px) and Same(Rect(K, ns.RestedXP.Rail.Holder()), shown.guide, px), what .. ": opening the guide again moves neither card")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("skins restedxp whole step ok")
