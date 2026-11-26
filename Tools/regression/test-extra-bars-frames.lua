-- test-extra-bars-frames.lua: after Medallions' Extra bars layout (Two rows or Beside) and a switch to Frames, bars 4 and 5 stand clear of each other and every other HUD element without shrinking the HUD, and Action Bars still offers Off to undo the preset (KSTY-139, found by the player's v0.3.5.1 report).
local Suite = dofile("Tools/regression/suite_env.lua")

local function Clear(K, a, b)
	local ax, ay, aw, ah = K.Layout.Rect(a)
	local bx, by, bw, bh = K.Layout.Rect(b)
	if not (ax and bx) or aw <= 0 or bw <= 0 then return true end
	return ax + aw <= bx + 0.5 or bx + bw <= ax + 0.5 or ay + ah <= by + 0.5 or by + bh <= ay + 0.5
end

local checked = 0
for _, screen in ipairs({ { 1920, 1080 }, { 3456, 2234 }, { 3440, 1440 } }) do
	for _, kind in ipairs({ "rows", "beside" }) do
		local env, K = Suite.New(nil, screen[1], screen[2], nil, function(_, K)
			local choice = K.Setup.NewChoice()
			choice.hudStyle, choice.layout = "medallions", "DPS"
			assert(K.Setup.Apply(choice), "the first-run setup must apply")
		end)
		env.RunTimers()
		local cfg = K.Store.Module("ActionBars")
		local before4, before5 = cfg.bar4.rows, cfg.bar5.rows
		K.Options.Write("ActionBars", "extraBarsLayout", kind)
		env.RunTimers()
		K.Options.Write("HudStyle", "style", "frames")
		env.RunTimers()
		local label = kind .. ", then Frames at " .. screen[1] .. "x" .. screen[2]
		assert(cfg.extraBarsApplied == kind, label .. ": the preset is still applied")
		assert(K.Scale.AppliedUserScale() >= K.Scale.MIN_USER_SCALE, label .. ": the HUD must keep its size, got " .. K.Scale.AppliedUserScale())
		assert(Clear(K, "actionbars.bar4", "actionbars.bar5"), label .. ": bars 4 and 5 must not overlap")
		for _, element in ipairs(K.Setup.Layouts.ELEMENTS) do
			for _, bar in ipairs({ "actionbars.bar4", "actionbars.bar5" }) do
				if element.key ~= "actionbars.bar4" and element.key ~= "actionbars.bar5" then
					assert(Clear(K, bar, element.key), label .. ": " .. bar .. " must stand clear of " .. element.key)
				end
			end
		end

		K.Options.Write("ActionBars", "bar4.rows", 3)
		env.RunTimers()
		assert(Clear(K, "actionbars.bar4", "actionbars.bar5"), label .. ": bar 4 reshaped to three rows still stands clear of bar 5")

		local row = K.Options.Row("ActionBars", "extraBarsLayout")
		assert(row.showWhen(cfg), label .. ": Frames offers the Extra bars layout while a preset is applied")
		local values = {}
		for _, option in ipairs(row.options()) do values[#values + 1] = option.value end
		assert(table.concat(values, ",") == "off," .. kind, label .. ": Frames offers Off and the applied preset only, got " .. table.concat(values, ","))
		K.Options.Write("ActionBars", "extraBarsLayout", "off")
		env.RunTimers()
		assert(cfg.extraBarsApplied == "off" and cfg.bar4.rows == before4 and cfg.bar5.rows == before5, label .. ": Off restores bars 4 and 5")
		assert(Clear(K, "actionbars.bar4", "actionbars.bar5"), label .. ": restored bars 4 and 5 stand apart on the rail")
		assert(not row.showWhen(cfg), label .. ": Frames hides the selector once nothing is left to undo")
		assert(#env._errors + K.ErrorCount() == 0, label .. ": no Lua error")
		checked = checked + 1
	end
end
print("extra bars under frames ok: " .. checked .. " preset switches stay clear and undo")
