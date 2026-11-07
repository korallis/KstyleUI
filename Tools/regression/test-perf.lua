-- test-perf.lua: every combat path registered in Tools/regression/perf/ stays within its time budget per call and allocates no memory on addon lines.
--
-- Each file in perf/ is named after the addon folder it covers (Core.lua, KstyleUI_UnitFrames.lua) and
-- returns a list of paths: { name = "UnitFrames UNIT_HEALTH", budget = <microseconds per call>, setup =
-- function(Perf) return env, run end }. setup builds a stub environment and returns it with the function
-- to measure. The test enters combat, makes the stubs quiet and measures run with measure.lua. A path
-- fails when its fastest round averages over budget, when it allocates on an addon line, or when it
-- reports an error. Tools/regression/README.md describes the format.
local Measure = dofile("Tools/regression/measure.lua")

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

-- The checks on the registry itself.
do
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

-- Load the registry.
local paths, seen = {}, {}
for _, name in ipairs(List(DIR)) do
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
assert(#paths > 0, "no combat paths are registered in " .. DIR)

-- Measure each path.
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
		local measured, problems, r = pcall(Measure.Check, { name = entry.name, budget = entry.budget, run = run, calls = entry.calls })
		env.SetQuiet(false)
		if not measured then
			Fail(entry.name .. ": raised " .. tostring(problems))
		else
			print(string.format("%-40s %7.2f us of %4g   %5.0f B/call on addon lines   %6.0f B/call in all", entry.name, r.time * 1e6, entry.budget, r.addonKb * 1024, r.kb * 1024))
			for _, problem in ipairs(problems) do
				Fail(problem)
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
	local names, listed = {}, {}
	for _, failure in ipairs(failures) do
		local name = failure:match("^(.-):")
		if name and not listed[name] then
			listed[name] = true
			names[#names + 1] = name
		end
	end
	print("test-perf: " .. #names .. " of " .. #paths .. " combat paths failed: " .. table.concat(names, ", "))
	os.exit(1)
end
print("test-perf: " .. #paths .. " combat paths ok")
