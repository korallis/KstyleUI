-- test-devtest-profile.lua: /kstyle perf times the event dispatcher, Motion and Calm only inside its window, on a controlled clock.
local W = dofile("Tools/regression/widget_env.lua")
local Printed = W.CoreEnv.Printed

local function boot(opts)
	local env, K = W.New(opts)
	local clock = { ms = 0, fps = 60 }
	env.debugprofilestop = function()
		return clock.ms
	end
	env.GetFramerate = function()
		return clock.fps
	end
	return env, K, env.SlashCmdList.KSTYLE, clock
end

local function perfLines(env)
	local out = {}
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "Perf" then
			out[#out + 1] = entry.message
		end
	end
	return out
end

local function has(lines, text)
	for _, line in ipairs(lines) do
		if line == text then
			return true
		end
	end
	return false, "missing " .. text .. " in:\n" .. table.concat(lines, "\n")
end

local function scriptFrom(env, file)
	for _, frame in ipairs(env._frames) do
		local fn = frame:GetScript("OnUpdate")
		if fn and debug.getinfo(fn, "S").source == "@" .. file then
			return frame, fn
		end
	end
end

local function tick(frame, clock, dt)
	clock.ms = clock.ms + dt * 1000
	frame:GetScript("OnUpdate")(frame, dt)
end

-- Outside a window every driver runs its own handler; a window swaps timing in for running and new drivers alike.
do
	local env, K, slash, clock = boot()
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(100, 40)
	K.Layout.Register(frame, "databars.xp", { anchor = "BOTTOMLEFT", x = 10, y = 10 }, { label = "XP" })
	W.Settle(env)
	K.Layout.Calm.Update()
	env.SetCombat(true)
	W.Settle(env)
	env.SetCombat(false)
	local calm, wait = scriptFrom(env, "Core/Layout/Calm.lua")
	assert(calm, "leaving combat starts the Calm wait with its own handler")

	K.Events.Register("Bench", "BENCH", function()
		clock.ms = clock.ms + 5
	end)
	local events = env._frames[#env._frames]
	local dispatch = events:GetScript("OnEvent")
	local first = K.Motion.Tween({}, function() end, 0, 1, 100, "linear")
	local motion, step = scriptFrom(env, "Core/Motion.lua")
	assert(motion, "a tween runs Motion's own step")

	slash("perf 5")
	local sampler = env._frames[#env._frames]
	assert(sampler ~= motion and sampler ~= calm and sampler:GetScript("OnUpdate"), "the window samples on its own frame")
	assert(events:GetScript("OnEvent") ~= dispatch, "a window times the running event dispatcher")
	assert(motion:GetScript("OnUpdate") ~= step, "a window times the running Motion driver")
	assert(calm:GetScript("OnUpdate") ~= wait, "a window times the running Calm wait")
	env.FireEvent("BENCH")
	env.FireEvent("BENCH")
	tick(motion, clock, 0.25)
	K.Motion.Stop(first)
	assert(motion:GetScript("OnUpdate") == nil, "an idle Motion driver stops")
	K.Motion.Tween({}, function() end, 0, 1, 100, "linear")
	assert(motion:GetScript("OnUpdate") ~= step, "a tween started inside the window is timed")
	tick(motion, clock, 0.25)
	tick(calm, clock, 0.25)
	tick(sampler, clock, 1)
	slash("perf")

	assert(events:GetScript("OnEvent") == dispatch, "the plain event dispatcher is back after the window")
	assert(motion:GetScript("OnUpdate") == step, "the plain Motion step is back after the window")
	assert(calm:GetScript("OnUpdate") == wait, "the plain Calm wait is back after the window")
	assert(sampler:GetScript("OnUpdate") == nil, "the sampler stops with the window")
	local lines = perfLines(env)
	assert(has(lines, "  10.00 ms/s      2 calls  Bench BENCH"))
	local motionRow, calmRow
	for _, line in ipairs(lines) do
		motionRow = motionRow or line:match("(%d+) calls  Motion step$")
		calmRow = calmRow or line:match("(%d+) calls  Calm wait$")
	end
	assert(motionRow == "2" and calmRow == "1", "both drivers are timed, got " .. tostring(motionRow) .. " and " .. tostring(calmRow))
	assert(Printed(env, "type /reload to save it"), "stopping says how to save the report")
end

-- Results keep their arity, nested time counts once, a reset clock never goes negative, and the window ends on time.
do
	local env, K, slash, clock = boot()
	local function values()
		return 17, nil, nil
	end
	assert(select("#", K.DevTest.Time("arity", values)) == 3, "with no window a timed call keeps its results")
	slash("perf 3")
	assert(select("#", K.DevTest.Time("arity", values)) == 3, "inside a window a timed call keeps its results")
	K.DevTest.Time("outer", function()
		clock.ms = clock.ms + 100
		K.DevTest.Time("inner", function()
			clock.ms = clock.ms + 600
		end)
	end)
	K.DevTest.Time("reset", function()
		clock.ms = 0
	end)
	local sampler = env._frames[#env._frames]
	for i = 1, 7 do
		clock.fps = 50 + i
		tick(sampler, clock, 0.375)
	end
	assert(K.DevTest.Profiling(), "a 3 s window still records at 2.625 s")
	clock.fps = 58
	tick(sampler, clock, 0.375)
	assert(not K.DevTest.Profiling(), "a 3 s window ends at 3 s")
	local lines = perfLines(env)
	assert(has(lines, "3.0 s window: 56 fps mean, 52 lowest, 60 highest, 7 samples"))
	assert(has(lines, "this addon's Lua: 233.3 ms per second, 23.33% of the wall time, 4 timed calls"))
	assert(has(lines, " 200.00 ms/s      1 calls  inner"))
	assert(has(lines, "  33.33 ms/s      1 calls  outer"))
	assert(has(lines, "   0.00 ms/s      1 calls  reset"))
end

-- One sampler for every window, no report from an empty window, a non-finite length refused, a fraction kept.
do
	local env, K, slash = boot({ setup = function(e)
		e.GetLocale = function()
			return "deDE"
		end
	end })
	slash("perf 1")
	local frames = #env._frames
	for _ = 1, 4 do
		slash("perf")
		slash("perf 1")
	end
	assert(#env._frames == frames, "every window reuses one sampler frame")
	slash("perf")
	assert(#perfLines(env) == 0, "a window stopped before its first frame writes no report")
	slash("perf 1e309")
	assert(not K.DevTest.Profiling(), "an infinite window is refused")
	K.DevTest.Profile(0 / 0)
	assert(not K.DevTest.Profiling(), "a NaN window is refused")
	slash("perf 1.8")
	assert(Printed(env, " 1.8 "), "a fractional window prints its length")
	slash("perf")
	slash("help")
	assert(not Printed(env, "/kstyle perf [seconds] - record"), "the perf help line is translated")
end

do
	local env, K = W.New()
	env.debugprofilestop = nil
	env.SlashCmdList.KSTYLE("perf 5")
	assert(not K.DevTest.Profiling(), "without debugprofilestop nothing records")
	assert(Printed(env, "debugprofilestop"), "without debugprofilestop the profiler says why it cannot run")
end

print("devtest profile ok")
