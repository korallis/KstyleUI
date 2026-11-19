-- test-perf-resize.lua: a saved whole-suite HUD changes resolution and back without repeating fitting and module rebuilds.
local Suite = dofile("Tools/regression/suite_env.lua")
local Budget = dofile("Tools/regression/path_budget.lua")
local reload = Suite.Prepare("medallions", 5120, 1440)
local env, K = reload()
local changes = 0
local bindings, reads = 0, 0
local action, cooldowns = env._addons.KstyleUI_ActionBars, env._addons.KstyleUI_Cooldowns
local bind, read = action.ApplyBindings, cooldowns.Settings.Read
action.ApplyBindings = function(...) bindings = bindings + 1; return bind(...) end
cooldowns.Settings.Read = function(...) reads = reads + 1; return read(...) end
K.Callbacks.Register("ScaleChanged", "resize-budget", function() changes = changes + 1 end)
local function Resize(w, h)
	env.GetPhysicalScreenSize = function() return w, h end
	env.UIParent._width, env.UIParent._height = 768 * w / h / env.UIParent._scale, 768 / env.UIParent._scale
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	env.FireEvent("UI_SCALE_CHANGED")
	env.FireEvent("CVAR_UPDATE", "uiScale")
	local root = K.Scale.Root()
	root:GetScript("OnSizeChanged")(root)
	env.RunTimers()
end
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local function RoundTrip()
		Resize(1936, 1048)
		Resize(unpack(screen))
	end
	Resize(unpack(screen))
	RoundTrip()
	changes = 0
	bindings, reads = 0, 0
	local result = Budget.Count(env, RoundTrip)
	Budget.Check(result, 18000000, 400000, "resize: reuse fitted sizes and avoid reapplying unchanged module state")
	assert(changes == 2, "the budget must include both completed size changes")
	assert(bindings == 0 and reads == 0, "a resize must preserve action bindings and the cooldown settings snapshot")
	print(string.format("resize %dx%d: %d instructions, %d calls", screen[1], screen[2], result.instructions, result.calls))
end
local result = Budget.Count(env, function() Resize(3840, 2160) end)
Budget.Check(result, 5000, 20, "resize: skip fitting and refreshes when the root size and scale are unchanged")
assert(#env._errors == 0 and K.ErrorCount() == 0, "the resize budget must exercise a successful path")
print("perf resize ok")
