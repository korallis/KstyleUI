-- test-databars-rail.lua: Setup leaves automatic bar positions unsaved and Right rail restores the v0.2.6 readout.
local D = dofile("Tools/regression/databars_env.lua")
local Scene = dofile("Tools/render/scene.lua")

for _, style in ipairs({ "frames", "orbs", "medallions" }) do
	for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto", setup = D.Menus })
		local choice = K.Setup.NewChoice()
		choice.hudStyle = style
		assert(K.Setup.Apply(choice))
		env.RunTimers()
		local function rail()
			K.Options.Write("DataBars", "strip.placement", "rail")
			env.RunTimers()
			local p = K.Layout.Get("databars.strip")
			assert(p.anchor == "BOTTOMRIGHT" and p.x == -17 and p.y == 181,
				"Right rail must use the v0.2.6 default after Setup; do not save the automatic top bar as a player position")
			local x, y, w, h = Scene.Rect(env, ns.Strip.view.frame)
			local rw, rh = K.Layout.RootSize()
			local pixel = K.Scale.Pixel(1)
			local left, bottom = K.Layout.Rect("databars.strip")
			assert(math.abs(left - (rw - 17 - p.width)) <= pixel and math.abs(bottom - 181) <= pixel,
				"Right rail must restore the v0.2.6 readout rectangle")
			assert(x and y and w > 0 and h > 0 and rh > 0)
		end
		rail()
		assert(K.Setup.Apply(choice))
		rail()
		env.FireEvent("PLAYER_LOGOUT")
		local saved = D.CoreEnv.DeepCopy(env.KstyleUIDB)
		env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto", saved = saved, setup = D.Menus })
		rail()
		K.Options.Write("DataBars", "strip.placement", "top")
		assert(K.Layout.Update("databars.strip", { anchor = "BOTTOM", x = 37, y = 300 }))
		K.Options.Write("DataBars", "strip.placement", "rail")
		local moved = K.Layout.Get("databars.strip")
		assert(moved.anchor == "BOTTOM" and moved.x == 37 and moved.y == 300,
			"Right rail must never clear a position the player moved by hand")
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end
print("databars rail ok: v0.2.6 placement after Setup, rerun and reload in all styles and owner screens; moved positions kept")
