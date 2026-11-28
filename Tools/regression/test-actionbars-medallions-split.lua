-- test-actionbars-medallions-split.lua: KSTY-171 part 1, from a player's report that the medallion disappears when they change the panels. Under Medallions, bars 1 and 2 out of line, the slab switched off, or either bar off or toggled away, splits the slab: each shown bar wears its own plate and the crest stays on the Crest Layout element, at the joined gap's spot until moved; back in line the slab returns. Gamepad mode still hides both.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Fixture = dofile("Tools/regression/travel_fixture.lua")

local CREST = "actionbars.crest"

local function Rect(region)
	local s = region:GetEffectiveScale()
	return { region:GetLeft() * s, region:GetBottom() * s, region:GetRight() * s, region:GetTop() * s }
end

local function Centre(region)
	local r = Rect(region)
	return (r[1] + r[3]) / 2, (r[2] + r[4]) / 2, r[3] - r[1]
end

local function Holds(plate, bar, what)
	local p = Rect(plate)
	for i = 1, 12 do
		local r = Rect(bar.buttons[i])
		assert(r[1] >= p[1] and r[3] <= p[3] and r[2] >= p[2] and r[4] <= p[4], what .. ": " .. bar.def.key .. "'s plate holds slot " .. i)
	end
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 } }) do
	local width, height = screen[1], screen[2]
	local env, K, ns = AB.New({ width = width, height = height, class = "WARLOCK", setup = function(e)
		e._game.bindings["CLICK KstyleUI_Toggle_bar1:LeftButton"] = { "F9" }
		e._game.bindings["CLICK KstyleUI_Toggle_bar2:LeftButton"] = { "F10" }
		e._resolveRects = true
	end })
	Fixture.Install(env, true)
	AB.Hiding(env)
	AB.Enable(env, K)
	env.RunTimers()
	local Slab, Layout = ns.Slab, K.Layout
	local bar2 = ns.bars.bar2
	local hub, slab, crest = Slab.hub, Slab.frame, Slab.crest
	local px = 768 / height * 1.01
	local x0, y0, w0 = Centre(hub)
	local function Joined(what)
		assert(slab:IsShown() and hub:IsVisible(), what .. ": the slab and the crest are shown")
		assert(not Layout.Live(CREST), what .. ": the Crest element is not live while the gap places the crest")
		assert(hub:GetParent() == (Layout.Get(CREST).shown == "always" and K.Scale.Root() or Slab.Gate()), what .. ": the crest sits in the gap, not on its element")
		assert(not (Slab.sides.bar1 and Slab.sides.bar1:IsShown()) and not (Slab.sides.bar2 and Slab.sides.bar2:IsShown()), what .. ": no plate of their own on joined bars")
		local x, y, w = Centre(hub)
		assert(math.abs(x - x0) < 1e-6 and math.abs(y - y0) < 1e-6 and math.abs(w - w0) < 1e-6, what .. ": the crest is back where it was")
	end
	local function Split(what, one, two)
		assert(not slab:IsShown(), what .. ": the joined slab plate hides")
		assert(hub:IsVisible(), what .. ": the crest stays")
		assert(Layout.Live(CREST) and hub:GetParent() == crest, what .. ": the crest stands on the live Crest element")
		for key, on in pairs({ bar1 = one, bar2 = two }) do
			local plate = Slab.sides[key]
			assert((plate and plate:IsVisible() or false) == on, what .. ": " .. key .. (on and " wears" or " does not wear") .. " its own plate")
			if on then Holds(plate, ns.bars[key], what) end
		end
	end
	-- Held: split in combat from joined, the crest keeps the gap until combat ends, so its secure controls, which
	-- cannot move in combat, stay over it.
	local function Held(what, one, two)
		assert(not slab:IsShown() and hub:IsVisible(), what .. ": the joined slab plate hides and the crest stays")
		assert(not Layout.Live(CREST) and hub:GetParent() == (Layout.Get(CREST).shown == "always" and K.Scale.Root() or Slab.Gate()), what .. ": the crest keeps the gap until combat ends")
		local x, y = Centre(hub)
		assert(math.abs(x - x0) < 1e-6 and math.abs(y - y0) < 1e-6, what .. ": where it was")
		for key, on in pairs({ bar1 = one, bar2 = two }) do
			local plate = Slab.sides[key]
			assert((plate and plate:IsVisible() or false) == on, what .. ": " .. key .. (on and " wears" or " does not wear") .. " its own plate")
		end
	end
	local what = width .. "x" .. height
	Joined(what .. " at first")
	assert(Layout.Get(CREST).scale == 1, what .. ": the crest starts at scale 1")

	local y = Layout.Get("actionbars.bar2").y
	assert(Layout.Set("actionbars.bar2", "y", y + 14))
	env.RunTimers()
	Split(what .. " bar 2 up 14", true, true)
	local x, yc, w = Centre(hub)
	assert(math.abs(x - x0) <= px and math.abs(yc - y0) <= px and math.abs(w - w0) <= px, string.format("%s: the split crest keeps the gap's spot within a pixel, moved %.2f %.2f", what, x - x0, yc - y0))
	assert(Layout.Set("actionbars.bar2", "y", y))
	env.RunTimers()
	Joined(what .. " bar 2 back in line")

	K.Options.Write("ActionBars", "slab", false)
	env.RunTimers()
	Split(what .. " slab off", true, true)
	-- Slab off, the default bars stand clear of the crest so their larger buttons do not cover it.
	local ring = Rect(hub)
	for i = 1, 12 do
		local one, two = Rect(ns.bars.bar1.buttons[i]), Rect(bar2.buttons[i])
		assert(one[3] <= ring[1] + px and two[1] >= ring[3] - px, string.format("%s slab off: slot %d of bars 1 and 2 clears the crest, %.1f and %.1f against %.1f to %.1f", what, i, one[3], two[1], ring[1], ring[3]))
	end
	K.Options.Write("ActionBars", "slab", true)
	env.RunTimers()
	Joined(what .. " slab on")

	K.Options.Write("ActionBars", "bar2.enabled", false)
	env.RunTimers()
	Split(what .. " bar 2 off", true, false)
	K.Options.Write("ActionBars", "bar2.enabled", true)
	env.RunTimers()
	Joined(what .. " bar 2 on")

	assert(AB.PressKey(env, "F9"))
	env.RunTimers()
	Split(what .. " bar 1 toggled away", false, true)
	assert(AB.PressKey(env, "F9"))
	env.RunTimers()
	Joined(what .. " bar 1 toggled back")

	-- The Crest element: moving, scaling and hiding it carries the crest and its secure travel button while split.
	local travel = ns.Travel.crest
	local function Travels(case)
		local tl, tb, tw, th = travel:GetRect()
		local vl, vb, vw, vh = hub.crest:GetRect()
		local ts, vs = travel:GetEffectiveScale(), hub.crest:GetEffectiveScale()
		assert(travel:IsShown(), case .. ": the travel button is on the crest")
		assert(math.abs(tl * ts - vl * vs) < 0.5 and math.abs(tb * ts - vb * vs) < 0.5 and math.abs(tw * ts - vw * vs) < 0.5 and math.abs(th * ts - vh * vs) < 0.5, case .. ": the travel button covers the crest")
	end
	assert(Layout.Set("actionbars.bar2", "y", y + 14))
	env.RunTimers()
	local c = Layout.Get(CREST)
	assert(Layout.Set(CREST, "x", c.x + 100))
	env.RunTimers()
	local mx, my = Centre(hub)
	local unit = K.Scale.Root():GetEffectiveScale()
	assert(math.abs((mx - x) / unit - 100) < 2 * px / unit and math.abs(my - yc) < 2 * px, string.format("%s: moving the element 100 units moves the crest, got %.2f", what, (mx - x) / unit))
	assert(Layout.Set(CREST, "scale", 1.5))
	env.RunTimers()
	local _, _, mw = Centre(hub)
	assert(math.abs(mw / w - 1.5) < 0.01, what .. ": scaling the element to 1.5 scales the crest, got " .. mw / w)
	Travels(what .. " moved and scaled")
	assert(Layout.Set(CREST, "shown", "never"))
	env.RunTimers()
	assert(not hub:IsVisible(), what .. ": Shown never on the element hides the crest")
	assert(not travel:IsShown() and not (ns.Travel.menu and ns.Travel.menu:IsShown()), what .. ": and its travel button")
	assert(Layout.Set(CREST, "shown", "always"))
	env.RunTimers()
	assert(hub:IsVisible(), what .. ": and Always brings it back")
	Travels(what .. " shown again")
	local sx, sy = Centre(hub)

	-- A Crest element shown only out of combat takes its travel button and an open travel menu away in combat,
	-- through the secure gate's state driver, and gives them back after.
	assert(Layout.Set(CREST, "shown", "noCombat"))
	env.RunTimers()
	AB.W.Enter(travel)
	AB.W.Leave(travel)
	AB.Click(env, travel, "RightButton", false)
	assert(ns.Travel.menu and ns.Travel.menu:IsVisible(), what .. ": the travel menu opens on the split crest")
	env.SetCombat(true)
	env.RunTimers()
	assert(not hub:IsVisible() and not travel:IsVisible() and not ns.Travel.menu:IsVisible(), what .. ": in combat the crest, its travel button and the open menu are gone")
	env.SetCombat(false)
	env.RunTimers()
	assert(hub:IsVisible() and travel:IsVisible() and not ns.Travel.menu:IsShown(), what .. ": after combat the crest and its button are back and the menu stays shut")
	AB.Click(env, travel, "RightButton", false)
	assert(ns.Travel.menu:IsVisible(), what .. ": the travel menu opens again after combat")
	assert(AB.PressKey(env, "ESCAPE", false) and not ns.Travel.menu:IsShown(), what .. ": Escape closes the reopened menu")
	Travels(what .. " after a combat hide")
	assert(Layout.Set(CREST, "shown", "always"))
	env.RunTimers()

	-- Profiles: a copy keeps the split; back in line there it joins; the first profile splits again with the crest
	-- where it was left.
	local profile, other = K.Store.ProfileName(), "Other " .. width
	assert(K.Store.CopyProfile(profile, other) and K.Store.SetProfile(other))
	env.RunTimers()
	Split(what .. " in a copied profile", true, true)
	assert(Layout.Set("actionbars.bar2", "y", y))
	env.RunTimers()
	Joined(what .. " the copy back in line")
	assert(K.Store.SetProfile(profile))
	env.RunTimers()
	Split(what .. " back in the split profile", true, true)
	local bx, by = Centre(hub)
	assert(math.abs(bx - sx) <= px and math.abs(by - sy) <= px, string.format("%s: the crest keeps its moved place across profiles, %.2f %.2f against %.2f %.2f", what, bx, by, sx, sy))

	-- In combat the crest never moves, so its secure controls stay over it: split, it stays on its element; joined,
	-- it keeps the gap; it moves once combat ends. The plates change at once.
	env.SetCombat(true)
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	Split(what .. " bar 2 toggled away in combat", true, false)
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	Split(what .. " bar 2 back in combat", true, true)
	env.SetCombat(false)
	env.RunTimers()
	Split(what .. " after combat, still out of line", true, true)
	assert(Layout.Set("actionbars.bar2", "y", y))
	env.RunTimers()
	Joined(what .. " back in line after combat")
	env.SetCombat(true)
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	Held(what .. " bar 2 toggled away in combat from joined", true, false)
	Travels(what .. " held in combat")
	env.SetCombat(false)
	env.RunTimers()
	Split(what .. " after combat the held crest", true, false)
	local hx, hy = Centre(hub)
	assert(math.abs(hx - sx) <= px and math.abs(hy - sy) <= px, string.format("%s: once combat ends the crest takes its saved place, %.2f %.2f against %.2f %.2f", what, hx, hy, sx, sy))
	Travels(what .. " after combat on its saved place")
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	Joined(what .. " bar 2 back")
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	Split(what .. " bar 2 toggled away, aligned", true, false)
	env.SetCombat(true)
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	assert(slab:IsShown() and not Slab.sides.bar1:IsShown() and not (Slab.sides.bar2 and Slab.sides.bar2:IsShown()), what .. ": bar 2 back in line in combat brings the joined plate back at once")
	assert(Layout.Live(CREST) and hub:GetParent() == crest and hub:IsVisible(), what .. ": the crest stays on its element until combat ends")
	local cx, cy = Centre(hub)
	assert(math.abs(cx - sx) <= px and math.abs(cy - sy) <= px, what .. ": the crest holds its saved place in combat")
	Travels(what .. " rejoined in combat")
	assert(#env._blocked == 0, what .. ": rejoining in combat moves nothing protected: " .. table.concat(env._blocked, ", "))
	env.SetCombat(false)
	env.RunTimers()
	Joined(what .. " rejoined after combat")

	-- A custom visibility rule that hides bar 2 in combat splits the aligned bars there and rejoins them after.
	K.Options.Write("ActionBars", "bar2.visibility", "[combat] hide; show")
	env.RunTimers()
	Joined(what .. " with a combat rule, out of combat")
	env.SetCombat(true)
	env.RunTimers()
	assert(not bar2.header:IsVisible(), what .. ": the rule hides bar 2 in combat")
	Held(what .. " the rule in combat", true, false)
	env.SetCombat(false)
	env.RunTimers()
	Joined(what .. " the rule after combat")
	-- The same split under a saved Crest rule of Out of combat only: the rule applies as the bars split in combat, so
	-- the crest held in the gap and its travel button hide at once, and come back joined after combat.
	assert(Layout.Set(CREST, "shown", "noCombat"))
	env.RunTimers()
	Joined(what .. " a saved crest rule while joined")
	env.SetCombat(true)
	env.RunTimers()
	assert(not bar2.header:IsVisible(), what .. ": bar 2's rule splits the bars in combat")
	assert(not slab:IsShown() and hub:IsShown() and hub:GetParent() == Slab.Gate(), what .. ": the first split in combat holds the crest in the gap")
	assert(not hub:IsVisible() and not travel:IsVisible(), what .. ": the saved rule hides the crest and its travel button as the bars split")
	assert(#env._blocked == 0, what .. ": the rule applied in combat with nothing blocked: " .. table.concat(env._blocked, ", "))
	env.SetCombat(false)
	env.RunTimers()
	Joined(what .. " after that combat")
	K.Options.Write("ActionBars", "bar2.visibility", "")
	env.RunTimers()
	-- Joined, the crest keeps showing in combat; the toggle key splitting the bars there applies the rule, and
	-- bringing bar 2 back shows the joined crest again.
	env.SetCombat(true)
	env.RunTimers()
	assert(hub:IsVisible() and travel:IsVisible(), what .. ": joined in combat, the crest shows whatever its split rule")
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	assert(not slab:IsShown() and not hub:IsVisible() and not travel:IsVisible(), what .. ": the toggle key splits the bars in combat and the rule hides the crest")
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	assert(slab:IsShown() and hub:IsVisible() and travel:IsVisible(), what .. ": bar 2 back in combat shows the joined crest again")
	assert(#env._blocked == 0, what .. ": the toggle key in combat blocked nothing: " .. table.concat(env._blocked, ", "))
	env.SetCombat(false)
	env.RunTimers()
	Joined(what .. " after the toggled combat")
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	Split(what .. " split out of combat under the saved crest rule", true, false)
	env.SetCombat(true)
	env.RunTimers()
	assert(not hub:IsVisible() and not travel:IsVisible(), what .. ": the next combat hides the split crest and its button")
	env.SetCombat(false)
	env.RunTimers()
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	assert(Layout.Set(CREST, "shown", "always"))
	env.RunTimers()
	Joined(what .. " the crest rule back to always")

	-- Gamepad mode keeps today's rule: neither the slab nor the crest.
	ns.gamepad = true
	Slab.Refresh()
	assert(not slab:IsShown() and not hub:IsShown() and not Layout.Live(CREST), what .. ": gamepad mode hides the slab and the crest")
	assert(not (Slab.sides.bar1 and Slab.sides.bar1:IsShown()), what .. ": and gives bar 1 no plate")
	ns.gamepad = false
	Slab.Refresh()
	assert(slab:IsShown() and hub:IsShown(), what .. ": leaving gamepad mode joins them again")

	assert(#env._errors == 0 and K.ErrorCount() == 0 and #env._blocked == 0, AB.Errors(env) .. " blocked " .. tostring(env._blocked[1]))
end

print("ok actionbars medallions split")
