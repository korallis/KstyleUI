-- perf_runner.lua: measure registered combat paths, allocation budgets and PUC Lua 5.1 CPU headroom.
local Measure = dofile("Tools/regression/measure.lua")
local fs = dofile("Tools/regression/fs.lua")

local ATTEMPTS = 3
local GROUPS = {
	core = { "Core.lua", "KstyleUI_ActionBars.lua", "KstyleUI_CombatText.lua", "KstyleUI_Cooldowns.lua", "KstyleUI_GroupFrames.lua", "KstyleUI_Meters.lua", "KstyleUI_Tooltips.lua" },
	frames = { "KstyleUI_Nameplates.lua", "KstyleUI_UnitFrames.lua" },
	skins = { "KstyleUI_Skins.lua" },
	hud = { "KstyleUI_DataBars.lua", "KstyleUI_Minimap.lua" },
}

local DIR = "Tools/regression/perf"
local FIELDS = { name = true, budget = true, setup = true, calls = true }

local Perf = {}

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

local function Exists(path)
	local handle = io.open(path, "rb")
	if handle then
		handle:close()
		return true
	end
	return false
end

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

local MIN_HEADROOM = 5

local function HeadroomProblem(name, budget, us)
	if budget >= MIN_HEADROOM * us then
		return nil
	end
	return string.format("%s: budget %g us is %.1f times the %.3g us Lua 5.1 CPU time; set it to at least %.3g us (%d times)",
		name, budget, budget / us, us, MIN_HEADROOM * us, MIN_HEADROOM)
end

do
	assert(HeadroomProblem("X", 100, 10) == nil, "a budget 10 times the Lua 5.1 time passes")
	assert(HeadroomProblem("X", 50, 10) == nil, "a budget 5 times the Lua 5.1 time passes")
	local tight = HeadroomProblem("X", 40, 13)
	assert(tight and tight:find("^X: budget 40 us is 3.1 times") and tight:find("set it to at least 65 us", 1, true), "the PR #167 budget, 3 times the Lua 5.1 time, fails and names the fix: " .. tostring(tight))
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

local function Load(group)
	local names = fs.list(DIR)
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

local function LoadAverage()
	local load = os.getenv("KSTYLEUI_LOAD")
	return load ~= "" and load or nil
end

local function IsTimeProblem(problem)
	return problem:find("over its budget", 1, true) ~= nil
end

local function Attempt(entry, run, checkHeadroom)
	local problems, r = Measure.Check({ name = entry.name, budget = entry.budget, run = run, calls = entry.calls })
	local tight = checkHeadroom and HeadroomProblem(entry.name, entry.budget, r.time * 1e6) or nil
	return problems, r, tight
end

local function Fastest(entry, run, checkHeadroom)
	local bestProblems, best, bestTight, attempts
	local kept, order = {}, {}
	for attempt = 1, ATTEMPTS do
		local problems, r, tight = Attempt(entry, run, checkHeadroom)
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

do
	assert(IsTimeProblem("X: 12.0 us per call, over its budget 10 us") and not IsTimeProblem("X: allocates 40 bytes per call: a.lua:1 (40 bytes)"), "only the time problem clears on another attempt")
	local load = LoadAverage()
	assert(load == nil or load:match("^%d"), "the load average reads as numbers, got " .. tostring(load))
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
	local problems, r, tight, attempts = Fastest(fake, slow, false)
	Measure.Check = real
	assert(#problems == 0 and attempts == 3 and r.time == 5e-6 and tight == nil, "the third, quick attempt counts: " .. tostring(attempts) .. " attempts, " .. tostring(r.time))
	calls = 0
	Measure.Check = function(e)
		return { e.name .. ": 500.0 us per call, over its budget " .. e.budget .. " us" }, { time = 500e-6, addonKb = 0, kb = 0 }
	end
	local slowest
	problems, slowest, tight, attempts = Fastest(fake, slow, false)
	Measure.Check = real
	assert(#problems == 1 and attempts == 3 and slowest.time == 500e-6 and tight == nil, "a path slow on every attempt fails after " .. ATTEMPTS .. " attempts")
	calls = 0
	Measure.Check = function(e)
		local n = calls
		calls = calls + 1
		if n == 0 then
			return { e.name .. ": 500.0 us per call, over its budget " .. e.budget .. " us", e.name .. ": allocates 40 bytes per call: KstyleUI_Fake/Hot.lua:5 (40 bytes)" }, { time = 500e-6, addonKb = 0.04, kb = 0.04 }
		end
		return {}, { time = 5e-6, addonKb = 0, kb = 0 }
	end
	problems, r, tight, attempts = Fastest(fake, slow, false)
	Measure.Check = real
	assert(attempts == 2 and r.time == 5e-6 and tight == nil, "the quick second attempt sets the time")
	assert(#problems == 1 and problems[1]:find("allocates 40 bytes", 1, true), "the first attempt's allocation still fails the path: " .. tostring(problems[1]))
	assert(GroupProblem({ "A.lua", "B.lua" }, { x = { "A.lua" }, y = { "B.lua" } }) == nil, "a full partition passes")
	assert(GroupProblem({ "A.lua", "B.lua" }, { x = { "A.lua" } }):find("B.lua is in no group", 1, true), "a file in no group fails")
	assert(GroupProblem({ "A.lua" }, { x = { "A.lua" }, y = { "A.lua" } }):find("both", 1, true), "a file in two groups fails")
	assert(GroupProblem({ "A.lua" }, { x = { "A.lua", "C.lua" } }):find("does not hold", 1, true), "a listed file that is missing fails")
end

return function(group)
local paths = Load(group)
local label = "test-perf (" .. group .. ")"
local windows = package.config:sub(1, 1) == "\\"
local checkHeadroom = not windows and rawget(_G, "jit") == nil
if windows then
	print("HeadroomProblem skipped: Windows MSVC os.clock measures wall time, not Lua 5.1 CPU time")
elseif not checkHeadroom then
	print("HeadroomProblem skipped: requires PUC Lua 5.1 CPU time")
end
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
		local measured, problems, r, tight, attempts = pcall(Fastest, entry, run, checkHeadroom)
		env.SetQuiet(false)
		if not measured then
			Fail(entry.name .. ": raised " .. tostring(problems))
		else
			print(string.format("%-40s %7.2f us of %4g   %5.0f B/call on addon lines   %6.0f B/call in all%s", entry.name, r.time * 1e6, entry.budget, r.addonKb * 1024, r.kb * 1024, attempts > 1 and string.format("   (fastest of %d attempts)", attempts) or ""))
			for _, problem in ipairs(problems) do
				Fail(problem)
			end
			if tight then
				if os.getenv("CI") == "true" and os.getenv("RUNNER_ENVIRONMENT") == "github-hosted" then
					print("WARN " .. tight)
				else
					Fail(tight)
				end
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
