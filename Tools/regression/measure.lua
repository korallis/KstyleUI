-- measure.lua: time a call and count the memory it allocates with the garbage collector stopped, and name the addon lines that allocate.
--
--   local Measure = dofile("Tools/regression/measure.lua")
--   local r = Measure.Run(fn, { calls = 1000 })
--   local problems, r = Measure.Check({ name = "UnitFrames UNIT_HEALTH", budget = 60, run = fn })
--
-- Run calls fn 10 times to warm caches, then opts.rounds rounds (5 by default) of opts.calls calls (1,000
-- by default) with the collector stopped. The fastest round counts, so a round another process slowed
-- does not set the time. It returns:
--   calls    the calls per round
--   rounds   the rounds run
--   time     CPU seconds per call in the fastest round
--   kb       KB allocated per call by all code, stubs included
--   addonKb  KB allocated per call on addon lines
--   sites    the addon lines that allocate, most bytes first: { { where = "Core/X.lua:12", bytes = n } }
--   traced   the calls run under the debug hook: 0, or opts.calls when kb is above 0
-- When kb is above 0, Run runs opts.calls more calls under a debug hook that charges each allocation to
-- the line that ran it, so a line that allocates only now and then is found too (the hook costs about
-- fifty times a plain call, which is most of a perf test's time). Memory a C function
-- allocates is charged to the Lua line that called it. An addon line is one in a file outside Tools/,
-- so the stubs' own allocations are counted in kb only. In quiet mode the stubs allocate almost
-- nothing, so most paths that allocate nothing skip the trace.
--
-- Check(entry) runs entry.run and returns a list of problems and the result. entry.budget is the time
-- per call in microseconds. A path fails when it is over budget or allocates on an addon line.
--
-- LuaJIT's compiler is switched off while this file is loaded: the game runs an interpreter, and a
-- compiled trace is itself an allocation.

local jit = rawget(_G, "jit")
if jit and jit.off then
	jit.off()
end

local Measure = {}

local DEFAULT_CALLS = 1000
local WARMUP_CALLS = 10
local ROUNDS = 5
local TRACE_WARMUP_CALLS = 2
local SHOWN_SITES = 5

local clock, count, getinfo = os.clock, collectgarbage, debug.getinfo

local function IsAddon(source)
	return type(source) == "string" and source:sub(1, 1) == "@" and not source:find("^@%.?/?Tools/")
end

local function Loop(fn, calls)
	for _ = 1, calls do
		fn()
	end
end

-- The source and line of the nearest Lua function at the hook's level or above, skipping C and tail frames.
local function LuaFrame(level)
	while true do
		local info = getinfo(level + 1, "Sl")
		if not info then
			return "?", 0
		end
		if info.what == "Lua" or info.what == "main" then
			return info.source, info.currentline
		end
		level = level + 1
	end
end

-- Trace(fn, calls) -> { [source] = { [line] = KB } } charged over the calls. Only a call or a return
-- changes the running function, so a line event keeps the source and takes the new line alone.
local function Trace(fn, calls)
	local sites = {}
	local source, at, last = "?", 0, nil
	local function hook(event, line)
		local now = count("count")
		if last and now > last then
			local lines = sites[source]
			if not lines then
				lines = {}
				sites[source] = lines
			end
			lines[at] = (lines[at] or 0) + (now - last)
		end
		if event == "line" then
			at = line
		elseif event == "call" then
			local info = getinfo(2, "S")
			if info.what ~= "C" then
				source, at = info.source, info.linedefined
			end
		else
			source, at = LuaFrame(3)
		end
		last = count("count")
	end
	debug.sethook(hook, "crl")
	local ok, err = pcall(Loop, fn, calls)
	debug.sethook()
	if not ok then
		error(err, 0)
	end
	return sites
end

local function Sites(charged, calls)
	local list, totalKb = {}, 0
	for source, lines in pairs(charged) do
		if IsAddon(source) then
			for line, kb in pairs(lines) do
				totalKb = totalKb + kb
				list[#list + 1] = { where = source:sub(2) .. ":" .. line, bytes = kb * 1024 / calls }
			end
		end
	end
	table.sort(list, function(a, b)
		if a.bytes ~= b.bytes then
			return a.bytes > b.bytes
		end
		return a.where < b.where
	end)
	return list, totalKb / calls
end

local function Rounds(fn, calls, rounds)
	local best, allocated = math.huge, 0
	for _ = 1, rounds do
		local before = count("count")
		local start = clock()
		Loop(fn, calls)
		local elapsed = clock() - start
		allocated = allocated + (count("count") - before)
		if elapsed < best then
			best = elapsed
		end
	end
	return best / calls, allocated / (rounds * calls)
end

local function Charge(fn, calls)
	Trace(fn, TRACE_WARMUP_CALLS)
	return Trace(fn, calls)
end

function Measure.Run(fn, opts)
	opts = opts or {}
	local calls = opts.calls or DEFAULT_CALLS
	local rounds = opts.rounds or ROUNDS
	local traceCalls = calls
	Loop(fn, WARMUP_CALLS)
	count("collect")
	count("stop")
	local ok, time, kb = pcall(Rounds, fn, calls, rounds)
	local charged
	if ok and kb > 0 then
		ok, charged = pcall(Charge, fn, traceCalls)
		if not ok then
			time = charged
		end
	end
	count("restart")
	count("collect")
	if not ok then
		error(time, 0)
	end
	local sites, addonKb = {}, 0
	if charged then
		sites, addonKb = Sites(charged, traceCalls)
	end
	return { calls = calls, rounds = rounds, time = time, kb = kb, addonKb = addonKb, sites = sites, traced = charged and traceCalls or 0 }
end

function Measure.Check(entry)
	local problems = {}
	local r = Measure.Run(entry.run, { calls = entry.calls, rounds = entry.rounds })
	local us = r.time * 1e6
	if us > entry.budget then
		problems[#problems + 1] = string.format("%s: %.1f us per call, over its budget %g us", entry.name, us, entry.budget)
	end
	if r.addonKb > 0 then
		local shown = {}
		for i = 1, math.min(#r.sites, SHOWN_SITES) do
			shown[i] = string.format("%s (%.0f bytes)", r.sites[i].where, r.sites[i].bytes)
		end
		problems[#problems + 1] = string.format("%s: allocates %.0f bytes per call: %s", entry.name, r.addonKb * 1024, table.concat(shown, ", "))
	end
	return problems, r
end

return Measure
