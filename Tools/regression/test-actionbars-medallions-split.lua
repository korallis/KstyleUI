-- test-actionbars-medallions-split.lua: KSTY-171 part 1, from a player's report that the medallion disappears when they change the panels. Under Medallions, bars 1 and 2 out of line, the slab switched off, or either bar off or toggled away, splits the slab: each shown bar wears its own plate and the crest stays on the Crest Layout element, at the joined gap's spot until moved; back in line the slab returns. Gamepad mode still hides both.
local AB = dofile("Tools/regression/actionbars_env.lua")

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
	end })
	AB.Enable(env, K)
	env.RunTimers()
	local Slab, Layout = ns.Slab, K.Layout
	local bar1, bar2 = ns.bars.bar1, ns.bars.bar2
	local hub, slab, crest = Slab.hub, Slab.frame, Slab.crest
	local px = 768 / height * 1.01
	local x0, y0, w0 = Centre(hub)
	local function Joined(what)
		assert(slab:IsShown() and hub:IsVisible(), what .. ": the slab and the crest are shown")
		assert(not Layout.Live(CREST), what .. ": the Crest element is not live while the gap places the crest")
		assert(hub:GetParent() == K.Scale.Root(), what .. ": the crest sits in the gap, not on its element")
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

	-- The Crest element: moving, scaling and hiding it carries the crest while split.
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
	assert(Layout.Set(CREST, "shown", "never"))
	env.RunTimers()
	assert(not hub:IsVisible(), what .. ": Shown never on the element hides the crest")
	assert(Layout.Set(CREST, "shown", "always"))
	env.RunTimers()
	assert(hub:IsVisible(), what .. ": and Always brings it back")

	-- Splitting and joining in combat stays clear of protected calls.
	env._combat = true
	env.FireEvent("PLAYER_REGEN_DISABLED")
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	Split(what .. " bar 2 toggled away in combat", true, false)
	assert(AB.PressKey(env, "F10"))
	env.RunTimers()
	assert(hub:IsVisible() and bar2.buttons[1]:IsVisible(), what .. ": bar 2 and the crest are back in combat")
	env._combat = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	env.RunTimers()
	assert(Layout.Set("actionbars.bar2", "y", y))
	env.RunTimers()
	assert(slab:IsShown() and hub:GetParent() == K.Scale.Root(), what .. ": back in line after combat, the slab returns")

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
