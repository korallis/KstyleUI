-- test-skins-questcard.lua: the quest card shows a set number of tracked quests (3 by default, 1 to 8) in the story slot, scrolls to the rest with the wheel, never crosses the chat card at the owner's screen, docks under the RestedXP guide, never changes its item buttons in combat, hands the screen back to Blizzard's tracker for scenarios and when switched off, and keeps the combat path cheap.
local S = dofile("Tools/regression/skins_env.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local RestedXP = dofile("Tools/regression/restedxp_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local W = S.W

local OWNER = { width = 2383, height = 1540, uiScale = 768 / 1080 }
local PROTECTED = {
	SetAttribute = true, Show = true, Hide = true, SetShown = true, SetPoint = true, ClearAllPoints = true,
	SetAllPoints = true, SetSize = true, SetWidth = true, SetHeight = true, SetParent = true, EnableMouse = true,
	SetScale = true, RegisterForClicks = true,
}

-- Boot(opts) -> env, K, ns, log, tracker: Skins on, Blizzard's tracker loaded, opts.quests tracked (10 by
-- default). opts.rxp installs RestedXP; opts.screen sets the screen; opts.saved the saved Skins section.
local function Boot(opts)
	opts = opts or {}
	local log, tracker, rxp
	local screen = opts.screen or {}
	local env, K, ns = S.New({
		width = screen.width,
		height = screen.height,
		uiScale = screen.uiScale,
		saved = opts.saved,
		setup = function(env)
			log = Quests.Install(env, opts.quests or Quests.List(10))
			log.super = opts.super or 0
			if opts.rxp then
				rxp = RestedXP.Install(env, {})
			end
		end,
		before = function(env)
			tracker = Quests.Tracker(env, S.Blizzard(env))
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	W.Settle(env)
	return env, K, ns, log, tracker, rxp
end

local function Saved(section)
	return {
		version = 2,
		profiles = { Default = { Skins = section } },
		characters = {},
		layouts = {},
		account = { setupSeen = true },
		devlog = {},
	}
end

-- Shown(ns) -> the ids of the quests the card shows, top to bottom.
local function Shown(ns)
	local out = {}
	for _, row in ipairs(ns.Quests.Rows()) do
		if row:IsShown() and row.questID then
			out[#out + 1] = row.questID
		end
	end
	return out
end

local function Ids(list)
	local out = {}
	for i, id in ipairs(list) do
		out[i] = tostring(id)
	end
	return table.concat(out, ",")
end

local function Wheel(ns, delta)
	local card = ns.Quests.Card()
	local fn = assert(card:GetScript("OnMouseWheel"), "the card takes the mouse wheel")
	fn(card, delta)
end

local function Clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- RootRect(K, object) -> the object's rect in KstyleUI's root units, whichever frame it hangs from.
local function RootRect(K, object)
	local env = K.Scale.Root()._env
	local r = assert(Geometry.Rect(object, env.UIParent))
	local s = env.UIParent:GetEffectiveScale() / K.Scale.Root():GetEffectiveScale()
	return { left = r.left * s, right = r.right * s, bottom = r.bottom * s, top = r.top * s }
end

-- Three of ten: the card shows three quests, the super-tracked one first and marked, and counts all ten -------------

do
	local env, K, ns, _, tracker = Boot({ super = 305 })
	assert(ns.Skins.IsApplied("quests"), "the quest card applies once Blizzard's tracker loads")
	assert(ns.Quests.Active(), "the card stands in for Blizzard's quest list")
	assert(ns.Quests.Card():IsShown(), "and shows")
	local shown = Shown(ns)
	assert(Ids(shown) == "305,301,302", "three of ten, the super-tracked quest first, got " .. Ids(shown))
	local first = ns.Quests.Rows()[1]
	assert(first.marked == true, "the super-tracked quest is marked")
	assert(ns.Quests.Rows()[2].marked ~= true, "and only that one")
	local parts = ns.Quests.Parts()
	assert(parts.cap.titleValue == "Quests" or parts.cap.titleValue == K.L["Quests"], "the cap reads QUESTS")
	assert(parts.cap.trailValue == "10", "the cap counts every tracked quest, got " .. tostring(parts.cap.trailValue))
	local title = first.title:GetText()
	assert(title:find("[10]", 1, true) and title:find("Dark Storms", 1, true), "the title carries the quest's level as Forever shows it, got " .. title)
	assert(parts.more:IsShown() and parts.more:GetText():find("7", 1, true), "the card says how many more there are, got " .. tostring(parts.more:GetText()))
	assert(parts.thumb:IsShown(), "and a slim scroll bar shows")
	assert(not tracker:IsVisible(), "Blizzard's tracker does not show the quests a second time")
	Clean(env, K)
end

-- Scrolling reveals the rest, one quest per wheel step, and stops at either end -------------------------------------

do
	local env, K, ns = Boot()
	assert(Ids(Shown(ns)) == "301,302,303", "the first three, got " .. Ids(Shown(ns)))
	Wheel(ns, -1)
	assert(Ids(Shown(ns)) == "302,303,304", "one wheel step down shows the next quest, got " .. Ids(Shown(ns)))
	for _ = 1, 20 do
		Wheel(ns, -1)
	end
	assert(Ids(Shown(ns)) == "308,309,310", "the wheel reaches the last quest and stops there, got " .. Ids(Shown(ns)))
	local more = ns.Quests.Parts().more
	assert(more:IsShown() and more:GetText() == "7 above, scroll up", "at the end the more line points up, got " .. tostring(more:GetText()))
	Wheel(ns, 1)
	assert(Ids(Shown(ns)) == "307,308,309", "and back up, got " .. Ids(Shown(ns)))
	for _ = 1, 20 do
		Wheel(ns, 1)
	end
	assert(Ids(Shown(ns)) == "301,302,303", "up to the top and no further, got " .. Ids(Shown(ns)))
	Clean(env, K)
end

-- The setting picks how many quests show, from 1 to 8; fewer quests than that show them all with no scroll bar -----

do
	local env, K, ns, log = Boot()
	K.Options.Write("Skins", "quests.shown", 5)
	env.RunTimers()
	assert(#Shown(ns) == 5, "five shown, got " .. #Shown(ns))
	K.Options.Write("Skins", "quests.shown", 1)
	env.RunTimers()
	assert(#Shown(ns) == 1, "one shown, got " .. #Shown(ns))
	K.Options.Write("Skins", "quests.shown", 12)
	env.RunTimers()
	assert(#Shown(ns) == 8, "never more than eight, got " .. #Shown(ns))
	K.Options.Write("Skins", "quests.shown", 3)
	for _ = 1, 8 do
		log.Untrack(log.quests[#log.quests].id)
	end
	env.RunTimers()
	assert(Ids(Shown(ns)) == "301,302", "two quests show whole, got " .. Ids(Shown(ns)))
	assert(not ns.Quests.Parts().thumb:IsShown(), "with no scroll bar")
	assert(not ns.Quests.Parts().more:IsShown(), "and no more line")
	for _ = 1, 2 do
		log.Untrack(log.quests[#log.quests].id)
	end
	env.RunTimers()
	assert(not ns.Quests.Card():IsShown(), "no tracked quests, no card")
	Clean(env, K)
end

-- The card fits the story slot at the owner's screen (2383 by 1540 at UI scale 768/1080) with fifteen quests of five
-- objectives each, with and without RestedXP: under the full party card, over the chat card, and the guide's card
-- too; three such quests are taller than the guide's half of the slot, so the card shows what fits ------------------

for _, withGuide in ipairs({ false, true }) do
	local env, K, ns, _, _, rxp = Boot({ screen = OWNER, quests = Quests.List(15, 5), rxp = withGuide })
	local Layouts = K.Setup.Layouts
	local story = K.Setup.Story("DPS", withGuide)
	local _, partyHeight = Layouts.Footprint("DPS", "groupframes.party")
	local partyBottom = 1080 - 28 - partyHeight
	local chat = Layouts.Element("chat.main")
	local chatTop = 28 + chat.height
	local card = RootRect(K, ns.Quests.Card())
	local what = withGuide and "with the guide" or "without the guide"
	assert(card.top <= partyBottom + 0.5, what .. ": the card starts under the party card, got " .. card.top .. " for " .. partyBottom)
	assert(card.bottom >= chatTop - 0.5, what .. ": the card ends over the chat card, got " .. card.bottom .. " for " .. chatTop)
	assert(card.bottom >= story.story.bottom - 0.5 and card.top <= story.story.top + 0.5, what .. ": inside the story slot")
	assert(math.abs(card.left - story.story.left) <= 0.6 and math.abs(card.right - story.story.right) <= 0.6, what .. ": on the rail's edge and width")
	assert(#Shown(ns) >= 1, what .. ": at least one quest shows")
	for _, row in ipairs(ns.Quests.Rows()) do
		if row:IsShown() then
			local r = RootRect(K, row)
			assert(r.bottom >= card.bottom - 0.5, what .. ": every quest shown sits whole inside the card")
		end
	end
	if withGuide then
		assert(#Shown(ns) < 3, "five-objective quests: fewer than three fit the guide's half, got " .. #Shown(ns))
	end
	if withGuide then
		assert(ns.RestedXP.Rail.Placed(), "the guide is placed")
		assert(ns.RestedXP.Rail.Docked(), "and docks the quest card into its card")
		local glass = assert(K.Skin.Parts(rxp.RXPFrame).backdrop, "the guide wears its glass")
		local g = RootRect(K, glass)
		assert(g.bottom >= chatTop - 0.5, "the guide's glass ends over the chat card too, got " .. g.bottom)
		assert(math.abs(g.bottom - card.bottom) <= 8.6, "and runs down to the card's foot, got " .. g.bottom .. " for " .. card.bottom)
		assert(g.top <= partyBottom + 0.5, "under the party card, got " .. g.top)
		assert(not ns.Quests.Parts().glass:IsShown(), "the card's own glass yields to the guide's")
		assert(card.top <= story.tracker.top + 0.5, "the card sits in the tracker's half")
	else
		assert(ns.Quests.Parts().glass:IsShown(), "on its own, the card wears its own glass")
		assert(ns.Quests.Parts().glass.chrome.gilt == nil, "with a thin rim and no gilt corner tips: the story card carries no ornament")
	end
	Clean(env, K)
end

-- Item buttons: a quest's item is a secure item button set out of combat; in combat nothing protected changes on
-- it, whatever happens to the quests, and the changes land when combat ends ------------------------------------------

do
	local list = Quests.List(10)
	list[1].item = { link = "|cffffffff|Hitem:5179::::::::|h[Moss-Twined Heart]|h|r", icon = 134339 }
	list[4].item = { link = "|cffffffff|Hitem:6145::::::::|h[Clarice's Pendant]|h|r", icon = 133279 }
	local heart, pendant = list[1].item.link, list[4].item.link
	local env, K, ns, log = Boot({ quests = list })
	local buttons = ns.Quests.Buttons()
	local used
	for _, button in ipairs(buttons) do
		if button:IsShown() then
			assert(not used, "one item button for the one item quest in view")
			used = button
		end
	end
	assert(used, "the item quest in view has its item button")
	assert(used._template and used._template:find("SecureActionButtonTemplate", 1, true), "built on SecureActionButtonTemplate")
	assert(used:GetAttribute("type") == "item", "type item")
	assert(used:GetAttribute("item") == heart, "using the quest's item")
	assert(used:GetParent() == env.UIParent, "parented to UIParent, so no KstyleUI frame turns protected")
	local marks = {}
	for i, button in ipairs(ns.Quests.Buttons()) do
		marks[i] = #button._calls
	end
	env.SetCombat(true)
	Wheel(ns, -1)
	Wheel(ns, -1)
	Wheel(ns, -1)
	list[1].complete = true
	log.Fire("QUEST_LOG_UPDATE")
	log.Untrack(301)
	log.super = 304
	log.Fire("SUPER_TRACKING_CHANGED")
	K.Options.Write("Skins", "quests.shown", 6)
	env.RunTimers()
	W.Settle(env)
	for i, button in ipairs(ns.Quests.Buttons()) do
		for n = (marks[i] or 0) + 1, #button._calls do
			local method = button._calls[n].method
			assert(not PROTECTED[method], "a protected " .. method .. " on an item button in combat")
		end
	end
	assert(#ns.Quests.Buttons() == #marks, "no item button is made in combat")
	env.SetCombat(false)
	env.RunTimers()
	W.Settle(env)
	local now
	for _, button in ipairs(ns.Quests.Buttons()) do
		if button:IsShown() then
			now = button
		end
	end
	assert(now and now:GetAttribute("item") == pendant, "after combat the item button follows the quests: the pendant's quest, now first")
	Clean(env, K)
end

-- Off: Blizzard's tracker comes back exactly as it was, and the card goes; on again, the card returns --------------

do
	local original = {}
	local env, K, ns, log, tracker = Boot()
	assert(ns.Quests.Active() and not tracker:IsVisible(), "the card stands in")
	original.parent = env.UIParent
	K.Options.Write("Skins", "quests.enabled", false)
	env.RunTimers()
	assert(not ns.Quests.Active(), "off, the card stands down")
	assert(not ns.Quests.Card():IsShown(), "and hides")
	assert(tracker:GetParent() == original.parent, "Blizzard's tracker is back on its own parent")
	assert(tracker:IsVisible(), "and shows")
	local point = { tracker:GetPoint(1) }
	assert(point[1] == "TOPRIGHT" and point[2] == env.UIParent and point[4] == -110 and point[5] == -275, "where Edit Mode put it")
	for _, button in ipairs(ns.Quests.Buttons()) do
		assert(not button:IsShown(), "no item button stays")
	end
	K.Widgets.RestyleAll()
	K.Options.Write("Skins", "text.size", 1.2)
	log.Fire("QUEST_LOG_UPDATE")
	env.RunTimers()
	assert(not ns.Quests.Card():IsShown() and tracker:IsVisible(), "a restyle, a text size change or a quest update never brings a switched-off card back")
	K.Options.Write("Skins", "text.size", 1)
	K.Options.Write("Skins", "quests.enabled", true)
	env.RunTimers()
	assert(ns.Quests.Active() and ns.Quests.Card():IsShown() and not tracker:IsVisible(), "on again, the card stands in again")
	assert(#log.calls == 0, "switching calls no quest action")
	Clean(env, K)
end

-- Scenarios, dungeons and delves stay in Blizzard's tracker: while it holds anything the card does not show, the
-- tracker shows instead of the card, and the card comes back when it ends; in combat the swap waits ----------------

do
	local env, K, ns, _, tracker = Boot()
	tracker.scenario.contentsHeight = 60
	tracker:Update()
	env.RunTimers()
	assert(tracker:IsVisible(), "a scenario stage brings Blizzard's tracker back")
	assert(not ns.Quests.Active() and not ns.Quests.Card():IsShown(), "in place of the card, so no quest shows twice")
	tracker.scenario.contentsHeight = 0
	env.SetCombat(true)
	tracker:Update()
	env.RunTimers()
	assert(tracker:IsVisible(), "in combat Blizzard's tracker stays until combat ends")
	env.SetCombat(false)
	env.RunTimers()
	assert(not tracker:IsVisible() and ns.Quests.Active() and ns.Quests.Card():IsShown(), "then the card takes the slot again")
	Clean(env, K)
end

-- An auto-complete quest's "click to complete" pop-up lives in Blizzard's quest module, which the card does not
-- draw: while one is up, Blizzard's tracker shows in place of the card, so the player can still complete the quest.

do
	local env, K, ns, log, tracker = Boot()
	log.popups = 1
	log.Fire("QUEST_AUTOCOMPLETE", 302)
	tracker:Update()
	env.RunTimers()
	assert(tracker:IsVisible() and not ns.Quests.Active(), "a quest pop-up brings Blizzard's tracker back")
	log.popups = 0
	tracker:Update()
	env.RunTimers()
	assert(not tracker:IsVisible() and ns.Quests.Active(), "and the card returns once it is gone")
	Clean(env, K)
end

-- While an item button is frozen in combat the card itself holds still too: a restyle, a layout change or entering
-- the world in combat moves nothing, so the button keeps covering its socket; the move lands after combat.

do
	local list = Quests.List(10)
	list[1].item = { link = "|cffffffff|Hitem:5179::::::::|h[Moss-Twined Heart]|h|r", icon = 134339 }
	local env, K, ns = Boot({ quests = list })
	local card = ns.Quests.Card()
	local mark = #card._calls
	env.SetCombat(true)
	K.Widgets.RestyleAll()
	env.FireEvent("PLAYER_ENTERING_WORLD")
	K.Options.Write("Layout", "preset", "Healer")
	env.RunTimers()
	for i = mark + 1, #card._calls do
		local method = card._calls[i].method
		assert(method ~= "SetPoint" and method ~= "ClearAllPoints" and method ~= "SetWidth", "the card does not move while its item button is frozen, got " .. method)
	end
	env.SetCombat(false)
	env.RunTimers()
	local story = K.Setup.Story("Healer", false).tracker
	local _, _, _, _, top = card:GetPoint(1)
	assert(math.abs(top - K.Widgets.Snap(card, story.top)) < 1 or math.abs(top - story.top) < 1, "after combat it moves to the new layout's slot, got " .. tostring(top) .. " for " .. story.top)
	Clean(env, K)
end

-- Clicks as Blizzard's tracker: a left click opens the quest's details, shift untracks, a right click opens the
-- quest's menu, whose first entry super-tracks it ---------------------------------------------------------------------

do
	local env, K, ns, log = Boot()
	local row = ns.Quests.Rows()[2]
	W.Click(row, "LeftButton")
	local opened = log.Called("OpenToQuestDetails")
	assert(#opened == 1 and opened[1].args[1] == 302, "a left click opens the quest's details")
	log.modified.QUESTWATCHTOGGLE = true
	W.Click(row, "LeftButton")
	log.modified.QUESTWATCHTOGGLE = nil
	env.RunTimers()
	local removed = log.Called("RemoveQuestWatch")
	assert(#removed == 1 and removed[1].args[1] == 302, "shift untracks it")
	assert(Ids(Shown(ns)) == "301,303,304", "and the card moves up, got " .. Ids(Shown(ns)))
	W.Click(ns.Quests.Rows()[1], "RightButton")
	assert(#log.Called("CreateContextMenu") == 1 and log.menu, "a right click opens the quest's menu")
	local track
	for _, entry in ipairs(log.menu) do
		if entry.fn and entry.text == env.SUPER_TRACK_QUEST then
			track = entry
		end
	end
	assert(track, "the menu's entries are Blizzard's own words")
	track.fn()
	env.RunTimers()
	assert(log.super == 301 and ns.Quests.Rows()[1].marked == true, "super-tracking from the menu marks the quest")
	Clean(env, K)
end

-- Ready to turn in, failed and finished objectives read at a glance -------------------------------------------------

do
	local list = Quests.List(3)
	list[1].complete = true
	list[2].failed = true
	list[3].objectives[1].finished = true
	local env, K, ns = Boot({ quests = list })
	local rows = ns.Quests.Rows()
	local function Lines(row)
		local out = {}
		for _, line in ipairs(row.lines) do
			if line.text:IsShown() then
				out[#out + 1] = line
			end
		end
		return out
	end
	local ready = Lines(rows[1])
	assert(#ready == 1 and ready[1].text:GetText() == "Ready for turn-in", "a complete quest reads Ready for turn-in, got " .. tostring(ready[1] and ready[1].text:GetText()))
	local fr, fg, fb = ready[1].text:GetTextColor()
	local gr, gg, gb = K.Tokens.Color("friend")
	assert(W.Near(fr, gr) and W.Near(fg, gg) and W.Near(fb, gb), "in the friendly green")
	local failed = Lines(rows[2])
	assert(#failed == 1 and failed[1].text:GetText() == "Failed", "a failed quest says so")
	local done = Lines(rows[3])
	assert(done[1].count:GetText() == "3/5", "a finished objective keeps its count, got " .. tostring(done[1].count:GetText()))
	local dr, dg, db = done[1].text:GetTextColor()
	local xr, xg, xb = K.Tokens.Color("textDisabled")
	assert(W.Near(dr, xr) and W.Near(dg, xg) and W.Near(db, xb), "and dims")
	assert(not done[1].text:GetText():find("%d+/%d+"), "the count sits in its own column, out of the words")
	Clean(env, K)
end

-- Without the quest API (an older client) the card stays out of the way and Blizzard's tracker keeps its quests ----

do
	local env, K, ns = S.New({
		before = function(env)
			Quests.Tracker(env, S.Blizzard(env))
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	assert(not ns.Quests.Active(), "no quest API, no card")
	assert(env.ObjectiveTrackerFrame:IsVisible(), "Blizzard's tracker keeps the quests")
	assert(S.Logged(env, "quest card"), "and the devlog says why")
	Clean(env, K)
end

-- The setting off from the first load: Blizzard's tracker is never touched ----------------------------------------

do
	local env, K, ns, _, tracker = Boot({ saved = Saved({ enabled = true, quests = { enabled = false } }) })
	assert(not ns.Quests.Active(), "off from the start")
	assert(tracker:GetParent() == env.UIParent and tracker:IsVisible(), "Blizzard's tracker is untouched")
	for _, call in ipairs(tracker._calls) do
		assert(call.method ~= "SetParent", "never reparented")
	end
	Clean(env, K)
end

print("test-skins-questcard: ok")
