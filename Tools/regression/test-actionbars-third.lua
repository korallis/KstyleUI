local AB = dofile("Tools/regression/actionbars_env.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")
local function Rect(frame)
	return { frame:GetLeft(), frame:GetBottom(), frame:GetRight(), frame:GetTop() }
end
local function Apart(a, b)
	return a[1] >= b[3] or b[1] >= a[3] or a[2] >= b[4] or b[2] >= a[4]
end
for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 } }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		local env, K, ns = AB.New({ width = screen[1], height = screen[2] })
		AB.Enable(env, K)
		K.Options.Write("HudStyle", "style", style)
		do
			local fitEnv, fitK = CoreEnv.New({ width = screen[1], height = screen[2], fit = true, size = "auto" })
			CoreEnv.Boot(fitEnv)
			local maximum, fits = fitK.Setup.Layouts.ScaleLimit(fitK.Scale.CanvasWidth(screen[1], screen[2]), screen[2], "DPS", nil, style)
			local baseScale = (screen[1] == 1920 or style == "medallions") and 0.9375 or 0.984375
			assert(fitK.Scale.Auto(screen[2], maximum, fits) == baseScale, "bar 3 off must keep the base Auto scale")
		end
		assert(K.Setup.Apply({ layout = "DPS", modules = { ActionBars = true }, hudStyle = style }))
		K.Options.Write("ActionBars", "bar3.enabled", true)
		AB.Slot(env, 1, { texture = 135813, type = "spell", id = 133 })
		assert(ns.bars.bar1.buttons[1].hotkey:GetText() == "-", "a filled, unbound slot needs a dim dash")
		for _, count in ipairs({ 6, 12 }) do
			K.Options.Write("ActionBars", "bar3.buttons", count)
			env.RunTimers()
			AB.W.Settle(env)
			local bar, slab = ns.bars.bar3, ns.Slab
			assert(bar.count == count and bar.buttons[count]:IsShown() and (count == 12 or not bar.buttons[count + 1]:IsShown()))
			local rect = Rect(bar.holder)
			for _, other in ipairs({ "bar1", "bar2", "pet", "stance" }) do
				assert(Apart(rect, Rect(ns.bars[other].holder)), style .. ": bar 3 overlaps " .. other)
			end
			if style == "medallions" then
				assert(slab.sides.bar3 and slab.sides.bar3:IsShown(), "Medallions bar 3 needs its own finished slab")
				assert(bar.buttons[1].medFrame:IsShown(), "bar 3 wears the same sockets")
				assert(Apart(Rect(slab.sides.bar3), Rect(slab.hub)), "bar 3 must clear the crest")
			end
			local positions = K.Setup.Layouts.Positions("DPS", style, K.Scale.Aspect(), K.Scale.Band())
			local rw, rh = K.Layout.RootSize()
			for _, key in ipairs({ "unitframes.player", "unitframes.target", "unitframes.focus", "unitframes.castbar.player", "unitframes.castbar.target", "unitframes.resource", "cooldowns.essential", "cooldowns.utility", "chat.main" }) do
				local place = positions[key]
				local w, h = K.Setup.Layouts.StyleSize(style, K.Scale.Aspect(), key)
				if not w then w, h = K.Setup.Layouts.Footprint("DPS", key) end
				local other = { K.Setup.Layouts.Rect({ width = w, height = h }, place, rw, rh) }
				assert(Apart(rect, other), style .. " " .. count .. ": bar 3 overlaps " .. key)
			end
		end
		local before = Rect(ns.bars.bar3.holder)
		env.SetCombat(true)
		K.Options.Write("ActionBars", "bar3.buttons", 6)
		assert(#env._blocked == 0, "bar 3 changes must queue during combat")
		local held = Rect(ns.bars.bar3.holder)
		assert(held[3] == before[3], "combat holds the old geometry")
		env.SetCombat(false)
		env.RunTimers()
		assert(ns.bars.bar3.count == 6 and #env._errors == 0, tostring(env._errors[1]))
		collectgarbage()
	end
end
print("third action bar ok")
