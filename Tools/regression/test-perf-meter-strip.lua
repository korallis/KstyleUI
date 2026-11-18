-- test-perf-meter-strip.lua: unchanged meter fitting does not read data-strip sources or re-anchor the strip.
local M = dofile("Tools/regression/meters_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local env, K, meters = M.New({ setup = function(e)
	D.Game(e)
	D.Blizzard(e)
	D.Menus(e)
end })
dofile("Tools/regression/load_files.lua")(D.Files(), env)
K.Modules.Enable("DataBars")
M.Enable(env, K)
env.RunTimers()
M.W.Settle(env)
local strip = env._addons.KstyleUI_DataBars.Strip
local view, meter = strip.view, meters.Damage.list
strip.Refresh()
local reads, anchors = 0, 0
local framerate, point = env.GetFramerate, view.frame.SetPoint
env.GetFramerate = function(...) reads = reads + 1; return framerate(...) end
view.frame.SetPoint = function(self, ...) anchors = anchors + 1; return point(self, ...) end
for _ = 1, 10 do meter:Fit() end
assert(reads == 0 and anchors == 0, "unchanged meter fits must not refresh sources or re-anchor the data strip")
assert(#env._errors == 0 and K.ErrorCount() == 0, "meter fitting must keep working")
print("meter fit leaves the strip alone")
