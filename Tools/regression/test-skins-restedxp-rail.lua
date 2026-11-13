-- test-skins-restedxp-rail.lua: the RestedXP guide hangs from the top of its own Layout element, the story slot, on the rail's edge and width as one card (cap, steps, route row), with the quests in a column of their own beside it, RestedXP's window folded to its floor and its list folded by RestedXP's own rule; it follows the steps out of combat, comes back on entering the world, lets a player's drag win, never reaches into the quests, and keeps the rail's placement out of RestedXP's saved settings.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local HOOKED = { SetAlpha = true, SetChecked = true, SetFont = true, SetFontObject = true, SetText = true, Show = true, Hide = true, SetShown = true, UpdateVisuals = true, SetMinMaxValues = true, SetStep = true, SetScale = true, StopMovingOrSizing = true }

-- Sized(size) -> saved data at that Interface size. The tests run at the shipped size (16 / 19), as the game does: the
-- story slot is sized for it, and is far shorter at size 1.
local function Sized(size)
	return { version = 9, profiles = { Default = { Appearance = { uiScale = size } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local booted = {}

local function Boot(opts)
	opts = opts or {}
	local rxp
	local saved = Sized(16 / 19)
	if opts.preset then
		saved.profiles.Default.Layout = { preset = opts.preset }
	end
	local env, K, ns = S.New({
		saved = saved,
		setup = function(env)
			rxp = Fake.Install(env, opts)
		end,
	})
	K.Modules.Enable("Skins")
	env.RunTimers()
	booted.ns = ns
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

-- Clean(env, K, rxp): nothing was written onto RestedXP's objects, nothing raised, and RestedXP's saved settings hold
-- nothing of the rail's. RestedXP saves every window's place and size itself, on each mouse-up on one of its windows
-- and at logout (SettingsPanel.lua 4327, RXPGuides.lua 1831), so the check logs out first: while the rail holds the
-- guide, that save must leave RestedXP's entry for the guide as it was.
local function Clean(env, K, rxp)
	rxp.fake.check(HOOKED)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	local profile = rxp.settings.profile
	assert(profile.frameHeight == nil, "the rail's height never reaches RestedXP's saved frameHeight")
	local placed = booted.ns.RestedXP.Rail.Placed() ~= nil
	local before = profile.framePositions and profile.framePositions.RXPFrame
	local sizeBefore = profile.frameSizes and profile.frameSizes.RXPFrame
	rxp.fake.logout()
	local after, sizeAfter = profile.framePositions.RXPFrame, profile.frameSizes.RXPFrame
	if placed then
		assert(after == before and sizeAfter == sizeBefore, "RestedXP's logout save leaves the guide's saved place and size alone while the rail holds it")
		assert(profile.framePositions.arrowFrame, "and still saves RestedXP's other windows")
	else
		assert(after and after[1] and sizeAfter, "with the rail off RestedXP saves the guide's place as ever")
	end
end

-- The guide's card is its own Layout element, the whole story slot (KSTY-33, the Captain's ruling on the Fable audit:
-- two cards, two Layout elements); the quests stand in a column of their own a rail gap to its left, at the same top.
-- One card on the rail's left edge and width, hanging from the slot's top, the cap over the steps and the route row
-- under them, RestedXP's window folded to its 28-unit floor behind them, the list folded.

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	rxp.SetStep(2)
	env.RunTimers()
	local story = K.Setup.Story("DPS", true)
	local rw, rh = K.Layout.RootSize()
	local slot = K.Setup.Layouts.Slot("DPS", rh)
	local sl, sb, sr, st = K.Setup.Layouts.Rect(slot, slot, rw, rh)
	local band = story.guide
	local px = K.Scale.Pixel(1) + 0.01
	assert(near(band.left, sl, px) and near(band.right, sr, px) and near(band.top, st, px) and near(band.bottom, sb, px), "the guide's element is the whole story slot")
	assert(K.Layout.Get("skins.guide") ~= nil, "a Layout element of its own, with its own mover")
	assert(near(story.tracker.right, band.left - 16, px) and near(story.tracker.top, band.top, px), "the quests' column stands a rail gap to its left, at the same top")
	assert(ns.RestedXP.Rail.Placed(), "the guide is placed in the story rail")
	local point = { f:GetPoint(1) }
	assert(point[1] == "TOPLEFT" and point[2] == env.UIParent and point[3] == "BOTTOMLEFT", "from the screen's bottom left, so a UI scale change keeps it")
	local card = Rect(K, Glass(K, f))
	assert(near(card.left, band.left, 0.01) and near(card.right, band.right, 0.01), "the card's glass shares the rail's left edge and width to the pixel, got " .. card.left .. " to " .. card.right .. " for " .. band.left .. " to " .. band.right)
	assert(near(card.top, band.top, 0.01), "the card hangs from the slot's top, to the pixel, got " .. card.top .. " for " .. band.top)
	assert(card.bottom >= band.bottom - 0.5, "and ends inside the slot, got " .. card.bottom .. " for " .. band.bottom)
	local path = ns.RestedXP.Chrome.Path(f)
	local cap = Rect(K, path.cap.row)
	local steps = Rect(K, f.CurrentStepFrame)
	local name = Rect(K, f.GuideName)
	assert(near(card.top, Rect(K, path.holder).top), "the card starts at the cap holder's top")
	assert(cap.top <= card.top and cap.bottom >= steps.top - 12 * K.Widgets.ScaleFactor(f) - 0.5, "the cap sits inside the card's top, over the first step's empty head")
	assert(steps.bottom >= name.top - 0.5, "the steps end above the route row")
	assert(card.bottom <= name.bottom + 0.5 and card.bottom >= name.bottom - 6 * K.Widgets.ScaleFactor(f), "the card ends a small gap under the route row, not under RestedXP's resting footer, got " .. card.bottom .. " for " .. name.bottom)
	assert(near(f:GetHeight(), 28, 0.05), "RestedXP's window is folded to its own floor, 28 (GuideWindow.lua 2363), got " .. f:GetHeight())
	assert(not f.BottomFrame:IsShown(), "RestedXP folds its step list in the rail, so the rail reads the path, then the quests")
	for _, step in ipairs(f.CurrentStepFrame.framePool) do
		assert(not K.Skin.IsSkinned(step, "Backdrop"), "the steps are rows in the card, not cards of their own")
	end
	local factor = K.Widgets.ScaleFactor(path.holder)
	local function Root(units)
		return K.Widgets.Snap(path.holder, units / factor)
	end
	assert(near(path.capHeight, Root(12.5) + Root(19) + Root(6) - K.Widgets.Snap(path.holder, 12), 0.01), "the cap adds its head, its row and its foot, less the 12 units it shares with the first step's empty head")
	assert(near(card.top - cap.top, 12.5, 0.6) and near(cap.top - cap.bottom, 19, 0.6), "the caption's row is 19 root units and starts 12.5 under the glass's top at any RestedXP scale, as the picture draws it, got " .. card.top - cap.top .. " and " .. cap.top - cap.bottom)
	-- Three steps of two lines each still hang from the top and stay in the slot.
	rxp.SetStep(3, 2)
	env.RunTimers()
	card = Rect(K, Glass(K, f))
	assert(near(card.top, band.top) and card.bottom >= band.bottom - 0.5, "more steps grow downward inside the slot, got " .. card.top .. " to " .. card.bottom)
	Clean(env, K, rxp)
end

-- Every layout: the card hangs from that layout's slot top, on its edges, and ends inside it (the Captain's rule,
-- 2026-11-10: nothing leaves the slot in any preset).

for _, preset in ipairs({ "DPS", "Tank", "Healer" }) do
	local env, K, ns, rxp = Boot({ preset = preset })
	local f = rxp.RXPFrame
	rxp.SetStep(2, 2)
	env.RunTimers()
	assert(K.Layout.Setting("preset") == preset and ns.RestedXP.Rail.Placed(), preset .. ": the rail places the guide for the layout")
	local slot = K.Setup.Story(preset, true).guide
	local card = Rect(K, Glass(K, f))
	assert(near(card.top, slot.top, 0.01) and near(card.left, slot.left, 0.01) and near(card.right, slot.right, 0.01), preset .. ": the card is on the slot's top and edges, got " .. card.left .. " to " .. card.right .. " at " .. card.top)
	assert(card.bottom >= slot.bottom - 0.5, preset .. ": and ends inside the slot, got " .. card.bottom .. " for " .. slot.bottom)
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
	assert(near(Rect(K, Glass(K, f)).top, band.top), "more steps keep the card's top on the slot's top")
	assert(Rect(K, f.CurrentStepFrame).bottom > Rect(K, f.GuideName).top, "and stack over the route row")
	f:ClearAllPoints()
	f:SetPoint("LEFT", env.UIParent, "LEFT", 0, 35)
	env.SetCombat(true)
	env.FireEvent("PLAYER_ENTERING_WORLD")
	env.RunTimers()
	assert(select(1, f:GetPoint(1)) == "LEFT", "nothing moves in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(select(1, f:GetPoint(1)) == "TOPLEFT" and near(Rect(K, Glass(K, f)).top, band.top), "after combat, entering the world's re-place runs")
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

print("skins restedxp rail ok")
