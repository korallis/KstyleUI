-- test-actionbars-config-cache.lua: Auto fit caches include the bar geometry and survive a profile reload.
local AB = dofile("Tools/regression/actionbars_env.lua")
local function Setup(e) e._fitScale, e._size = true, "auto" end
local env, K = AB.New({ width = 1920, height = 1080, setup = Setup })
K.VERSION = "actionbar-geometry-cache"
AB.Enable(env, K)
local calls, fits = 0, K.Setup.Layouts.Fits
K.Setup.Layouts.Fits = function(...) calls = calls + 1; return fits(...) end
for index, style in ipairs({ "frames", "orbs", "medallions" }) do
	K.Options.Write("HudStyle", "style", style)
	K.Options.Write("ActionBars", "bar1.size", 30 + index)
	local before = calls
	K.Options.Write("ActionBars", "bar1.size", 50 + index)
	assert(calls > before, "Auto fit must search again when bar geometry changes under " .. style)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
	local warm = K.Scale.AppliedUserScale()
	assert(K.Store.CopyProfile(K.Store.ProfileName(), "Snapshot"))
	local saved = AB.CoreEnv.DeepCopy(env.KstyleUIDB)
	saved.scaleCache = nil
	local reload, cold = AB.New({ width = 1920, height = 1080, saved = saved, setup = Setup })
	AB.Enable(reload, cold)
	assert(warm == cold.Scale.AppliedUserScale(), style .. ": warm fit must match a cold reload")
end
assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
print("ok actionbar geometry cache")
