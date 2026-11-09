-- test-skins-restedxp-rail.lua: the RestedXP guide takes the story rail's top half on the rail's edge and width as one card (cap, steps, route row, footer), its list folded by RestedXP's own rule; it follows the steps out of combat, comes back on entering the world, lets a player's drag win, docks the quests into its card when Apply placed them under it, and never writes RestedXP's settings.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local HOOKED = { SetAlpha = true, SetChecked = true, SetFont = true, SetText = true, UpdateVisuals = true, SetMinMaxValues = true, SetStep = true }

local function Boot(opts)
	opts = opts or {}
	local rxp
	local env, K, ns = S.New({
		setup = function(env)
			rxp = Fake.Install(env, opts)
		end,
	})
	K.Modules.Enable("Skins")
	env.RunTimers()
	return env, K, ns, rxp
end

local function Glass(K, frame)
	local parts = K.Skin.Parts(frame)
	return assert(parts and parts.backdrop, "glass on the frame")
end

-- Rect(K, object) -> the object's rect in KstyleUI's root units: RestedXP hangs from UIParent, whose units differ.
local function Rect(K, object)
	local env = K.Scale.Root()._env
	local r = assert(Geometry.Rect(object, env.UIParent))
	local s = env.UIParent:GetEffectiveScale() / K.Scale.Root():GetEffectiveScale()
	return { left = r.left * s, right = r.right * s, bottom = r.bottom * s, top = r.top * s }
end

local function near(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tolerance or 0.6)
end

local function Clean(env, K, rxp)
	rxp.fake.check(HOOKED)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	local profile = rxp.settings.profile
	assert(profile.framePositions == nil and profile.frameSizes == nil and profile.frameHeight == nil, "RestedXP's saved settings are never written")
end

-- The guide sits in the top half of the DPS story rail as one card: its glass on the rail's left edge and width,
-- the footer on the half's foot (one rail gap above the quests), the route row and the steps over it, the cap on
-- top of the card, the list folded.

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	rxp.SetStep(2)
	env.RunTimers()
	local band = K.Setup.Story("DPS", true).guide
	assert(band and ns.RestedXP.Rail.Placed(), "the guide is placed in the story rail")
	local point = { f:GetPoint(1) }
	assert(point[1] == "TOPLEFT" and point[2] == env.UIParent and point[3] == "BOTTOMLEFT", "from the screen's bottom left, so a UI scale change keeps it")
	local card = Rect(K, Glass(K, f))
	assert(near(card.left, band.left) and near(card.right, band.right), "the card's glass shares the rail's left edge and width, got " .. card.left .. " to " .. card.right .. " for " .. band.left .. " to " .. band.right)
	assert(near(card.bottom, band.bottom), "the card's foot, RestedXP's footer, sits on the half's foot, one rail gap above the quests")
	local path = ns.RestedXP.Chrome.Path(f)
	local cap = Rect(K, path.cap.row)
	local steps = Rect(K, f.CurrentStepFrame)
	local name = Rect(K, f.GuideName)
	local footer = Rect(K, f.Footer)
	assert(near(card.top, Rect(K, path.holder).top), "the card starts at the cap holder's top")
	assert(cap.top <= card.top and cap.bottom >= steps.top, "the cap sits inside the card's top, above the steps")
	assert(steps.bottom >= name.top - 0.5, "the steps end above the route row")
	assert(name.bottom >= footer.top - 0.5 or name.bottom >= footer.top - 9.5, "the route row ends above the footer")
	assert(card.top <= band.top + 0.5, "the cap and two steps fit inside the half, got " .. card.top .. " for " .. band.top)
	assert(not f.BottomFrame:IsShown(), "RestedXP folds its step list in the rail, so the rail reads the path, then the quests")
	for _, step in ipairs(f.CurrentStepFrame.framePool) do
		assert(not K.Skin.IsSkinned(step, "Backdrop"), "the steps are rows in the card, not cards of their own")
	end
	assert(path.capHeight >= 16 + 2 * K.Tokens.Size("gapSmall") - 0.01, "the cap holder is the cap row plus its air")
	Clean(env, K, rxp)
end

-- New steps stack upward over the head; anything that moves the window is undone on entering the world, and in
-- combat the guide waits for combat to end.

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	rxp.SetStep(1)
	env.RunTimers()
	local band = K.Setup.Story("DPS", true).guide
	rxp.SetStep(3, 2)
	env.RunTimers()
	assert(near(Rect(K, Glass(K, f)).bottom, band.bottom), "more steps keep the footer one gap above the quests")
	assert(Rect(K, f.CurrentStepFrame).bottom > Rect(K, f.GuideName).top, "and stack over the route row")
	f:ClearAllPoints()
	f:SetPoint("LEFT", env.UIParent, "LEFT", 0, 35)
	env.SetCombat(true)
	env.FireEvent("PLAYER_ENTERING_WORLD")
	env.RunTimers()
	assert(select(1, f:GetPoint(1)) == "LEFT", "nothing moves in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(select(1, f:GetPoint(1)) == "TOPLEFT" and near(Rect(K, Glass(K, f)).bottom, band.bottom), "after combat, entering the world's re-place runs")
	assert(ns.RestedXP.Rail.Placed(), "and the guide is placed")
	Clean(env, K, rxp)
end

-- A player's drag wins: the rail turns off and the guide stays put; turning the rail back on places it again,
-- and turning it off returns RestedXP's own place and size.

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	env.RunTimers()
	f:ClearAllPoints()
	f:SetPoint("CENTER", env.UIParent, "CENTER", 120, 0)
	f:GetScript("OnMouseUp")(f, "LeftButton")
	env.RunTimers()
	assert(ns.Skins.Setting("restedXP", "rail") == false, "a drag turns the story rail off")
	assert(S.W.CoreEnv.Printed(env, "Story rail"), "and tells the player how to turn it back on")
	env.FireEvent("PLAYER_ENTERING_WORLD")
	env.RunTimers()
	assert(select(1, f:GetPoint(1)) == "CENTER", "and the guide stays where the player put it")
	K.Options.Write("Skins", "restedXP.rail", true)
	env.RunTimers()
	assert(select(1, f:GetPoint(1)) == "TOPLEFT", "turning the rail on places it again")
	K.Options.Write("Skins", "restedXP.rail", false)
	env.RunTimers()
	assert(select(1, f:GetPoint(1)) == "CENTER" and select(4, f:GetPoint(1)) == 120, "turning it off gives back the place it had")
	-- RestedXP also starts the drag from its step cards: a drag that ends there counts too.
	K.Options.Write("Skins", "restedXP.rail", true)
	env.RunTimers()
	f:ClearAllPoints()
	f:SetPoint("CENTER", env.UIParent, "CENTER", -80, 0)
	f.CurrentStepFrame:GetScript("OnMouseUp")(f.CurrentStepFrame, "LeftButton")
	env.RunTimers()
	assert(ns.Skins.Setting("restedXP", "rail") == false, "a drag from the step cards turns the rail off too")
	-- A click that moves nothing leaves the rail on.
	K.Options.Write("Skins", "restedXP.rail", true)
	env.RunTimers()
	f:GetScript("OnMouseUp")(f, "LeftButton")
	env.RunTimers()
	assert(ns.Skins.Setting("restedXP", "rail") == true, "a click without a drag keeps the rail")
	Clean(env, K, rxp)
end

do
	local env, K, _, rxp = Boot()
	local f = rxp.RXPFrame
	env.RunTimers()
	K.Options.Write("Skins", "restedXP.rail", false)
	env.RunTimers()
	local point = { f:GetPoint(1) }
	assert(point[1] == "LEFT" and point[4] == 0 and point[5] == 35, "off, the guide is back at RestedXP's own place")
	assert(f:GetWidth() == 235 and f:GetHeight() == 125, "at RestedXP's own size")
	f.BottomFrame.UpdateFrame()
	assert(f.BottomFrame:IsShown(), "with its step list")
	Clean(env, K, rxp)
end

-- A resize ends in RestedXP's own OnMouseUp, which calls SetStep and so queues a placement before KstyleUI's hook
-- runs: the hook checks at once, so the player's size wins and the rail turns off (round 2, Codex review).

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	env.RunTimers()
	assert(ns.RestedXP.Rail.Placed())
	local point = { f:GetPoint(1) }
	f:SetSize(300, 200)
	rxp.SetStep(1)
	f:GetScript("OnMouseUp")(f, "LeftButton")
	env.RunTimers()
	assert(ns.Skins.Setting("restedXP", "rail") == false, "a resize turns the rail off")
	assert(f:GetWidth() == 300 and f:GetHeight() == 200, "and the player's size stays, got " .. f:GetWidth() .. " by " .. f:GetHeight())
	assert(select(5, f:GetPoint(1)) == point[5], "where it was")
	Clean(env, K, rxp)
end

-- A profile switch refreshes every setting at once (OnSetting with no field): a profile with the rail off gives the
-- guide back its own place, and one with the rail on places it again.

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	env.RunTimers()
	K.Store.Module("Skins").restedXP = { rail = false }
	ns.Skins.Get("restedXP").OnSetting(ns.Skins.Get("restedXP"), nil)
	env.RunTimers()
	assert(select(1, f:GetPoint(1)) == "LEFT" and f:GetWidth() == 235, "a profile with the rail off restores RestedXP's own place and size")
	K.Store.Module("Skins").restedXP = { rail = true }
	ns.Skins.Get("restedXP").OnSetting(ns.Skins.Get("restedXP"), nil)
	env.RunTimers()
	assert(select(1, f:GetPoint(1)) == "TOPLEFT" and ns.RestedXP.Rail.Placed(), "a profile with the rail on places it again")
	Clean(env, K, rxp)
end

-- The cap measures its row: the guide's name takes its natural width while the row has room for it, the step
-- and the rule; on a row too narrow for it, it is clamped to the room and ellipsises, never the step.

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	K.Options.Write("Skins", "restedXP.rail", false)
	env.RunTimers()
	rxp.SetStep(1)
	local path = ns.RestedXP.Chrome.Path(f)
	path.cap.title.GetUnboundedStringWidth = function() return 90 end
	path.cap.trail.GetUnboundedStringWidth = function(self) return self:GetText() ~= "" and 40 or 0 end
	f.GuideName.text:SetText("6-10 Durotar\nSpeedrun Guide 1-22")
	local function At(width)
		path.cap.row:SetWidth(width)
		path.cap:Fit()
	end
	At(400)
	assert(path.cap.trail:GetText() == "Step 1" and path.cap.title:GetWidth() == 0, "wide: the step rides in the cap's trail and the name takes its natural width")
	assert(path.meta:IsShown() and path.meta:GetText() == "Speedrun Guide 1-22", "the route has its own caption row")
	At(120)
	assert(path.cap.title:GetWidth() > 0 and path.cap.title:GetWidth() < 90, "narrow: the name is clamped to the room before the step, got " .. tostring(path.cap.title:GetWidth()))
	assert(path.cap.trail:GetText() == "Step 1", "and the step stays whole")
	local _, relative, _, _, top = f.ScrollFrame:GetPoint(1)
	assert(relative == f.BottomFrame and -top >= 9, "the list's view starts under RestedXP's header overlap, got " .. tostring(top))
	local bottom = select(5, f.ScrollFrame:GetPoint(2))
	local clear = K.Widgets.Snap(f.ScrollFrame, 6 + K.Tokens.Size("gapSmall"))
	assert(math.abs(bottom - clear) < 0.01, "and ends a gap above the footer, which covers the list's last 6 units, so no row overprints it, got " .. tostring(bottom))
	Clean(env, K, rxp)
end

-- Docking the quests (round 3, Grok and Muse: one story rail): when Apply's Edit Mode layout holds the tracker
-- under the guide, the guide's card runs down to the tracker glass's foot and the tracker's own glass yields, so
-- the rail reads as one card with two caps; a tracker the player moved keeps its own glass; the setting turns
-- it off; an Edit Mode change re-checks.

local function TrackerStandIn(env, B)
	local StandIn = dofile("Tools/render/scenes/_tracker.lua")
	return StandIn.StandIn(env, B, StandIn.QUESTS)
end

local function BootWithTracker(place)
	local rxp, tracker
	local env, K, ns = S.New({
		setup = function(env)
			rxp = Fake.Install(env, {})
		end,
		before = function(env, K)
			tracker = TrackerStandIn(env, S.Blizzard(env))
			if place then
				local story = K.Setup.Story("DPS", true)
				local at = K.Setup.EditMode.TrackerPlace(story.tracker)
				local scale = K.Widgets.ScaleFactor(tracker)
				tracker:ClearAllPoints()
				tracker:SetPoint("TOPLEFT", env.UIParent, "BOTTOMLEFT", at.x / scale + (place.dx or 0), at.y / scale + (place.dy or 0))
			end
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	return env, K, ns, rxp, tracker
end

do
	local env, K, ns, rxp, tracker = BootWithTracker({})
	local f = rxp.RXPFrame
	assert(ns.Skins.IsApplied("tracker") and ns.RestedXP.Rail.Placed(), "both skins are on and the guide is placed")
	assert(ns.RestedXP.Rail.Docked() and ns.Tracker.Docked(), "with the tracker at Apply's anchor the quests dock into the guide's card")
	local trackerGlass = K.Skin.Parts(tracker).backdrop
	assert(trackerGlass and not trackerGlass:IsShown(), "the tracker's own glass yields")
	local card = ns.RestedXP.Chrome.Card(f)
	local bottom = card._points[3]
	assert(bottom[1] == "BOTTOM" and bottom[2] == ns.Tracker.Fit(), "the card's foot follows the tracker skin's fit frame")
	assert(near(bottom[5], -K.Widgets.Snap(card, 8), 0.01), "down to where the tracker's glass ended, 8 under the fit, got " .. tostring(bottom[5]))
	local glass = Rect(K, Glass(K, f))
	local quests = Rect(K, ns.Tracker.Fit())
	assert(glass.bottom <= quests.bottom + 0.5, "one glass from the cap to the quests' foot")
	-- The setting turns it off: two cards again.
	K.Options.Write("Skins", "restedXP.dock", false)
	env.RunTimers()
	assert(not ns.RestedXP.Rail.Docked() and not ns.Tracker.Docked() and trackerGlass:IsShown(), "with the setting off the tracker keeps its own glass")
	assert(card._points[3][2] == f, "and the card ends at the footer")
	K.Options.Write("Skins", "restedXP.dock", true)
	env.RunTimers()
	assert(ns.RestedXP.Rail.Docked() and not trackerGlass:IsShown(), "on again, docked again")
	-- The tracker's glass setting off means nothing to dock to.
	K.Options.Write("Skins", "tracker.panel", false)
	env.RunTimers()
	ns.RestedXP.Rail.Place()
	assert(not ns.RestedXP.Rail.Docked(), "with the tracker's glass off there is no dock")
	K.Options.Write("Skins", "tracker.panel", true)
	env.RunTimers()
	ns.RestedXP.Rail.Place()
	assert(ns.RestedXP.Rail.Docked())
	-- The player moves the tracker in Edit Mode: the layouts update, and the guide lets it keep its own glass.
	tracker:ClearAllPoints()
	tracker:SetPoint("TOPLEFT", env.UIParent, "BOTTOMLEFT", 600, 500)
	env.FireEvent("EDIT_MODE_LAYOUTS_UPDATED")
	env.RunTimers()
	assert(not ns.RestedXP.Rail.Docked() and trackerGlass:IsShown(), "a tracker moved out of the slot undocks")
	tracker:ClearAllPoints()
	local story = K.Setup.Story("DPS", true)
	local at = K.Setup.EditMode.TrackerPlace(story.tracker)
	local scale = K.Widgets.ScaleFactor(tracker)
	tracker:SetPoint("TOPLEFT", env.UIParent, "BOTTOMLEFT", at.x / scale, at.y / scale)
	env.FireEvent("EDIT_MODE_LAYOUTS_UPDATED")
	env.RunTimers()
	assert(ns.RestedXP.Rail.Docked(), "back in the slot, docked")
	-- RestedXP hides its guide (the player's hide key, a hidewindow step): the card goes with it, so the tracker
	-- gets its own glass back at once, and docks again when the guide shows (round 3, Codex review).
	rxp.fake.close(f)
	assert(not ns.RestedXP.Rail.Docked() and trackerGlass:IsShown(), "a hidden guide undocks the quests")
	rxp.fake.open(f)
	env.RunTimers()
	assert(ns.RestedXP.Rail.Docked() and not trackerGlass:IsShown(), "and a shown guide docks them again")
	-- The rail off undocks too.
	K.Options.Write("Skins", "restedXP.rail", false)
	env.RunTimers()
	assert(not ns.RestedXP.Rail.Docked() and trackerGlass:IsShown(), "the rail off gives the tracker its glass back")
	Clean(env, K, rxp)
end

do
	local env, K, ns, rxp, tracker = BootWithTracker({ dx = 40 })
	assert(ns.RestedXP.Rail.Placed() and not ns.RestedXP.Rail.Docked(), "a tracker 40 units off Apply's anchor is the player's: no dock")
	assert(K.Skin.Parts(tracker).backdrop:IsShown(), "it keeps its own glass")
	Clean(env, K, rxp)
end

do
	local env, K, ns, rxp = BootWithTracker(nil)
	assert(ns.RestedXP.Rail.Placed() and not ns.RestedXP.Rail.Docked(), "a tracker at Forever's preset, top right, does not dock")
	Clean(env, K, rxp)
end

print("skins restedxp rail ok")
