-- gallery_qol.lua: the settings window on the real Quality of Life page, the module loaded as the game loads it so
-- its own schema fills the page: the module switch, then Loot, Merchants (with the note that sends junk selling to
-- the Bags page), Quests, Camera and Alerts. The module draws nothing on the HUD, so this page is its only frame.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Q = dofile("Tools/regression/qol_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = Q.W

local WINDOW_KEY = "Options.Window"
local MODULE = "QoL"
local AT = { x = 16, y = 16 }

local function settle(env)
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

return Common.Run(function()
	local frames = Gallery.Frames()
	local env, K = Q.New(Common.ScreenOpts({
		saved = Gallery.Saved({ [MODULE] = {} }),
		setup = function(env)
			Gallery.Setup(env)
			env.C_AddOns = env.C_AddOns or {}
			env.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not env._addons.KstyleUI_Options then
					Load(O.Files(), env)
				end
				return true
			end
		end,
	}))
	assert(K.Modules.IsRunning(MODULE), "QoL runs from the saved switch")
	assert(K.Options.Open(MODULE) == true, "the window opens on the QoL page")
	settle(env)
	assert(K.Layout.Set(WINDOW_KEY, "anchor", "TOPLEFT"))
	assert(K.Layout.Set(WINDOW_KEY, "x", AT.x))
	assert(K.Layout.Set(WINDOW_KEY, "y", -AT.y))
	settle(env)
	local ns = env._addons.KstyleUI_Options
	assert(ns.Window.State().page == MODULE, "the window shows the QoL page")
	frames:Add(env, ns.Window.Frame(), {
		name = "options_qol", title = "Quality of Life page", grade = "window", reference = "chat",
		caption = "The settings window on the real Quality of Life page: the module switch, then Faster auto loot under Loot; Repair by itself, Guild funds first and the note that points to Bags' Sell junk by itself under Merchants; Accept and turn in quests with its pause key under Quests; Max camera distance under Camera; and Quiet error text under Alerts. Each row carries its help line.",
		match = "Surface fill, the dark outer and light inner line, the 12-unit window chamfer and the drop shadow, as the mockup's chat panel; the toggles and the dropdown wear the button grade.",
	})
	local scene = Gallery.Build(env)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: qol: " .. err
	end
	return frames:Finish(scene, env, K, "gallery qol")
end)
