-- test-skins-story-overflow.lua: the story rail of the owner's first live session (2026-11-12, 5120x1440: RestedXP's guide with three active steps of wrapped lines that ran 141 units under its part of the story rail and over the quest card, and nine quests, the first with four objectives) never draws text over text, on every screen of the matrix and in combat: the RestedXP guide's card and the quest card each stay inside their own Layout element, neither crosses the other, every text either shows stays inside its own card and crosses no other text, and the steps or quests that do not fit rest under a "more" line.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")

local SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 3840, 1080 }, { 5120, 1440 },
	{ 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}

-- The guide RestedXP showed (step 57, three active steps) plus two more steps, so the steps outrun the whole story slot.
local STEPS = {
	{ title = "Step 57", elements = { { text = "Kill |cRXP_ENEMY_Bandit Highwayman|r. Loot them for the [Blood-Stained Bandit Masks]." }, { text = "Watch for stealthed enemies in the apple orchard." }, { text = "0/7 Blood-Stained Bandit Mask" } } },
	{ title = "Step 58", elements = { { text = "Make your way up the mountain" }, { text = "If you see a Tornado, use it for faster travel to the top of the hill" } } },
	{ title = "Step 59", elements = { { text = "Click on the |cRXP_PICK_Construct Parts|r" }, { text = "Obtain Air Construct Core from the Bandit Camp 0/1" } } },
	{ title = "Step 60", elements = { { text = "Return to Riaani at the camp by the lake and hand in the parts you found" }, { text = "Collect the Enchanted Gyrozephyr from the shallows of Windsong Lake" } } },
	{ title = "Step 61", elements = { { text = "Follow the road north to the Sparkling Cave and clear the elementals at its mouth" } } },
}

local function QuestList()
	local list = Quests.List(9)
	list[1].title = "The Broken Construct"
	list[1].objectives = {
		{ text = "Listen to what Riaani has to say: 1/1", finished = true },
		{ text = "Obtain Crystallized Lightning from the Sparkling Cave: 1/1", finished = true },
		{ text = "Obtain Enchanted Gyrozephyr from Windsong Lake: 0/1", finished = false },
		{ text = "Obtain Air Construct Core from the Bandit Camp: 0/1", finished = false },
	}
	return list
end

local function Boot(screen, preset)
	local rxp
	local saved = { version = 12, profiles = { Default = { Appearance = { uiScale = 16 / 19 }, Layout = { preset = preset } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = S.New({
		width = screen[1], height = screen[2], saved = saved,
		setup = function(env)
			env._textWidth = Measure.TextWidth
			Quests.Install(env, QuestList())
			rxp = Fake.Install(env, {})
		end,
		before = function(env)
			Quests.Tracker(env, S.Blizzard(env))
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	rxp.fake.guide(STEPS)
	rxp.SetStep()
	env.RunTimers()
	S.W.Settle(env)
	return env, K, ns, rxp
end

local function RootRect(K, object)
	local root = K.Scale.Root()
	return Geometry.ScaledRect(object, root._env.UIParent, root)
end

local function Shown(region)
	local node = region
	while node do
		if not node:IsShown() then
			return false
		end
		local alpha = node:GetAlpha()
		if type(alpha) == "number" and alpha <= 0 then
			return false
		end
		node = node:GetParent()
	end
	return true
end

-- Texts(K, root) -> every font string under root that draws words, with its rect in root units.
local function Texts(K, root)
	local out = {}
	for _, object in ipairs(Geometry.Tree(root)) do
		if object._type == "FontString" and Shown(object) then
			local text = object:GetText()
			if type(text) == "string" and text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("%S") then
				local r = RootRect(K, object)
				if r and r.right > r.left and r.top > r.bottom then
					out[#out + 1] = { object = object, text = text, rect = r }
				end
			end
		end
	end
	return out
end

local function Crosses(a, b, slack)
	return math.min(a.right, b.right) - math.max(a.left, b.left) > slack and math.min(a.top, b.top) - math.max(a.bottom, b.bottom) > slack
end

local function Check(K, ns, rxp, what)
	local px = K.Scale.Pixel(1) + 0.01
	local rw, rh = K.Layout.RootSize()
	local slot = K.Setup.Layouts.Slot(K.Layout.Setting("preset"), rh)
	local _, sb, _, st = K.Setup.Layouts.Rect(slot, slot, rw, rh)
	local guide = RootRect(K, assert(K.Skin.Parts(rxp.RXPFrame).backdrop, what .. ": the guide wears its glass"))
	local card = RootRect(K, ns.Quests.Card())
	assert(guide.bottom >= sb - px and guide.top <= st + px, what .. ": the guide's card stays inside the story slot, got " .. guide.bottom .. " to " .. guide.top .. " for " .. sb .. " to " .. st)
	assert(not Crosses(guide, card, px), what .. ": the guide's card and the quest card do not cross")
	local cards = { { name = "guide", root = rxp.RXPFrame, glass = guide }, { name = "quests", root = ns.Quests.Card(), glass = card } }
	local all = {}
	for _, c in ipairs(cards) do
		for _, t in ipairs(Texts(K, c.root)) do
			t.card = c.name
			local past = Geometry.Outside(t.rect, c.glass)
			assert(past <= px, what .. ": \"" .. t.text .. "\" stays on the " .. c.name .. " card's glass, " .. past .. " units past it")
			all[#all + 1] = t
		end
	end
	assert(#all > 0, what .. ": the cards show words")
	for i = 1, #all do
		for j = i + 1, #all do
			local a, b = all[i], all[j]
			assert(not Crosses(a.rect, b.rect, 2), what .. ": \"" .. a.text .. "\" (" .. a.card .. ") and \"" .. b.text .. "\" (" .. b.card .. ") draw over each other")
		end
	end
	assert(ns.RestedXP.Rail.Hidden() > 0, what .. ": the steps that do not fit rest unseen")
	for _, step in ipairs(rxp.RXPFrame.CurrentStepFrame.framePool) do
		if step:IsShown() and step:GetAlpha() <= 0 and step:GetHeight() > 1 then
			assert(not step:IsMouseEnabled(), what .. ": a step resting unseen takes no clicks")
			for _, line in ipairs(step.elements or {}) do
				assert(not line:IsMouseEnabled() and not (line.button and line.button:IsMouseEnabled()), what .. ": nor do its lines and their check buttons, which hang over the rail's bars")
			end
		end
	end
end

local cases = 0
for _, screen in ipairs(SCREENS) do
	for _, preset in ipairs({ "DPS", "Tank", "Healer" }) do
		local env, K, ns, rxp = Boot(screen, preset)
		local what = preset .. " at " .. screen[1] .. "x" .. screen[2]
		Check(K, ns, rxp, what)
		-- In combat RestedXP lays its steps out again (a step completes, a timer bar starts): the guide still fits
		-- its card at once, though its window waits for combat to end to move.
		env.SetCombat(true)
		rxp.SetStep()
		env.RunTimers()
		Check(K, ns, rxp, what .. " in combat")
		env.SetCombat(false)
		env.RunTimers()
		Check(K, ns, rxp, what .. " after combat")
		assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))
		cases = cases + 1
	end
end

print("test-skins-story-overflow: ok, " .. cases .. " screen and preset cases")
