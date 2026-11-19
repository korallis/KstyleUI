-- test-scale-resize.lua: display bursts use only their final inputs, skip no-ops, reuse fitting answers and wait for combat.
local C = dofile("Tools/regression/core_env.lua")
local env, K = C.New({ width = 1920, height = 1080, size = "auto", fit = true })
C.Boot(env)
K.Options.Write("Widgets", "resizeDebounce", false)
env.RunTimers()
local changes, searches = 0, 0
K.Callbacks.Register("ScaleChanged", "resize-test", function() changes = changes + 1 end)
local limit = K.Setup.Layouts.ScaleLimit
K.Setup.Layouts.ScaleLimit = function(...)
	searches = searches + 1
	return limit(...)
end
local function Screen(w, h)
	env.GetPhysicalScreenSize = function() return w, h end
	env.UIParent._width, env.UIParent._height = 768 * w / h / env.UIParent._scale, 768 / env.UIParent._scale
end
local function Burst()
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	env.FireEvent("UI_SCALE_CHANGED")
	env.FireEvent("CVAR_UPDATE", "uiScale")
	local root = K.Scale.Root()
	root:GetScript("OnSizeChanged")(root)
end
Screen(2560, 1440)
env.FireEvent("DISPLAY_SIZE_CHANGED")
Screen(3840, 2160)
env.FireEvent("UI_SCALE_CHANGED")
Screen(5120, 1440)
env.FireEvent("CVAR_UPDATE", "uiScale")
assert(changes == 0 and searches == 0, "coalesce all three events before doing any fitting or layout")
env.RunTimers()
assert(changes == 1 and searches == 1, "three events must do one fit and one layout using the final screen")
local before = K.Scale.AppliedUserScale()
Burst()
env.RunTimers()
assert(changes == 1 and searches == 1, "a focus-only event burst must do no fitting or layout")
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	Screen(unpack(screen))
	Burst()
	env.RunTimers()
end
local n = searches
Screen(5120, 1440)
Burst()
env.RunTimers()
assert(searches == n and K.Scale.AppliedUserScale() == before, "a resolution round trip must reuse the exact fitted answer")
K.Options.Write("Appearance", "textFloor", false)
assert(searches > n, "a fitting setting must invalidate the session's resolution answers")
local root, scale = K.Scale.Root(), K.Scale.Root():GetScale()
local applied = changes
env.SetCombat(true)
Screen(2560, 1440)
Burst()
env.RunTimers()
Screen(3840, 2160)
Burst()
env.RunTimers()
assert(changes == applied and root:GetScale() == scale, "protected geometry must wait for Combat.Queue")
env.SetCombat(false)
env.RunTimers()
assert(changes == applied + 1, "combat ending must apply only the final pending size")
assert(#env._errors == 0 and K.ErrorCount() == 0, "resize must complete without addon errors")
print("scale resize ok")
