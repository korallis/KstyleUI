-- actionbars_config.lua: the real action bars at their shipped defaults, six buttons in two rows, or free of their slab and tray.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local AB = dofile("Tools/regression/actionbars_env.lua")

return Common.Run(function()
	local env, K = AB.New({
		class = "WARRIOR", width = Common.SCREEN.width, height = Common.SCREEN.height,
		saved = Gallery.Saved({ "ActionBars" }),
		setup = function(e)
			Common.ForceScreen(e)
			e._game.petExists = true
			for i = 1, 10 do
				e._game.forms[i] = { texture = 132355, spellID = 2457 + i }
				e._game.pet[i] = { name = "Attack", texture = 132152, spellID = 8000 + i }
			end
			for i = 1, 72 do e._game.slots[i] = { texture = 132355, type = "spell", id = 100 + i } end
			for i = 1, 12 do e._game.bindings["ACTIONBUTTON" .. i] = { tostring(i) } end
		end,
	})
	AB.Enable(env, K)
	local mode = os.getenv("RENDER_BAR_CONFIG") or "default"
	if mode == "legacy" then K.Options.Write("ActionBars", "tray", false) end
	if mode == "reversed" then K.Options.Write("ActionBars", "bar1.reverse", true) end
	if mode == "free" then
		local settings = K.Store.Module("ActionBars")
		settings.slab, settings.tray, settings.useTray = false, false, false
		K.Callbacks.Fire("ProfileChanged")
		for _, key in ipairs({ "bar1", "bar2", "pet", "stance" }) do
			K.Options.Write("ActionBars", key .. ".buttons", 6)
			K.Options.Write("ActionBars", key .. ".rows", 2)
			K.Options.Write("ActionBars", key .. ".size", 40)
			K.Options.Write("ActionBars", key .. ".spacing", 4)
		end
	end
	env.RunTimers()
	AB.W.Settle(env)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
	return Common.Scene.Build(env, Common.ScreenOpts({ iconDirs = Common.IconDirs() }))
end)
