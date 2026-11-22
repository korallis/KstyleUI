-- bench-scalelimit.lua: alternate the frozen previous search and the current search, with cold result caches and stopped GC.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local display = arg[1] == "--display"
local physicalWidth, physicalHeight = 1920, 1080
local env, K = CoreEnv.New({ fit = true, size = "auto", setup = function(e)
	e.GetPhysicalScreenSize = function()
		return physicalWidth, physicalHeight
	end
end })
local previous = { L = K.L, Scale = K.Scale, Tokens = K.Tokens }
assert(loadfile("Tools/regression/fixtures/scalelimit-before.lua"))("KstyleUI", previous)
local sides = { previous.Setup.Layouts, K.Setup.Layouts }
if display then
	CoreEnv.Boot(env)
	local profile, enabled = K.Store.Profile(), sides[2].Enabled("DPS")
	for _, element in ipairs(sides[2].ELEMENTS) do
		local section = profile[element.module] or {}
		profile[element.module], section.enabled = section, true
		local id = element.key:match("^[^.]+%.(.+)$")
		local cast = id:match("^castbar%.(.+)$")
		local entry = section[cast or id] or {}
		section[cast or id] = entry
		if cast then
			entry.castbar, entry.style = enabled[element.key], "plate"
		else
			entry.enabled = enabled[element.key]
		end
	end
	K.Options.Write("Layout", "arrangement", "spread")
	env.RunTimers()
end
local caches = {}
for i, layouts in ipairs(sides) do
	for up = 1, 40 do
		local name, value = debug.getupvalue(layouts.ScaleLimit, up)
		if name == "limits" then
			caches[i] = value
		end
	end
	assert(caches[i], "the benchmark must invalidate the real result cache")
end

print(_VERSION .. " (PUC required; Windows os.clock is wall time), 5 alternating A/B runs; all calls cold")
print(display and "path: DISPLAY_SIZE_CHANGED through Scale.Apply (core loaded, Spread, automatic size)" or "path: Layouts.ScaleLimit")
assert(not rawget(_G, "jit"), "use PUC lua5.1, never LuaJIT, for timing")
for _, style in ipairs({ "medallions" }) do
	if display then
		env.RunTimers()
	end
	for _, screen in ipairs({ { 5120, 1440 }, { 3456, 2234 } }) do
		physicalWidth, physicalHeight = screen[1], screen[2]
		local times, garbage, limits = { {}, {} }, { {}, {} }, {}
		for round = 1, 5 do
			for side, layouts in ipairs(sides) do
				K.Setup.Layouts = layouts
				if display then
					physicalWidth = screen[1] + 1
					env.FireEvent("DISPLAY_SIZE_CHANGED")
					env.RunTimers()
					physicalWidth = screen[1]
				end
				for key in pairs(caches[side]) do
					caches[side][key] = nil
				end
				collectgarbage("collect")
				collectgarbage("stop")
				local kb = collectgarbage("count")
				local start = os.clock()
				if display then
					env.FireEvent("DISPLAY_SIZE_CHANGED")
					limits[side] = K.Scale.AppliedUserScale()
				else
					limits[side] = layouts.ScaleLimit(screen[1], screen[2], "DPS", nil)
				end
				times[side][round] = (os.clock() - start) * 1000
				garbage[side][round] = (collectgarbage("count") - kb) * 1024
				collectgarbage("restart")
				if display then
					env.RunTimers()
				end
			end
			assert(string.format("%.17g", limits[1]) == string.format("%.17g", limits[2]), "every timed result is bit-identical")
		end
		for side = 1, 2 do
			table.sort(times[side])
			table.sort(garbage[side])
		end
		print(string.format("%-10s %dx%d before %.3f ms [%.3f, %.3f], %.0f B; after %.3f ms [%.3f, %.3f], %.0f B; scale %.17g; errors %d",
			style, screen[1], screen[2], times[1][3], times[1][1], times[1][5], garbage[1][3],
			times[2][3], times[2][1], times[2][5], garbage[2][3], limits[2], #env._errors))
	end
end
assert(#env._errors == 0, "no addon errors")
