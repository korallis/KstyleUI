-- test-skins-restedxp-whole-step.lua: on every screen the crew checks, at the automatic Interface size, the guide's card shows every line of the owner's Tirisfal Glades step 11 under its cap with no "more" line, in Frames and Orbs, RestedXP's boxes up and down, RestedXP's steps anchored under its window. In Frames, while a guide is shown and the quest card is up, the guide takes the quest card's tall column and the quest card the story slot under the minimap, still showing a quest (the Captain's ruling of 2026-11-15 on LEE-1532: the quest card gives up rows before the guide gives up its step); with RestedXP not loaded, or its guide closed, the quest card stands where it does on staging, and the cards trade places only when the guide appears or goes.
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

local function Boot(screen, style, opts)
	local rxp
	local saved = { version = 12, profiles = { Default = { Layout = { preset = "DPS" }, HudStyle = { style = style } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
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

-- Expected(K, style, guide, shown) -> the rects Layouts.Story gives the guide and the quest card.
local function Expected(K, style, guide, shown)
	local rw, rh = K.Layout.RootSize()
	local story = K.Setup.Layouts.Story("DPS", rh, guide, style, rw, shown)
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

local function Quests(ns)
	local count = 0
	for _, row in ipairs(ns.Quests.Rows()) do
		if row:IsShown() and row.questID and row:GetAlpha() > 0 then
			count = count + 1
		end
	end
	return count
end

for _, screen in ipairs(SCREENS) do
	for _, style in ipairs({ "frames", "orbs" }) do
		for _, boxes in ipairs({ true, false }) do
			local what = string.format("%dx%d at UI scale %.3f, %s, RestedXP's boxes %s", screen[1], screen[2], screen[3], style, boxes and "up" or "down")
			local env, K, ns, rxp = Boot(screen, style, { boxes = boxes })
			local px = K.Scale.Pixel(1) + 0.01
			local f = rxp.RXPFrame
			local path = ns.RestedXP.Chrome.Path(f)
			local glass, cap = Rect(K, K.Skin.Parts(f).backdrop), Rect(K, path.cap.row)
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
			assert(glass.bottom >= band.bottom - px and glass.top <= band.top + px, string.format("%s: the card %s stays inside its element %.1f..%.1f", what, Describe(glass), band.bottom, band.top))
			local card = ns.Quests.Fit()
			assert(card, what .. ": the quest card is up")
			local quests = Rect(K, ns.Quests.Parts().glass)
			assert(not Overlap(glass, quests, px), string.format("%s: the guide %s and the quest card %s keep apart", what, Describe(glass), Describe(quests)))
			assert(Quests(ns) >= 1, what .. ": the quest card still shows a quest")
			for _, box in ipairs({ rxp.targeting.activeTargetFrame, rxp.activeItemFrame }) do
				if box:IsShown() then
					local r = Rect(K, K.Skin.Parts(box).backdrop)
					assert(not Overlap(r, quests, px) and not Overlap(r, glass, px), string.format("%s: RestedXP's box %s keeps off both cards", what, Describe(r)))
				end
			end
			if style == "frames" then
				local want = Expected(K, style, true, true)
				assert(Same(Rect(K, ns.RestedXP.Rail.Holder()), want.guide, px), string.format("%s: the guide takes the quest card's tall column, %s for %s", what, Describe(Rect(K, ns.RestedXP.Rail.Holder())), Describe(want.guide)))
				assert(Same(Rect(K, ns.Quests.Holder()), want.quests, px), string.format("%s: the quest card takes the story slot under the minimap, %s for %s", what, Describe(Rect(K, ns.Quests.Holder())), Describe(want.quests)))
			end
			assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
		end
		local _, K, ns = Boot(screen, style, { rxp = false })
		local px = K.Scale.Pixel(1) + 0.01
		local want = Expected(K, style, false)
		assert(Same(Rect(K, ns.Quests.Holder()), want.quests, px), string.format("%dx%d %s with RestedXP not loaded: the quest card stands where it does on staging", screen[1], screen[2], style))
	end
end

-- The cards trade places only when the guide appears or goes: closing RestedXP's guide gives the quest card its
-- column back as on staging, a step change keeps both where they are, and opening the guide again swaps them back.
for _, screen in ipairs({ { 1920, 1080, 1 }, { 3456, 2234, MAC } }) do
	local env, K, ns, rxp = Boot(screen, "frames", { boxes = true })
	local px = K.Scale.Pixel(1) + 0.01
	local what = string.format("%dx%d frames", screen[1], screen[2])
	local shown, closed = Expected(K, "frames", true, true), Expected(K, "frames", true, false)
	assert(Same(Rect(K, ns.Quests.Holder()), shown.quests, px), what .. ": with the guide up the quest card holds the story slot")
	rxp.fake.guide({ STEP, { index = 12, elements = { { text = "Turn in Piercing the Veil" } } } })
	rxp.SetStep()
	env.RunTimers()
	assert(Same(Rect(K, ns.Quests.Holder()), shown.quests, px) and Same(Rect(K, ns.RestedXP.Rail.Holder()), shown.guide, px), what .. ": a step change moves neither card")
	rxp.fake.close(rxp.RXPFrame)
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	assert(Same(Rect(K, ns.Quests.Holder()), closed.quests, px), string.format("%s: with the guide closed the quest card has its column back as on staging, %s for %s", what, Describe(Rect(K, ns.Quests.Holder())), Describe(closed.quests)))
	rxp.fake.open(rxp.RXPFrame)
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	assert(Same(Rect(K, ns.Quests.Holder()), shown.quests, px) and Same(Rect(K, ns.RestedXP.Rail.Holder()), shown.guide, px), what .. ": opening the guide again swaps the cards back")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("skins restedxp whole step ok")
