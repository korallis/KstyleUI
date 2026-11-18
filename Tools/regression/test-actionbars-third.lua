local AB = dofile("Tools/regression/actionbars_env.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")
local integrationKeys = { "timerLane", "announcementLane", "KstyleUI_WeakAuras1", "KstyleUI_WeakAuras2" }
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
		local plannedScales = {}
		do
			local fitEnv, fitK = CoreEnv.New({ width = screen[1], height = screen[2], fit = true, size = "auto" })
			CoreEnv.Boot(fitEnv)
			local maximum, fits = fitK.Setup.Layouts.ScaleLimit(fitK.Scale.CanvasWidth(screen[1], screen[2]), screen[2], "DPS", nil, style)
			local baseScale = (screen[1] == 1920 or style == "medallions") and 0.9375 or 0.984375
			assert(fitK.Scale.Auto(screen[2], maximum, fits) == baseScale, "bar 3 off must keep the base Auto scale")
			local enabled = fitK.Setup.Layouts.Enabled("DPS")
			enabled["actionbars.bar3"] = true
			maximum, fits = fitK.Setup.Layouts.ScaleLimit(fitK.Scale.CanvasWidth(screen[1], screen[2]), screen[2], "DPS", enabled, style)
			local withBar = fitK.Scale.Auto(screen[2], maximum, fits)
			assert(withBar == baseScale, "bar 3 on fits without shrinking the default HUD")
			print(style, screen[1], "bar 3 off/on", baseScale, withBar)
			for _, preset in ipairs(fitK.Setup.Layouts.Names()) do
				local active = fitK.Setup.Layouts.Enabled(preset)
				active["actionbars.bar3"] = true
				maximum, fits = fitK.Setup.Layouts.ScaleLimit(fitK.Scale.CanvasWidth(screen[1], screen[2]), screen[2], preset, active, style)
				plannedScales[preset] = fitK.Scale.Auto(screen[2], maximum, fits)
			end
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
			assert(#K.Setup.Integrations.frames == 4, "Default-on integrations create both lanes and both named anchors")
			for _, lane in ipairs(K.Setup.Integrations.frames) do
				assert(Apart(rect, Rect(lane)), style .. " " .. count .. ": bar 3 overlaps an enabled other-addon lane")
			end
			for _, other in ipairs({ "bar1", "bar2", "pet", "stance" }) do
				assert(Apart(rect, Rect(ns.bars[other].holder)), style .. ": bar 3 overlaps " .. other)
			end
			if style == "medallions" then
				assert(slab.sides.bar3 and slab.sides.bar3:IsShown(), "Medallions bar 3 needs its own finished slab")
				assert(bar.buttons[1].medFrame:IsShown(), "bar 3 wears the same sockets")
				assert(Apart(Rect(slab.sides.bar3), Rect(slab.hub)), "bar 3 must clear the crest")
			end
			for _, preset in ipairs(K.Setup.Layouts.Names()) do
				local places = K.Setup.Layouts.Positions(preset, style, K.Scale.Aspect(), K.Scale.Band())
				local enabled = K.Setup.Layouts.Enabled(preset)
				local rh = 1080 / plannedScales[preset]
				local rw = K.Scale.CanvasWidth(screen[1], screen[2]) / screen[2] * rh
				local own = { K.Setup.Layouts.Rect({ width = ns.bars.bar3.holder:GetWidth(), height = ns.bars.bar3.holder:GetHeight() }, places["actionbars.bar3"], rw, rh) }
				for i, lane in ipairs(K.Setup.Integrations.frames) do
					local place = K.Layout.Get("integrations." .. integrationKeys[i])
					local other = { K.Setup.Layouts.Rect({ width = lane:GetWidth(), height = lane:GetHeight() }, place, rw, rh) }
					assert(Apart(own, other), style .. " " .. preset .. " " .. count .. ": bar 3 overlaps " .. integrationKeys[i])
				end
				for key, place in pairs(places) do
					if key ~= "actionbars.bar3" and enabled[key] then
						local w, h = K.Setup.Layouts.StyleSize(style, K.Scale.Aspect(), key)
						if not w then w, h = K.Setup.Layouts.Footprint(preset, key) end
						local other = { K.Setup.Layouts.Rect({ width = w, height = h }, place, rw, rh) }
						assert(Apart(own, other), style .. " " .. preset .. " " .. count .. ": bar 3 overlaps " .. key)
					end
				end
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
		K.Options.Write("ActionBars", "bindingHints", false)
		assert(ns.bars.bar1.buttons[1].hotkey:GetText() == "" and ns.bars.bar1.buttons[1].hotkey:GetAlpha() == 1, "Binding helpers off restores the old blank hotkey")
		K.Options.Write("ActionBars", "bindingHints", true)
		K.Options.Write("ActionBars", "bar3.finished", false)
		env.RunTimers()
		local old = K.Layout.Get("actionbars.bar3")
		assert(old.anchor == "BOTTOMLEFT" and old.x == 17 and old.y == (style == "orbs" and 475 or 462.5), "Finished third bar off restores the previous style position")
		if style == "medallions" then assert(not ns.Slab.sides.bar3:IsShown(), "Finished third bar off restores the previous slab treatment") end
		K.Layout.Set("actionbars.bar3", "x", 19)
		K.Layout.Set("actionbars.bar3", "scale", 1.1)
		K.Options.Write("ActionBars", "bar3.finished", true)
		env.RunTimers()
		assert(K.Layout.Get("actionbars.bar3").x == 19 and K.Layout.Get("actionbars.bar3").scale == 1.1, "changing the finish never moves a custom bar")
		K.Layout.Reset("actionbars.bar3")
		env.RunTimers()
		assert(K.Layout.Get("actionbars.bar3").scale == 1, "reset keeps the original default scale after a finish change")
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

for _, style in ipairs({ "frames", "orbs", "medallions" }) do
	local key = style .. ":actionbars.bar3"
	local env, K = CoreEnv.New({ saved = { version = 35, profiles = { Default = { HudStyle = { style = style } }, Custom = {} }, layouts = {
		Default = { ["actionbars.bar3"] = { anchor = "BOTTOMLEFT", x = 17, y = 462.5 }, [key] = { anchor = "BOTTOMLEFT", x = 17, y = style == "orbs" and 475 or 462.5 } },
		Custom = { [key] = { anchor = "BOTTOMLEFT", x = 19, y = 462.5 } },
	} } })
	CoreEnv.Boot(env)
	local layout = K.Store.Layout()
	assert(layout["actionbars.bar3"] == nil and layout[key] == nil, "the old default follows the new style position")
	assert(K.Store.SetProfile("Custom"))
	assert(K.Store.Layout()[key].x == 19, "a custom style position survives migration")
	assert(K.Store.CreateProfile("Fresh") and K.Store.SetProfile("Fresh"))
	assert(K.Store.Layout()[key] == nil, "a fresh profile inherits the new style default")
	local position = K.Setup.Layouts.Positions("DPS", style, "16:9")["actionbars.bar3"]
	assert(position.anchor == (style == "medallions" and "BOTTOM" or "TOP") and position.x == 0)
end
