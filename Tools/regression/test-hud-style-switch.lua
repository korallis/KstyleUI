-- test-hud-style-switch.lua: a HUD style chosen in combat waits for combat to end and says so once; a module that fails to switch brings the reload prompt.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local env, K = CoreEnv.New()
CoreEnv.Boot(env)
local fired, prompted = 0, nil
K.Callbacks.Register("HudStyleChanged", "test", function() fired = fired + 1 end)
K.Widgets.ReloadPrompt = function(text) prompted = text end

env.SetCombat(true)
K.Options.Write("HudStyle", "style", "frames")
K.Options.Write("HudStyle", "style", "frames")
assert(K.HudStyle.Saved() == "frames" and K.HudStyle.Current() == "medallions" and fired == 0, "in combat the style is saved but Medallions stays")
assert(CoreEnv.Count(env._printed, "KstyleUI: " .. K.L["Your HUD style changes when combat ends."]) == 1, "one line says the switch waits")
env.SetCombat(false)
env.RunTimers()
assert(K.HudStyle.Current() == "frames" and fired == 1 and prompted == nil, "the switch lands once when combat ends")

K.Callbacks.Register("HudStyleChanged", "broken", function() error("a module failed to switch") end)
K.Options.Write("HudStyle", "style", "medallions")
assert(K.HudStyle.Current() == "medallions" and prompted == K.L["Your HUD style finishes changing when you reload."], "a failed switch offers a reload")
print("hud style switch ok")
