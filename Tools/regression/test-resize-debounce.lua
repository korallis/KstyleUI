-- test-resize-debounce.lua: the optional 120 ms trailing resize delay defaults on and honours combat and the final display size.
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New({ size = "auto" })
env.RunTimers()
assert(K.Widgets.Setting("resizeDebounce") == true, "P5b: wait for resizing to stop by default, as the owner requested")
K.Options.Write("Widgets", "resizeDebounce", false)
local width, height = 1920, 1080
env.GetPhysicalScreenSize = function() return width, height end
local time, timers = 0, {}
env.C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = time + delay, run = fn } end
local function advance(seconds)
	time = time + seconds
	local again = true
	while again do
		again = false
		for i = #timers, 1, -1 do
			if timers[i].at <= time + 1e-9 then
				local timer = table.remove(timers, i)
				timer.run()
				again = true
			end
		end
	end
end
local changes = 0
K.Callbacks.Register("ScaleChanged", "resize-test", function() changes = changes + 1 end)
width, height = 2560, 1440
env.FireEvent("DISPLAY_SIZE_CHANGED")
assert(changes == 1, "P5b: a display change must still apply immediately when the option is off")
advance(0)
K.Options.Write("Widgets", "resizeDebounce", true)
width, height = 3456, 2234
env.FireEvent("DISPLAY_SIZE_CHANGED")
advance(0)
assert(changes == 1, "P5b: keep the previous HUD size while the window is being dragged")
advance(0.1)
width, height = 5120, 1440
env.FireEvent("DISPLAY_SIZE_CHANGED")
advance(0)
advance(0.119)
assert(changes == 1, "P5b: restart the 120 ms wait after every display event, including its late recheck")
advance(0.001)
assert(changes == 2, "P5b: apply the final display size once at the trailing edge")
local live = K.Scale.Pixel(1)
K.Options.Write("Widgets", "resizeDebounce", false)
env.FireEvent("DISPLAY_SIZE_CHANGED")
advance(0)
assert(K.Scale.Pixel(1) == live, "P5b: the settled result must equal the immediate live calculation")
K.Options.Write("Widgets", "resizeDebounce", true)
env.SetCombat(true)
width, height = 1920, 1080
env.FireEvent("DISPLAY_SIZE_CHANGED")
advance(1)
assert(changes == 2, "P5b: a protected resize must wait for combat to end")
env.SetCombat(false)
advance(0)
assert(changes == 3, "P5b: apply the latest requested size after combat")
assert(#env._errors == 0, table.concat(env._errors, "\n"))
print("resize debounce ok")
