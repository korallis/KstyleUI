-- test-layout-orbs-fit.lua: the fit bugs the layout property test found (Capy LEE-1459, LEE-1460, LEE-1461 and LEE-1483): the fit check counts the Orbs HUD's two orbs as circles, so no size it allows puts an orb over a card; action bar 3 has an Orbs place of its own, with the pet and stance bars under it on whole units; the fit cap is the largest size step that fits, and the size Scale applies is a step that fits, never above the cap, so pixel rounding that makes one step fit and the next smaller one not (fitting is not monotonic in size) cannot slip an overlap through.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local function New(width, height)
	local env, K = CoreEnv.New({
		width = width, height = height, uiScale = 768 / 1080, size = "auto", fit = true,
		setup = function(e)
			e.GetPhysicalScreenSize = function()
				return width, height
			end
		end,
	})
	CoreEnv.Boot(env)
	return env, K
end

local function whole(v)
	return v == math.floor(v)
end

local env, K = New(1920, 1080)
local Scale, Layouts = K.Scale, K.Setup.Layouts

local function step(height)
	return 1080 / (Scale.STEPS_PER_PIXEL * height)
end

-- LEE-1461: Scale.Within took the step a hair above a cap that sits just under a whole step. At 2043 x 855 with Tank the
-- cap was 0.947368421052572 and the applied size 0.947368421052632, where the party frames met action bar 3.
do
	local cap = 0.947368421052572
	local size = Scale.Nearest(0.9299, 855, cap)
	assert(size <= cap, "2043x855 Tank: the applied size stays under the fit cap, got " .. string.format("%.17g", size))
	for _, height in ipairs({ 720, 768, 855, 1080, 1089, 1123, 1440, 1495, 1540, 1651, 2160, 2234 }) do
		local s = step(height)
		for k = math.ceil(Scale.MIN_USER_SCALE / s), math.floor(Scale.MAX_USER_SCALE / s) do
			local exact = k * s
			assert(Scale.Nearest(Scale.MAX_USER_SCALE, height, exact) == exact, height .. " lines: a cap on a whole step keeps that step")
			for _, under in ipairs({ exact - 1e-13, exact * (1 - 1e-15), exact - s / 2 }) do
				if under >= math.ceil(Scale.MIN_USER_SCALE / s - 1e-9) * s then
					local what = string.format("%d lines, cap %.17g", height, under)
					assert(Scale.Nearest(Scale.MAX_USER_SCALE, height, under) <= under, what .. ": a chosen size stays under the cap")
					assert(Scale.Auto(height, under) <= under, what .. ": the automatic size stays under the cap")
				end
			end
		end
	end
end

-- LEE-1459: the orbs replace the player frame, so the fit skipped them and allowed sizes where the health orb covered
-- the chat card. At 1685 x 1123 with Tank the automatic size was 14 steps, 0.8415, and the orb ran 4 units into chat.
do
	local enabled = Layouts.Enabled("Tank")
	enabled["meters.damage"], enabled["meters.threat"] = false, false
	assert(not Layouts.Fits("Tank", 1685, 1123, 14 * step(1123), enabled, nil, "orbs"), "1685x1123 Tank Orbs: 14 steps puts the health orb over the chat card, so it does not fit")
	assert(Layouts.Fits("Tank", 1685, 1123, 14 * step(1123), enabled, nil, "frames"), "1685x1123 Tank Frames still fits at 14 steps")
	local barW, barH = Layouts.Footprint("Tank", "actionbars.bar1")
	local art = Layouts.OrbsTray(barW)
	local SCREENS = {
		{ 1452, 1089 }, { 1685, 1123 }, { 2642, 1651 }, { 1280, 1024 }, { 1920, 1200 }, { 2560, 1600 }, { 1920, 1080 },
		{ 1280, 720 }, { 2383, 1540 }, { 3456, 2234 }, { 3440, 1440 }, { 5120, 1440 },
	}
	for _, screen in ipairs(SCREENS) do
		local width, height = screen[1], screen[2]
		for _, physical in ipairs({ width, math.min(width, math.floor(height * 12 / 5 + 0.5)) }) do
			local class = Scale.AspectClass(physical, height)
			for _, name in ipairs(Layouts.Names()) do
				local on = Layouts.Enabled(name)
				on["meters.damage"], on["meters.threat"] = name ~= "Tank", name == "Tank"
				local cap, fits = Layouts.ScaleLimit(physical, height, name, on, "orbs")
				local size = Scale.Auto(height, cap, fits)
				assert(Layouts.Fits(name, physical, height, size, on, nil, "orbs"), name .. " " .. width .. "x" .. height .. ": the automatic size fits")
				local what = string.format("%s %dx%d on %d at %.4f", name, width, height, physical, size)
				local rh = 1080 / size
				local rw = rh * physical / height
				local px = rh / height
				local positions = Layouts.Positions(name, "orbs", class)
				local bl, bb, br, bt = Layouts.Rect({ width = barW, height = barH }, positions["actionbars.bar1"], rw, rh)
				local cy, r = (bb + bt) / 2 + art.lift, art.ring / 2
				local rects = {}
				for _, element in ipairs(Layouts.ELEMENTS) do
					local key = element.key
					if on[key] ~= false and key ~= "unitframes.player" then
						local w, h, offsetX = Layouts.Footprint(name, key)
						local styled = Layouts.Style("orbs", name, key)
						if styled and styled.width then
							w, h, offsetX = styled.width, styled.height, nil
						end
						rects[#rects + 1] = { key, Layouts.Rect({ width = w, height = h, offsetX = offsetX }, positions[key], rw, rh) }
					end
				end
				local story = Layouts.Story(name, rh, true, "orbs", rw)
				for _, card in ipairs({ story.guide, story.quests }) do
					rects[#rects + 1] = { card.key, Layouts.Rect(card, card, rw, rh) }
				end
				for _, cx in ipairs({ (bl + br) / 2 - art.ringX, (bl + br) / 2 + art.ringX }) do
					assert(cx - r >= -px and cx + r <= rw + px and cy - r >= -px, what .. ": the orb stays on screen")
					for _, rect in ipairs(rects) do
						local dx = math.max(rect[2] - cx, 0, cx - rect[4])
						local dy = math.max(rect[3] - cy, 0, cy - rect[5])
						assert(math.sqrt(dx * dx + dy * dy) >= r - px, what .. ": the orb at " .. math.floor(cx) .. " clears " .. rect[1])
					end
				end
			end
		end
	end
end

-- LEE-1460: under Orbs, action bar 3 kept its Frames place, half a unit under the top of the pet and stance bars'
-- Orbs places. It has an Orbs place of its own now, with both bars under it on whole units, in every preset and
-- layout class, and the layout fits at the automatic size with bar 3 on (4236 x 1495 Healer, spread, did not).
do
	local bar3W, bar3H = Layouts.Footprint("DPS", "actionbars.bar3")
	for _, name in ipairs(Layouts.Names()) do
		assert(Layouts.Style("orbs", name, "actionbars.bar3"), name .. ": action bar 3 has an Orbs place")
		for _, class in ipairs(Layouts.ASPECTS) do
			local what = name .. " " .. class
			local bar = Layouts.Place(name, "orbs", class, "actionbars.bar3")
			local _, b3, _, t3 = Layouts.Rect({ width = bar3W, height = bar3H }, bar, 2048, Layouts.HEIGHT)
			assert(whole(bar.x) and whole(bar.y), what .. ": bar 3 sits on whole units")
			for _, key in ipairs({ "actionbars.pet", "actionbars.stance" }) do
				local place = Layouts.Place(name, "orbs", class, key)
				local w, h = Layouts.Footprint(name, key)
				local l, b, r, t = Layouts.Rect({ width = w, height = h }, place, 2048, Layouts.HEIGHT)
				assert(whole(place.x) and whole(place.y) and whole(t), what .. ": " .. key .. " sits on whole units")
				assert(t + 1 <= b3 or b >= t3 + 1, what .. ": " .. key .. " (" .. l .. ", " .. b .. " to " .. r .. ", " .. t .. ") stands clear of bar 3 (" .. b3 .. " to " .. t3 .. ")")
			end
		end
	end
	local on = Layouts.Enabled("Healer")
	on["actionbars.bar3"] = true
	local size = Scale.Auto(1495, Layouts.ScaleLimit(4236, 1495, "Healer", on, "orbs"))
	assert(Layouts.Fits("Healer", 4236, 1495, size, on, nil, "orbs"), "4236x1495 Healer Orbs with bar 3 on fits at its automatic size, got " .. size)
end

assert(#env._errors == 0, tostring(env._errors[1]))

-- LEE-1483 and the mechanism behind LEE-1460 and LEE-1461: a size that fits does not mean every smaller size fits, because
-- each edge rounds to whole pixels on its own. The cap is the largest step that fits, and Scale checks the size it
-- applies, stepping down to the next one that fits. The property test's failing cases, booted through Scale.Apply: the
-- applied size fits with every enabled element, whatever the player asked for.
local CASES = {
	{ "930", 2266, 1000, "Tank", "orbs", "centred", "21:9" },
	{ "988", 3247, 1359, "Healer", "orbs", "spread", "full", 1.2368 },
	{ "292", 2043, 855, "Tank", "frames", "centred", "16:9", 0.9299, true },
	{ "18", 4236, 1495, "Healer", "orbs", "spread", "full", nil, true },
	{ "52", 1685, 1123, "Tank", "orbs", "spread", "21:9", 0.871 },
	{ "113", 2642, 1651, "Tank", "orbs", "spread", "21:9" },
}
for _, case in ipairs(CASES) do
	local label, width, height, preset, style, arrangement, canvas, size, bar3 = unpack(case)
	local caseEnv, CK = New(width, height)
	local profile = CK.Store.Profile()
	for _, element in ipairs(CK.Setup.Layouts.ELEMENTS) do
		profile[element.module] = profile[element.module] or {}
		profile[element.module].enabled = true
	end
	if bar3 then
		profile.ActionBars.bar3 = { enabled = true }
	end
	local layout = CK.Store.Module("Layout")
	layout.preset, layout.arrangement, layout.canvas = preset, arrangement, canvas
	CK.Options.Write("HudStyle", "style", style)
	if size then
		CK.Options.Write("Appearance", "uiScaleAuto", false)
		CK.Options.Write("Appearance", "uiScale", size)
	end
	CK.Callbacks.Fire("ModuleChanged")
	caseEnv.RunTimers()
	local applied, physical = CK.Scale.AppliedUserScale(), CK.Scale.CanvasWidth(width, height)
	local what = string.format("case %s, %dx%d %s %s %s on %d: applied %.4f under cap %.4f", label, width, height, preset, style, arrangement, physical, applied, CK.Scale.MaxUserScale())
	assert(CK.HudStyle.Current() == style, what .. ": the style applies")
	assert(applied <= CK.Scale.MaxUserScale(), what .. ": the applied size stays under the cap")
	assert(CK.Setup.Layouts.Fits(preset, physical, height, applied, CK.Setup.Layouts.Enabled(preset, profile), nil, style), what .. ": the applied size fits")
	assert(#caseEnv._errors == 0, what .. ": " .. tostring(caseEnv._errors[1]))
end

print("layout orbs fit ok")
