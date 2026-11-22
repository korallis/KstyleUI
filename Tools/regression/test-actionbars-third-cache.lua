local C = dofile("Tools/regression/core_env.lua")
-- 1366x768 is a screen where the Medallions HUD's Auto size depends on the third bar's finish.
local function New(saved)
	local env, K = C.New({ width = 1366, height = 768, fit = true, size = "auto", saved = saved })
	K.VERSION = "third-bar-finish-cache-test"
	K.Modules.Register(C.Module("ActionBars", { defaults = { bar3 = { enabled = true, finished = true } } }))
	K.Options.Register("ActionBars", { { type = "toggle", key = "bar3.finished", label = "Finish", help = "The third bar finish." } })
	local calls, fits = 0, K.Setup.Layouts.Fits
	K.Setup.Layouts.Fits = function(...) calls = calls + 1; return fits(...) end
	C.Boot(env)
	local profile = K.Store.Profile()
	for _, element in ipairs(K.Setup.Layouts.ELEMENTS) do
		profile[element.module] = profile[element.module] or {}
		profile[element.module].enabled = true
	end
	K.Callbacks.Fire("ModuleChanged")
	return env, K, function() return calls end
end
local env, K, calls = New()
local on, searched = K.Scale.AppliedUserScale(), calls()
K.Options.Write("ActionBars", "bar3.finished", false)
assert(calls() > searched, "Include the third-bar finish choice in the persistent scale cache key")
local off = K.Scale.AppliedUserScale()
assert(K.Store.CopyProfile(K.Store.ProfileName(), "Legacy"))
local saved = C.DeepCopy(env.KstyleUIDB)
saved.scaleCache = nil
local _, cold = New(saved)
assert(off == cold.Scale.AppliedUserScale() and off < on, "Finish off must match the previous cold Auto size: warm " .. off .. ", cold " .. cold.Scale.AppliedUserScale() .. ", on " .. on)
searched = calls()
K.Options.Write("ActionBars", "bar3.finished", true)
assert(K.Scale.AppliedUserScale() == on and calls() == searched, "Returning to the finished bar reuses only its matching cached fit")
assert(K.Store.SetProfile("Legacy"))
assert(K.Scale.AppliedUserScale() == off and calls() == searched, "A profile switch reuses the fit for its own finish choice")
assert(#env._errors == 0, tostring(env._errors[1]))
print("third-bar cache ok")
