-- actionbars_keybind.lua: the real /kb entry and hover over a rogue's stealth button, with its binding panel and the action rows.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local AB = dofile("Tools/regression/actionbars_env.lua")

return Common.Run(function()
	local env, K, ns = AB.New({
		class = "ROGUE", width = Common.SCREEN.width, height = Common.SCREEN.height,
		saved = Gallery.Saved({ ActionBars = { bar4 = { enabled = false }, bar5 = { enabled = false } } }),
		setup = function(e)
			Common.ForceScreen(e)
			e.GetBindingText = function(key)
				return e.GetLocale() == "deDE" and key:gsub("CTRL", "STRG") or key
			end
			e._game.forms = { { texture = 132320, spellID = 1784, isActive = true } }
			e._game.bindings.SHAPESHIFTBUTTON1 = { "CTRL-F" }
			local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
			for i = 1, 12 do
				e._game.bindings["ACTIONBUTTON" .. i] = { keys[i] }
				e._game.slots[i] = { texture = 132320, type = "spell", id = 1784 }
			end
			e.PossessActionBar:Hide()
		end,
	})
	AB.Enable(env, K)
	env.RunTimers()
	AB.W.Settle(env)
	env._resolveRects = true
	env.SlashCmdList.KSTYLEKB()
	assert(ns.Keybind.active, "/kb opens the real binding controller")
	local overlay = assert(ns.Keybind.overlays[ns.bars.stance.buttons[1]])
	overlay:GetScript("OnEnter")(overlay)
	assert(ns.Keybind.selected == overlay, "hover selects the stealth button")
	if os.getenv("RENDER_KB_HOVER") == "0" then overlay:GetScript("OnLeave")(overlay) end
	AB.W.Settle(env)
	return Common.Scene.Build(env, Common.ScreenOpts({ iconDirs = Common.IconDirs() }))
end)
