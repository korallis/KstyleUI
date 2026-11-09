-- perf_runner.lua: the shared runner behind test-perf.lua and test-perf-frames.lua: every combat path registered in
-- Tools/regression/perf/ stays within its time budget per call and allocates no memory on addon lines.
--
--   dofile("Tools/regression/perf_runner.lua")("core")      -- the files GROUPS.core lists
--
-- Each file in perf/ is named after the addon folder it covers (Core.lua, KstyleUI_UnitFrames.lua) and
-- returns a list of paths: { name = "UnitFrames UNIT_HEALTH", budget = <microseconds per call>, setup =
-- function(Perf) return env, run end }. setup builds a stub environment and returns it with the function
-- to measure. The runner enters combat, makes the stubs quiet and measures run with measure.lua. A path
-- fails when its fastest round averages over budget, when it allocates on an addon line, or when it
-- reports an error. A path that fails on time is measured again, up to ATTEMPTS times in all, and its
-- fastest attempt counts, so a round that another process slowed (five agents' test runs on one Mac)
-- does not fail a sound budget; an allocation found on any attempt stands. When a failure stands, the
-- report names the machine's load average. The perf/ files are split into GROUPS, one test file each,
-- so each file keeps well inside its 20 s budget when run-all runs 18 files at once; a perf/ file that
-- no group lists fails every group. Tools/regression/README.md describes the format.
local Measure = dofile("Tools/regression/measure.lua")

local ATTEMPTS = 3
local GROUPS = {
	core = { "Core.lua", "KstyleUI_ActionBars.lua", "KstyleUI_CombatText.lua", "KstyleUI_Cooldowns.lua", "KstyleUI_GroupFrames.lua", "KstyleUI_Meters.lua" },
	frames = { "KstyleUI_Nameplates.lua", "KstyleUI_UnitFrames.lua" },
}

local DIR = "Tools/regression/perf"
local FIELDS = { name = true, budget = true, setup = true, calls = true }

local Perf = {}

-- Event(env, event, ...) -> a function that runs the OnEvent script of each frame registered for the
-- event, with these arguments, as the game dispatches it. It finds the frames on its first call, so
-- it sees the registrations combat makes, and raises if no frame is registered.
function Perf.Event(env, event, ...)
	local args, n = { ... }, select("#", ...)
	local frames, handlers, count
	local function Collect()
		frames, handlers = {}, {}
		for _, frame in ipairs(env._frames) do
			local registered = frame._events[event]
			local wanted = registered == true
			if type(registered) == "table" then
				for _, unit in ipairs(registered) do
					wanted = wanted or unit == args[1]
				end
			end
			local handler = frame._scripts.OnEvent
			if wanted and handler then
				frames[#frames + 1], handlers[#handlers + 1] = frame, handler
			end
		end
		count = #frames
		if count == 0 then
			error("Perf.Event: no frame is registered for " .. event .. " " .. tostring(args[1]), 0)
		end
	end
	return function()
		if not count then
			Collect()
		end
		for i = 1, count do
			handlers[i](frames[i], event, unpack(args, 1, n))
		end
	end
end

local function List(folder)
	local names = {}
	local pipe = assert(io.popen("ls -1A '" .. folder:gsub("'", "'\\''") .. "' 2>/dev/null"))
	for name in pipe:lines() do
		names[#names + 1] = name
	end
	pipe:close()
	table.sort(names)
	return names
end

local function Exists(path)
	local handle = io.open(path, "rb")
	if handle then
		handle:close()
		return true
	end
	return false
end

-- AreaProblem(name) -> why a perf/ file name is wrong, or nil.
local function AreaProblem(name)
	local area = name:match("^(.+)%.lua$")
	if not area then
		return name .. " is not a .lua file; perf/ holds one <Folder>.lua per addon folder"
	end
	if area == "Core" then
		return not Exists("Core/Core.xml") and "Core/Core.xml is missing" or nil
	end
	if not area:match("^KstyleUI_%w+$") or not Exists(area .. "/" .. area .. ".toc") then
		return name .. " names no addon folder; use Core.lua or KstyleUI_<Module>.lua"
	end
end

-- EntryProblem(file, i, entry, seen) -> why a registered path is malformed, or nil. seen holds the names so far.
local function EntryProblem(file, i, entry, seen)
	local where = file .. " entry " .. i
	if type(entry) ~= "table" then
		return where .. " must be a table with name, budget and setup"
	end
	for field in pairs(entry) do
		if not FIELDS[field] then
			return where .. " has unknown field " .. tostring(field) .. "; use name, budget, setup and calls"
		end
	end
	if type(entry.name) ~= "string" or not entry.name:match("%S") then
		return where .. " needs a name, such as \"UnitFrames UNIT_HEALTH\""
	end
	if seen[entry.name] then
		return where .. ": " .. entry.name .. " is already registered in " .. seen[entry.name]
	end
	if type(entry.budget) ~= "number" or entry.budget <= 0 then
		return where .. " (" .. entry.name .. ") needs a budget: microseconds per call, above 0"
	end
	if type(entry.setup) ~= "function" then
		return where .. " (" .. entry.name .. ") needs setup: function(Perf) return env, run end"
	end
	if entry.calls ~= nil and (type(entry.calls) ~= "number" or entry.calls < 1 or entry.calls % 1 ~= 0) then
		return where .. " (" .. entry.name .. ") calls must be a whole number of 1 or more"
	end
end

-- CI's runner takes about 4 times as long per call as Lua 5.1 on the Mac, so a budget is set near 10 times
-- the Lua 5.1 time measured here and fails below 5 times. LuaJIT's interpreter runs about 1.5 times faster
-- than Lua 5.1, so its time is scaled up first. CI skips this check: there the budget itself is the check.
local TARGET_HEADROOM, MIN_HEADROOM, LUAJIT_SPEEDUP = 10, 5, 1.5

-- HeadroomProblem(name, budget, us, jitted) -> why a budget is too tight to pass on CI, or nil.
local function HeadroomProblem(name, budget, us, jitted)
	local lua51 = jitted and us * LUAJIT_SPEEDUP or us
	if budget >= MIN_HEADROOM * lua51 then
		return nil
	end
	return string.format("%s: budget %g us is %.1f times the %.3g us Lua 5.1 takes here, and CI runs about 4 times slower; set it near %.3g us (%d times)",
		name, budget, budget / lua51, lua51, TARGET_HEADROOM * lua51, TARGET_HEADROOM)
end

-- The checks on the registry itself.
do
	assert(HeadroomProblem("X", 100, 10, false) == nil, "a budget 10 times the Lua 5.1 time passes")
	assert(HeadroomProblem("X", 50, 10, false) == nil, "a budget 5 times the Lua 5.1 time passes")
	local tight = HeadroomProblem("X", 40, 13, false)
	assert(tight and tight:find("^X: budget 40 us is 3.1 times") and tight:find("set it near 130 us", 1, true), "the PR #167 budget, 3 times the Lua 5.1 time, fails and names the fix: " .. tostring(tight))
	assert(HeadroomProblem("X", 40, 9.66, true), "LuaJIT's interpreter is faster than Lua 5.1, so its time is scaled before the check")
	assert(HeadroomProblem("X", 100, 10, true) == nil, "a roomy budget passes under LuaJIT too")
	assert(AreaProblem("Core.lua") == nil and AreaProblem("KstyleUI_UnitFrames.lua") == nil, "real areas pass")
	assert(AreaProblem("KstyleUI_Nowhere.lua"), "an area with no addon folder fails")
	assert(AreaProblem("notes.txt"), "a file that is not Lua fails")
	local fine = { name = "X Y", budget = 10, setup = function() end }
	assert(EntryProblem("A.lua", 1, fine, {}) == nil, "a full entry passes")
	assert(EntryProblem("A.lua", 1, fine, { ["X Y"] = "B.lua" }):find("already registered in B.lua", 1, true), "a name twice fails")
	assert(EntryProblem("A.lua", 1, { name = "X", setup = fine.setup }, {}):find("needs a budget", 1, true), "a missing budget fails")
	assert(EntryProblem("A.lua", 1, { name = "X", budget = 0, setup = fine.setup }, {}), "a zero budget fails")
	assert(EntryProblem("A.lua", 1, { name = "X", budget = 5 }, {}):find("needs setup", 1, true), "a missing setup fails")
	assert(EntryProblem("A.lua", 1, { name = "X", budget = 5, setup = fine.setup, why = "" }, {}):find("unknown field why", 1, true), "an unknown field fails")
	assert(EntryProblem("A.lua", 1, { name = "X", budget = 5, setup = fine.setup, calls = 0.5 }, {}), "a fractional call count fails")
end

-- GroupProblem(names, groups) -> why the perf/ listing and the groups disagree, or nil: every file sits in
-- exactly one group, and every listed file exists.
local function GroupProblem(names, groups)
	local owner = {}
	for group, files in pairs(groups) do
		for _, file in ipairs(files) do
			if owner[file] then
				return file .. " is listed in both " .. owner[file] .. " and " .. group
			end
			owner[file] = group
		end
	end
	local present = {}
	for _, name in ipairs(names) do
		present[name] = true
		if not owner[name] then
			return DIR .. "/" .. name .. " is in no group; add it to GROUPS in Tools/regression/perf_runner.lua"
		end
	end
	for file, group in pairs(owner) do
		if not present[file] then
			return group .. " lists " .. file .. ", which " .. DIR .. " does not hold"
		end
	end
	return nil
end

-- Load(group) -> the paths of the group's files, each file and entry checked.
local function Load(group)
	local names = List(DIR)
	local grouping = GroupProblem(names, GROUPS)
	assert(not grouping, grouping)
	assert(GROUPS[group], "no perf group named " .. tostring(group))
	local paths, seen = {}, {}
	for _, name in ipairs(GROUPS[group]) do
		local file = DIR .. "/" .. name
		local problem = AreaProblem(name)
		assert(not problem, file .. ": " .. tostring(problem))
		local list = assert(loadfile(file))(Perf)
		assert(type(list) == "table" and #list > 0, file .. " must return a list of at least one path")
		for i, entry in ipairs(list) do
			local bad = EntryProblem(file, i, entry, seen)
			assert(not bad, bad)
			seen[entry.name] = file
			paths[#paths + 1] = entry
		end
	end
	assert(#paths > 0, "no combat paths are registered for " .. group)
	return paths
end

-- LoadAverage() -> the machine's 1, 5 and 15 minute load averages as uptime prints them, or nil.
local function LoadAverage()
	local pipe = io.popen("uptime 2>/dev/null")
	if not pipe then
		return nil
	end
	local line = pipe:read("*a") or ""
	pipe:close()
	return line:match("load averages?:%s*(.-)%s*$")
end

-- TimeProblems(problems) -> the problems that are about time, which another attempt may clear; the
-- allocation problems stay whatever the load.
local function IsTimeProblem(problem)
	return problem:find("over its budget", 1, true) ~= nil
end

-- Attempt(entry, run) -> problems, result, tight: one measurement of the path with its headroom check.
local function Attempt(entry, run, onCI, jitted)
	local problems, r = Measure.Check({ name = entry.name, budget = entry.budget, run = run, calls = entry.calls })
	local tight = not onCI and HeadroomProblem(entry.name, entry.budget, r.time * 1e6, jitted) or nil
	return problems, r, tight
end

-- Fastest(entry, run, onCI, jitted) -> problems, result, tight, attempts: the path measured until it passes
-- its time checks or ATTEMPTS attempts are spent, the fastest attempt's time problems reported together with
-- every allocation problem any attempt found.
local function Fastest(entry, run, onCI, jitted)
	local bestProblems, best, bestTight, attempts
	local kept, order = {}, {}
	for attempt = 1, ATTEMPTS do
		local problems, r, tight = Attempt(entry, run, onCI, jitted)
		local slow = tight and true or false
		local timed = {}
		for _, problem in ipairs(problems) do
			if IsTimeProblem(problem) then
				slow = true
				timed[#timed + 1] = problem
			elseif not kept[problem] then
				kept[problem] = true
				order[#order + 1] = problem
			end
		end
		if not best or r.time < best.time then
			bestProblems, best, bestTight = timed, r, tight
		end
		attempts = attempt
		if not slow then
			bestProblems, best, bestTight = timed, r, tight
			break
		end
	end
	local out = {}
	for _, problem in ipairs(bestProblems) do
		out[#out + 1] = problem
	end
	for _, problem in ipairs(order) do
		out[#out + 1] = problem
	end
	return out, best, bestTight, attempts
end

-- The checks on the attempt logic itself.
do
	assert(IsTimeProblem("X: 12.0 us per call, over its budget 10 us") and not IsTimeProblem("X: allocates 40 bytes per call: a.lua:1 (40 bytes)"), "only the time problem clears on another attempt")
	local load = LoadAverage()
	assert(load == nil or load:match("^%d"), "the load average reads as numbers, got " .. tostring(load))
	-- A path that is slow on its first attempts and quick on the last passes with its fastest attempt reported.
	local calls, fake = 0, { name = "Fake", budget = 100 }
	local slow = function()
		calls = calls + 1
	end
	local real = Measure.Check
	Measure.Check = function(e)
		local n = calls
		calls = calls + 1
		return n < 2 and { e.name .. ": 500.0 us per call, over its budget " .. e.budget .. " us" } or {}, { time = n < 2 and 500e-6 or 5e-6, addonKb = 0, kb = 0 }
	end
	local problems, r, tight, attempts = Fastest(fake, slow, true, false)
	Measure.Check = real
	assert(#problems == 0 and attempts == 3 and r.time == 5e-6 and tight == nil, "the third, quick attempt counts: " .. tostring(attempts) .. " attempts, " .. tostring(r.time))
	calls = 0
	Measure.Check = function(e)
		return { e.name .. ": 500.0 us per call, over its budget " .. e.budget .. " us" }, { time = 500e-6, addonKb = 0, kb = 0 }
	end
	local slowest
	problems, slowest, tight, attempts = Fastest(fake, slow, true, false)
	Measure.Check = real
	assert(#problems == 1 and attempts == 3 and slowest.time == 500e-6 and tight == nil, "a path slow on every attempt fails after " .. ATTEMPTS .. " attempts")
	-- An allocation found on a slow first attempt stands when a quick, allocation-free attempt follows.
	calls = 0
	Measure.Check = function(e)
		local n = calls
		calls = calls + 1
		if n == 0 then
			return { e.name .. ": 500.0 us per call, over its budget " .. e.budget .. " us", e.name .. ": allocates 40 bytes per call: KstyleUI_Fake/Hot.lua:5 (40 bytes)" }, { time = 500e-6, addonKb = 0.04, kb = 0.04 }
		end
		return {}, { time = 5e-6, addonKb = 0, kb = 0 }
	end
	problems, r, tight, attempts = Fastest(fake, slow, true, false)
	Measure.Check = real
	assert(attempts == 2 and r.time == 5e-6 and tight == nil, "the quick second attempt sets the time")
	assert(#problems == 1 and problems[1]:find("allocates 40 bytes", 1, true), "the first attempt's allocation still fails the path: " .. tostring(problems[1]))
	assert(GroupProblem({ "A.lua", "B.lua" }, { x = { "A.lua" }, y = { "B.lua" } }) == nil, "a full partition passes")
	assert(GroupProblem({ "A.lua", "B.lua" }, { x = { "A.lua" } }):find("B.lua is in no group", 1, true), "a file in no group fails")
	assert(GroupProblem({ "A.lua" }, { x = { "A.lua" }, y = { "A.lua" } }):find("both", 1, true), "a file in two groups fails")
	assert(GroupProblem({ "A.lua" }, { x = { "A.lua", "C.lua" } }):find("does not hold", 1, true), "a listed file that is missing fails")
end

-- Run(group): measure the group's paths and exit 1 when any fails.
return function(group)
local paths = Load(group)
local label = "test-perf (" .. group .. ")"
local onCI, jitted = os.getenv("CI") == "true", rawget(_G, "jit") ~= nil
local failures = {}
local function Fail(message)
	failures[#failures + 1] = message
end

for _, entry in ipairs(paths) do
	local ok, env, run = pcall(entry.setup, Perf)
	if not ok then
		Fail(entry.name .. ": setup raised " .. tostring(env))
	elseif type(env) ~= "table" or type(env.SetQuiet) ~= "function" or type(run) ~= "function" then
		Fail(entry.name .. ": setup must return the stub environment and the function to measure")
	else
		env.SetCombat(true)
		env.RunTimers()
		local errors = #env._errors
		env.SetQuiet(true)
		local measured, problems, r, tight, attempts = pcall(Fastest, entry, run, onCI, jitted)
		env.SetQuiet(false)
		if not measured then
			Fail(entry.name .. ": raised " .. tostring(problems))
		else
			print(string.format("%-40s %7.2f us of %4g   %5.0f B/call on addon lines   %6.0f B/call in all%s", entry.name, r.time * 1e6, entry.budget, r.addonKb * 1024, r.kb * 1024, attempts > 1 and string.format("   (fastest of %d attempts)", attempts) or ""))
			for _, problem in ipairs(problems) do
				Fail(problem)
			end
			if tight then
				Fail(tight)
			end
			if #env._errors > errors then
				Fail(entry.name .. ": reported an error: " .. tostring(env._errors[errors + 1]))
			end
		end
	end
end

if #failures > 0 then
	print("")
	for _, failure in ipairs(failures) do
		print("  " .. failure)
	end
	local load = LoadAverage()
	if load then
		print(string.format("  machine load average (1, 5, 15 min): %s; each path had %d attempts of %d rounds", load, ATTEMPTS, 5))
	end
	local names, listed = {}, {}
	for _, failure in ipairs(failures) do
		local name = failure:match("^(.-):")
		if name and not listed[name] then
			listed[name] = true
			names[#names + 1] = name
		end
	end
	print(label .. ": " .. #names .. " of " .. #paths .. " combat paths failed: " .. table.concat(names, ", "))
	os.exit(1)
end
print(label .. ": " .. #paths .. " combat paths ok")
end
