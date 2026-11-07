-- test-measure.lua: measure.lua times a call, counts the memory it allocates, and names the addon lines that allocate.
local Measure = dofile("Tools/regression/measure.lua")

-- chunk(path, source) -> the function a chunk named after path returns, as if that file held it.
local function chunk(path, source)
	return assert(loadstring(source, "@" .. path))()
end

local stub = chunk("Tools/regression/stubs/fake.lua", [[
return {
	alloc = function() return { 1, 2, 3 } end,
	plain = function() return 1 end,
}
]])

local addon = assert(loadstring([[
local stub = ...
local M = {}
function M.Nothing() end
function M.Table()
	local t = {}
	return t
end
function M.ViaStub()
	return stub.alloc()
end
function M.AfterStub()
	return select("#", stub.plain(), {})
end
function M.ThroughC()
	local ok = pcall(stub.plain) local t = {}
	return ok, t
end
function M.Thread()
	return coroutine.create(M.Nothing)
end
local cache
function M.Once()
	cache = cache or {}
	return cache
end
local n = 0
function M.Sometimes()
	n = n + 1
	if n % 100 == 0 then return {} end
end
return M
]], "@KstyleUI_Fake/Hot.lua"))(stub)

local function near(a, b)
	return math.abs(a - b) < 1e-9
end

-- A call that allocates nothing measures zero, and the result says how many calls ran.
do
	local r = Measure.Run(addon.Nothing)
	assert(r.calls == 1000, "1,000 calls by default, got " .. tostring(r.calls))
	assert(near(r.kb, 0), "nothing allocated, got " .. r.kb .. " KB per call")
	assert(near(r.addonKb, 0) and #r.sites == 0, "no addon allocation")
	assert(type(r.time) == "number" and r.time >= 0, "a time per call in seconds")
end

-- A table made on an addon line counts against the addon, at that line.
do
	local r = Measure.Run(addon.Table)
	assert(r.kb > 0, "a table per call allocates")
	assert(r.addonKb > 0, "the addon allocated it")
	assert(r.sites[1] and r.sites[1].where == "KstyleUI_Fake/Hot.lua:5", "the site is the line that made the table, got " .. tostring(r.sites[1] and r.sites[1].where))
	assert(r.sites[1].bytes > 0, "the site says how many bytes per call")
end

-- Memory a stub allocates is counted in kb but not against the addon.
do
	local r = Measure.Run(addon.ViaStub)
	assert(r.kb > 0, "the stub's table is counted in the total")
	assert(near(r.addonKb, 0) and #r.sites == 0, "a stub's allocation is not the addon's, got " .. tostring(r.sites[1] and r.sites[1].where))
end

-- An allocation on the addon's line after a stub returns is the addon's.
do
	local r = Measure.Run(addon.AfterStub)
	assert(r.addonKb > 0 and r.sites[1].where == "KstyleUI_Fake/Hot.lua:12", "the table after the stub call belongs to line 12, got " .. tostring(r.sites[1] and r.sites[1].where))
end

-- A Lua function called back through a C function returns to the addon line that called it.
do
	local r = Measure.Run(addon.ThroughC)
	assert(r.addonKb > 0 and r.sites[1].where == "KstyleUI_Fake/Hot.lua:15", "the table after pcall belongs to line 15, got " .. tostring(r.sites[1] and r.sites[1].where))
end

-- Memory a C function allocates for the addon counts against the addon line that called it.
do
	local r = Measure.Run(addon.Thread)
	assert(r.addonKb > 0 and r.sites[1].where == "KstyleUI_Fake/Hot.lua:19", "coroutine.create allocates for line 19, got " .. tostring(r.sites[1] and r.sites[1].where))
end

-- Warm-up calls run first, so a cache filled on the first call is not a per-call allocation.
do
	local r = Measure.Run(addon.Once)
	assert(near(r.kb, 0) and #r.sites == 0, "a one-time cache is not a per-call allocation")
end

-- An allocation every 100th call is still the addon's: the trace covers as many calls as a round.
do
	local r = Measure.Run(addon.Sometimes)
	assert(r.addonKb > 0 and r.sites[1] and r.sites[1].where == "KstyleUI_Fake/Hot.lua:29", "a table every 100th call belongs to line 29, got " .. tostring(r.sites[1] and r.sites[1].where))
	assert(#Measure.Check({ name = "Fake Sometimes", budget = 1000, run = addon.Sometimes }) == 1, "and Check fails it")
end

-- opts.calls sets the number of calls, and the time is CPU seconds per call.
do
	local spin = function()
		local start = os.clock()
		while os.clock() - start < 0.0002 do
		end
	end
	local r = Measure.Run(spin, { calls = 20 })
	assert(r.calls == 20, "opts.calls sets the count")
	assert(r.time >= 0.0002, "the time is per call, got " .. r.time)
end

-- The garbage collector stays stopped while calls run, so collected garbage does not hide allocation.
do
	local big = function()
		local t = {}
		for i = 1, 200 do
			t[i] = i
		end
		return t
	end
	local r = Measure.Run(big, { calls = 200 })
	assert(r.kb > 1, "200 numbers per call is over 1 KB, got " .. r.kb)
end

-- A call that raises an error stops the run with that error, and the collector runs again afterwards.
do
	local ok, err = pcall(Measure.Run, function()
		error("boom", 0)
	end)
	assert(not ok and tostring(err):find("boom", 1, true), "the error comes through")
	local before = collectgarbage("count")
	for _ = 1, 100000 do
		local _ = {}
	end
	assert(collectgarbage("count") < before + 3000, "the collector runs after a failed run")
end

-- Check(entry) passes a path within budget that allocates nothing.
do
	local problems, r = Measure.Check({ name = "Fake Nothing", budget = 1000, run = addon.Nothing })
	assert(#problems == 0, tostring(problems[1]))
	assert(r and near(r.addonKb, 0), "Check returns the result too")
end

-- Check fails a path that allocates and names the line.
do
	local problems = Measure.Check({ name = "Fake Table", budget = 1000, run = addon.Table })
	assert(#problems == 1, "one problem, got " .. #problems)
	assert(problems[1]:find("Fake Table", 1, true) and problems[1]:find("KstyleUI_Fake/Hot.lua:5", 1, true), problems[1])
end

-- Check fails a path over its time budget and says the time and the budget in microseconds.
do
	local spin = function()
		local start = os.clock()
		while os.clock() - start < 0.0002 do
		end
	end
	local problems = Measure.Check({ name = "Fake Spin", budget = 50, run = spin, calls = 20 })
	assert(#problems == 1 and problems[1]:find("Fake Spin", 1, true) and problems[1]:find("budget 50", 1, true), tostring(problems[1]))
end

print("test-measure: ok")
