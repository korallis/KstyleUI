-- test-hud-bar-shapes.lua: a bar shape the options offer never shrinks the HUD below the smallest Interface size, and a bar 1 or 2 in two rows stands clear of the other bar and the frames above it (a player's v0.3.5.1 report: Frames, bar 2 in two rows, the whole HUD at a quarter size with the bar's upper row under the player frame).
local Suite = dofile("Tools/regression/suite_env.lua")

local function Fresh(width, height, style)
	local env, K = Suite.New(nil, width, height, nil, function(_, K)
		local choice = K.Setup.NewChoice()
		choice.hudStyle, choice.layout = style, "DPS"
		assert(K.Setup.Apply(choice), "the first-run setup must apply")
	end)
	env.RunTimers()
	return env, K
end

local function Clear(K, a, b)
	local ax, ay, aw, ah = K.Layout.Rect(a)
	local bx, by, bw, bh = K.Layout.Rect(b)
	return ax + aw <= bx + 0.5 or bx + bw <= ax + 0.5 or ay + ah <= by + 0.5 or by + bh <= ay + 0.5
end

local TWO_ROWS = {
	{ "Frames, bar 2 in two rows", "frames", { { "bar2.rows", 2 } } },
	{ "Frames, bar 1 in two rows", "frames", { { "bar1.rows", 2 } } },
	{ "Medallions without the slab, bar 2 in two rows", "medallions", { { "slab", false }, { "bar2.rows", 2 } } },
}
local checked = 0
for _, screen in ipairs({ { 3456, 2234, #TWO_ROWS, 1 }, { 1920, 1080, 1, 0 } }) do
	local where = " at " .. screen[1] .. "x" .. screen[2]
	for index = 1, screen[3] do
		local case = TWO_ROWS[index]
		local env, K = Fresh(screen[1], screen[2], case[2])
		for _, write in ipairs(case[3]) do
			K.Options.Write("ActionBars", write[1], write[2])
			env.RunTimers()
		end
		local label = case[1] .. where
		assert(K.Scale.AppliedUserScale() >= K.Scale.MIN_USER_SCALE, label .. ": the HUD must stay at or above the smallest Interface size, got " .. K.Scale.AppliedUserScale())
		assert(Clear(K, "actionbars.bar1", "actionbars.bar2"), label .. ": bars 1 and 2 must not overlap")
		for _, bar in ipairs({ "actionbars.bar1", "actionbars.bar2" }) do
			for _, frame in ipairs({ "unitframes.player", "unitframes.target" }) do
				assert(Clear(K, bar, frame), label .. ": " .. bar .. " must stand clear of " .. frame)
			end
		end
		assert(#env._errors + K.ErrorCount() == 0, label .. ": no Lua error")
		checked = checked + 1
	end
	for _ = 1, screen[4] do
		local env, K = Fresh(screen[1], screen[2], "frames")
		K.Options.Write("ActionBars", "bar4.rows", 1)
		env.RunTimers()
		local label = "Frames, bar 4 set to one row" .. where
		assert(not Clear(K, "actionbars.bar4", "actionbars.bar5"), label .. ": a one-row bar 4 overlaps bar 5 on the right rail at every size, which is the case this guards")
		assert(K.Scale.AppliedUserScale() >= K.Scale.MIN_USER_SCALE, label .. ": an overlap no size cures must not shrink the HUD, got " .. K.Scale.AppliedUserScale())
		assert(#env._errors + K.ErrorCount() == 0, label .. ": no Lua error")
		checked = checked + 1
	end
end
print("hud bar shapes ok: " .. checked .. " shapes keep the HUD size and two-row bars clear of the frames above")
