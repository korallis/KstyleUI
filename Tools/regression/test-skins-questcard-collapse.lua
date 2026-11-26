-- test-skins-questcard-collapse.lua: player feedback asked for a quest card that collapses and expands: a click on its header folds it to the header row and a second click restores it, an arrow beside the count marks the state, combat defers a fold only while an item button shows, and the state is saved in the profile.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local S = dofile("Tools/regression/skins_env.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local RestedXP = dofile("Tools/regression/restedxp_fake.lua")

local CLICK_SOUND = 856
local played

local function Sounds(env)
	played = {}
	env.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = CLICK_SOUND, U_CHAT_SCROLL_BUTTON = 1115 }
	env.PlaySound = function(id) played[#played + 1] = id end
end

local function Card(K, ns)
	local parts = ns.Quests.Parts()
	local card = parts.card
	local unit = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(card)
	local T = { parts = parts, card = card }
	function T.Pixels(units)
		return units / unit
	end
	function T.Click()
		parts.toggle:GetScript("OnClick")(parts.toggle, "LeftButton")
	end
	function T.Rows()
		local n = 0
		for _, row in ipairs(ns.Quests.Rows()) do
			if row:IsVisible() then n = n + 1 end
		end
		return n
	end
	function T.Buttons()
		local n = 0
		for _, button in ipairs(ns.Quests.Buttons()) do
			if button:IsShown() then n = n + 1 end
		end
		return n
	end
	function T.Down()
		local _, _, top, bottom = parts.chevron:GetTexCoord()
		return top < bottom
	end
	function T.Folded(count, why)
		assert(card:IsShown() and parts.cap:IsVisible() and tostring(parts.cap.count:GetText()) == count, why .. ": the header row stays with the tracked count")
		assert(T.Rows() == 0 and not parts.view:IsVisible() and not parts.more:IsVisible(), why .. ": no quest row or hint line shows")
		assert(not parts.track:IsVisible() and not parts.thumb:IsVisible() and not parts.fade:IsVisible(), why .. ": no scroll bar or fade shows")
		local tall = 2 * math.floor(T.Pixels(11) + 0.5) + math.floor(T.Pixels(21) + 0.5)
		assert(math.abs(T.Pixels(card:GetHeight()) - tall) < 1e-6, why .. ": the folded card is 11, 21 and 11 units on whole pixels, " .. tall .. ", got " .. T.Pixels(card:GetHeight()))
		assert(T.Down() and parts.chevron:IsVisible(), why .. ": the arrow points down")
	end
	return T
end

local function Clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

for _, screen in ipairs({ { width = 1920, height = 1080 }, { width = 5120, height = 1440 } }) do
	screen.setup = Sounds
	local R = Boot(screen, true)
	local env, K, ns = R.env, R.K, R.ns
	local T = Card(K, ns)
	local parts, card = T.parts, T.card
	local open, first = card:GetHeight(), ns.Quests.Rows()[1].questID
	assert(T.Rows() >= 4 and T.Buttons() == 1 and not T.Down() and parts.chevron:IsVisible(), "the open card shows its quests, the item button and an arrow pointing up")
	local arrow = T.Pixels(parts.chevron:GetWidth())
	assert(math.abs(arrow - T.Pixels(10)) <= 0.5 and math.abs(arrow - math.floor(arrow + 0.5)) < 1e-6, "the arrow is ten units wide on whole pixels, got " .. arrow)
	local shown = T.Rows()
	local _, _, _, countX = parts.cap.count:GetPoint(1)
	assert(math.abs(-countX - parts.chevron:GetWidth() - K.Widgets.Snap(card, 8)) < 1e-6, "the count stands an eight-unit gap left of the arrow")
	assert(K.Options.Read("Skins", "quests.collapsed") == false, "a new profile starts expanded")

	T.Click()
	R.settle()
	T.Folded("8", "after a header click")
	assert(screen.height ~= 1080 or math.abs(T.Pixels(card:GetHeight()) - 40) < 1e-6, "at 1920 by 1080 the folded card is 40 screen pixels tall")
	assert(T.Buttons() == 0, "the item button leaves with its row")
	assert(#played == 1 and played[1] == CLICK_SOUND, "the click plays the game's tracker tick")
	assert(K.Options.Read("Skins", "quests.collapsed") == true, "the profile remembers the fold")
	local holder = ns.Quests.Holder()
	assert(card:GetHeight() <= holder:GetHeight() and select(5, card:GetPoint(1)) == holder:GetHeight(), "the folded card hangs from the top of its Layout element")
	card:GetScript("OnMouseWheel")(card, -1)
	assert(ns.Quests.Offset() == 1 and #played == 1, "the wheel waits while the card is folded")

	local kept = { [8] = R.quests[8] }
	R.log.Untrack(kept[8].id)
	R.settle()
	T.Folded("7", "after untracking a quest")
	for i = #R.quests, 1, -1 do
		kept[i] = R.quests[i]
		R.log.Untrack(R.quests[i].id)
	end
	R.settle()
	assert(not card:IsShown(), "with no tracked quest the card hides")
	for i = 1, 8 do
		R.log.Track(kept[i])
	end
	R.settle()
	T.Folded("8", "after tracking again")

	T.Click()
	R.settle()
	assert(T.Rows() == shown and card:GetHeight() == open and ns.Quests.Rows()[1].questID == first, "a second click restores the same rows and height")
	assert(T.Buttons() == 1 and not T.Down() and K.Options.Read("Skins", "quests.collapsed") == false, "the item button returns and the profile remembers the open card")
	card:GetScript("OnMouseWheel")(card, -1)
	T.Click()
	T.Click()
	R.settle()
	assert(ns.Quests.Offset() == 2 and ns.Quests.Rows()[1].questID == R.quests[2].id, "expanding returns to the scroll place it left")
	card:GetScript("OnMouseWheel")(card, 1)
	R.settle()

	env.SetCombat(true)
	T.Click()
	R.settle()
	assert(T.Rows() == shown and card:GetHeight() == open and T.Buttons() == 1 and not T.Down(), "in combat an item button holds the rows still")
	env.SetCombat(false)
	R.settle()
	T.Folded("8", "when combat ends")
	assert(T.Buttons() == 0, "the item button hides after combat")
	env.SetCombat(true)
	T.Click()
	R.settle()
	assert(T.Rows() == shown and card:GetHeight() == open and T.Buttons() == 0, "expanding in combat shows the rows at once and leaves the item button for later")
	env.SetCombat(false)
	R.settle()
	assert(T.Buttons() == 1, "the item button returns when combat ends")
	Clean(env, K)
end

do
	local R = Boot({ width = 1920, height = 1080 }, false)
	local T = Card(R.K, R.ns)
	R.env.SetCombat(true)
	T.Click()
	R.settle()
	T.Folded("8", "in combat with no item button")
	R.env.SetCombat(false)
	R.settle()
	T.Folded("8", "after that combat")
	Clean(R.env, R.K)
end

do
	local R = Boot({ width = 1920, height = 1080 }, false)
	local K, ns = R.K, R.ns
	local T = Card(K, ns)
	local parts = T.parts
	local holder = ns.Quests.Holder()
	K.Options.Write("Skins", "quests.shown", 1)
	ns.QuestCard.Place(holder, 0, holder:GetHeight(), holder:GetWidth(), 60)
	ns.QuestCard.Render()
	R.settle()
	assert(not parts.cap:IsShown() and parts.more:IsVisible() and T.Rows() == 1, "a short slot shows one quest and the hint line without the header")
	assert(parts.toggle:GetPoint(1) == "BOTTOMLEFT" and select(2, parts.chevron:GetPoint(1)) == T.card and select(3, parts.chevron:GetPoint(1)) == "BOTTOMRIGHT", "the hint line takes the click and carries the arrow")
	assert(parts.toggle:GetHeight() < T.card:GetHeight() / 2, "the click target is the hint line, not the quest")
	T.Click()
	R.settle()
	T.Folded("8", "a short slot folded")
	assert(parts.toggle:GetPoint(1) == "TOPLEFT", "the header row takes the click back")
	T.Click()
	R.settle()
	assert(not parts.cap:IsShown() and T.Rows() == 1, "the short slot expands to its one quest")
	Clean(R.env, K)
end

do
	local env, K, ns = S.New({
		width = 1920, height = 1080,
		saved = {
			version = 12, profiles = { Default = { Skins = { quests = { collapsed = true } } } },
			characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
		},
		setup = function(e)
			Quests.Install(e, Quests.List(8, 1))
			RestedXP.Install(e, {})
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
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	Settle()
	local T = Card(K, ns)
	T.Folded("8", "a fresh start from a profile saved folded")
	K.Store.CreateProfile("Other")
	K.Store.SetProfile("Other")
	Settle()
	assert(T.Rows() >= 1 and not T.Down(), "a profile that never folded the card opens it")
	K.Store.SetProfile("Default")
	Settle()
	T.Folded("8", "back on the folded profile")
	Clean(env, K)
end

print("test-skins-questcard-collapse: ok")
