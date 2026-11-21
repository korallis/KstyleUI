-- test-devtest-profile.lua: /kstyle perf records the frame rate and this addon's timed Lua work into the devlog.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Printed = CoreEnv.Printed

local function messages(env, module)
	local out = {}
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == module then
			out[#out + 1] = entry.message
		end
	end
	return out
end

local function find(list, needle)
	for _, line in ipairs(list) do
		if line:find(needle, 1, true) then
			return line
		end
	end
end

do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local slash = env.SlashCmdList.KSTYLE

	local twice = K.DevTest.Timed("work", function(value)
		return value * 2
	end)
	assert(twice(3) == 6, "a timed function passes its arguments and its result through")
	assert(not find(messages(env, "Perf"), "work"), "nothing is recorded while no profile runs")

	slash("perf 5")
	assert(Printed(env, "Profiling"), "perf says how long it measures")
	local burst = 0
	K.DevTest.Time("event Fake SOME_EVENT", function()
		for i = 1, 20000 do
			burst = burst + i
		end
	end)
	slash("perf 5")
	assert(burst > 0, "the timed work ran")
	assert(Printed(env, "reload"), "stopping says how to save the report")

	local log = messages(env, "Perf")
	local window = find(log, "s window")
	assert(window and window:find("fps", 1, true), "the report carries the frame rate, got " .. tostring(window))
	local lua = find(log, "this addon's Lua")
	assert(lua and lua:find("timed calls", 1, true), "the report carries the addon's Lua time, got " .. tostring(lua))
	assert(find(log, "event Fake SOME_EVENT"), "the hottest timed work is named")
	assert(#log >= 3, "the report lands in the devlog, got " .. #log .. " lines")

	slash("perf 5")
	assert(Printed(env, "Profiling"), "a stopped profile can run again")
	slash("perf 5")
end

do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	env.debugprofilestop = nil
	env.SlashCmdList.KSTYLE("perf 5")
	assert(Printed(env, "debugprofilestop"), "without debugprofilestop the profiler says why it cannot run")
end

print("devtest profile ok")
