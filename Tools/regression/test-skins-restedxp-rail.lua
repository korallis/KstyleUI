-- test-skins-restedxp-rail.lua: the RestedXP guide takes the story rail's top half on the rail's edge and width, its steps above a head that holds the logo and both text rows, its list folded by RestedXP's own rule; it follows the steps out of combat, comes back on entering the world, lets a player's drag win, and never writes RestedXP's settings.
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

-- The guide sits in the top half of the DPS story rail: every glass on the rail's left edge and width, the footer
-- on the half's foot (one rail gap above the quests), the head over it, the steps over the head, the list folded.

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	rxp.SetStep(2)
	env.RunTimers()
	local band = K.Setup.Story("DPS", true).guide
	assert(band and ns.RestedXP.Rail.Placed(), "the guide is placed in the story rail")
	local point = { f:GetPoint(1) }
	assert(point[1] == "TOPLEFT" and point[2] == env.UIParent and point[3] == "BOTTOMLEFT", "from the screen's bottom left, so a UI scale change keeps it")
	local head = Rect(K, Glass(K, f.GuideName))
	local footer = Rect(K, Glass(K, f.Footer))
	local steps = {}
	for i, step in ipairs(f.CurrentStepFrame.framePool) do
		steps[i] = Rect(K, Glass(K, step))
	end
	for what, r in pairs({ head = head, footer = footer, step1 = steps[1], step2 = steps[2] }) do
		assert(near(r.left, band.left) and near(r.right, band.right), what .. "'s glass shares the rail's left edge and width, got " .. r.left .. " to " .. r.right .. " for " .. band.left .. " to " .. band.right)
	end
	assert(near(footer.bottom, band.bottom), "the footer sits on the half's foot, one rail gap above the quests")
	assert(steps[2].bottom >= head.top, "the last step's glass ends above the head's glass")
	assert(head.bottom >= footer.top - 0.5, "the head's glass ends above the footer, so no line overprints it")
	assert(Rect(K, f.CurrentStepFrame).top <= band.top + 0.5, "two steps fit inside the half")
	assert(not f.BottomFrame:IsShown(), "RestedXP folds its step list in the rail, so the rail reads the path, then the quests")
	-- The head holds RestedXP's 42-unit logo, which hangs 3.5 above and below its 35-unit header.
	local path = ns.RestedXP.Chrome.Path(f)
	local name = Rect(K, f.GuideName)
	local center = (name.top + name.bottom) / 2
	assert(head.top >= center + 21 - 0.5 and head.bottom <= center - 21 + 0.5, "the head's glass holds the whole logo")
	assert(path.height >= 16 + 2, "and the cap row and the zone heading")
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
	assert(near(Rect(K, Glass(K, f.Footer)).bottom, band.bottom), "more steps keep the footer one gap above the quests")
	assert(Rect(K, f.CurrentStepFrame).bottom > Rect(K, f.GuideName).top, "and stack over the head")
	f:ClearAllPoints()
	f:SetPoint("LEFT", env.UIParent, "LEFT", 0, 35)
	env.SetCombat(true)
	env.FireEvent("PLAYER_ENTERING_WORLD")
	env.RunTimers()
	assert(select(1, f:GetPoint(1)) == "LEFT", "nothing moves in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(select(1, f:GetPoint(1)) == "TOPLEFT" and near(Rect(K, Glass(K, f.Footer)).bottom, band.bottom), "after combat, entering the world's re-place runs")
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

-- The head measures its rows: the route goes in the cap's trail when it fits, the cap drops its THE PATH wording
-- when only the route fits, and the route takes its own caption row under the zone heading when neither fits.

do
	local env, K, ns, rxp = Boot()
	local f = rxp.RXPFrame
	K.Options.Write("Skins", "restedXP.rail", false)
	env.RunTimers()
	local path = ns.RestedXP.Chrome.Path(f)
	path.cap.title.GetUnboundedStringWidth = function() return 90 end
	path.cap.trail.GetUnboundedStringWidth = function(self) return self:GetText() ~= "" and 110 or 0 end
	f.GuideName.text:SetText("6-10 Durotar\nSpeedrun Guide 1-22")
	local function At(width)
		path.cap.row:SetWidth(width)
		path:Restyle()
	end
	At(400)
	local wide = path.height
	assert(path.cap.trail:GetText() == "Speedrun Guide 1-22" and not path.narrow and not path.meta:IsShown(), "wide: the route rides in the cap's trail")
	At(190)
	assert(path.narrow and path.cap.title:GetText() == "" and path.cap.trail:GetText() == "Speedrun Guide 1-22", "narrow: the cap drops THE PATH and keeps the route")
	At(110)
	assert(path.meta:IsShown() and path.meta:GetText() == "Speedrun Guide 1-22" and path.cap.trail:GetText() == "", "narrower: the route takes its own row")
	assert(path.cap.title:GetText() ~= "", "and the cap reads THE PATH again")
	assert(path.height > wide, "the head grows by the route's row, measured, so nothing crowds")
	local metaTop = path.meta._points[1]
	assert(metaTop[2] == path.heading and metaTop[3] == "BOTTOMLEFT", "under the zone heading")
	local _, relative, _, _, top = f.ScrollFrame:GetPoint(1)
	assert(relative == f.BottomFrame and -top >= path.height - 26, "the list's view starts under the taller head, got " .. tostring(top))
	local bottom = select(5, f.ScrollFrame:GetPoint(2))
	local clear = K.Widgets.Snap(f.ScrollFrame, 6 + K.Tokens.Size("gapSmall"))
	assert(math.abs(bottom - clear) < 0.01, "and ends a gap above the footer, which covers the list's last 6 units, so no row overprints it, got " .. tostring(bottom))
	Clean(env, K, rxp)
end

print("skins restedxp rail ok")
