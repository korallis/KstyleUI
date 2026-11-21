-- DevTest.lua: /kstyle test smoke checks and the devlog in KstyleUIDB.
local _, ns = ...

local DevTest = {}
ns.DevTest = DevTest

local L = ns.L
local format = string.format
local MAX_ENTRIES = 500
local MAX_MESSAGE = 1000
local MAX_BLOCKED = 50

local pending = {}
local checks = {}
local blocked = {}

local PERF_SECONDS = 20
local PERF_SAMPLE = 0.5
local PERF_TOP = 10
local max = math.max
local perf, sampler

function DevTest.Profiling()
	return perf ~= nil
end

local function stop(state, name, start, outer, ...)
	local spent = max(debugprofilestop() - start, 0)
	state.spent[name] = (state.spent[name] or 0) + max(spent - state.inner, 0)
	state.calls[name] = (state.calls[name] or 0) + 1
	state.inner = outer + spent
	return ...
end

function DevTest.Time(name, fn, ...)
	local state = perf
	if not state then
		return fn(...)
	end
	local outer, start = state.inner, debugprofilestop()
	state.inner = 0
	return stop(state, name, start, outer, fn(...))
end

function DevTest.Timed(name, fn)
	return function(...)
		return DevTest.Time(name, fn, ...)
	end
end

local function swap(on)
	ns.Events.SetProfiling(on)
	ns.Motion.SetProfiling(on)
	ns.Layout.Calm.SetProfiling(on)
end

local function perfFinish()
	local state = perf
	perf = nil
	sampler:SetScript("OnUpdate", nil)
	swap(false)
	local seconds = state.elapsed
	if seconds <= 0 then
		ns.Print(L["The profile stopped before its first frame, so there is nothing to report."])
		return
	end

	local count, sum, low, high = #state.fps, 0, math.huge, 0
	for i = 1, count do
		local fps = state.fps[i]
		sum, low, high = sum + fps, math.min(low, fps), max(high, fps)
	end
	DevTest.Log("Perf", format("%.1f s window: %.0f fps mean, %.0f lowest, %.0f highest, %d samples", seconds, sum / count, low, high, count))

	local spent, calls, list = 0, 0, {}
	for name, ms in pairs(state.spent) do
		spent = spent + ms
		calls = calls + state.calls[name]
		list[#list + 1] = { name = name, ms = ms, calls = state.calls[name] }
	end
	DevTest.Log("Perf", format("this addon's Lua: %.1f ms per second, %.2f%% of the wall time, %d timed calls", spent / seconds, spent / seconds / 10, calls))
	if #list == 0 then
		DevTest.Log("Perf", "no timed work ran in the window")
	else
		table.sort(list, function(a, b)
			return a.ms > b.ms
		end)
		for i = 1, math.min(#list, PERF_TOP) do
			DevTest.Log("Perf", format("%7.2f ms/s %6d calls  %s", list[i].ms / seconds, list[i].calls, list[i].name))
		end
	end
	ns.Print(L["Profile written to the devlog; type /reload to save it."])
end

local function sample(_, dt)
	local state = perf
	state.elapsed = state.elapsed + dt
	state.tick = state.tick + dt
	if state.tick >= PERF_SAMPLE then
		state.tick = state.tick % PERF_SAMPLE
		state.fps[#state.fps + 1] = GetFramerate and GetFramerate() or 0
	end
	if state.elapsed >= state.seconds then
		perfFinish()
	end
end

function DevTest.Profile(seconds)
	if perf then
		perfFinish()
		return
	end
	if type(debugprofilestop) ~= "function" then
		ns.Print(L["This client has no debugprofilestop, so the profiler cannot run."])
		return
	end
	seconds = tonumber(seconds) or PERF_SECONDS
	if seconds ~= seconds or seconds == math.huge then
		ns.Print(L["The profile needs a finite number of seconds, such as /kstyle perf 30."])
		return
	end
	seconds = max(seconds, 1)
	perf = { seconds = seconds, elapsed = 0, tick = 0, inner = 0, fps = { GetFramerate and GetFramerate() or 0 }, spent = {}, calls = {} }
	sampler = sampler or CreateFrame("Frame")
	sampler:SetScript("OnUpdate", sample)
	swap(true)
	ns.Print(format(L["Profiling for %s seconds: play normally now, then type /kstyle perf again to stop."], seconds))
end

local PROBES = {
	{ path = "CreateFrame", required = true },
	{ path = "InCombatLockdown", required = true },
	{ path = "C_Timer.After", required = true },
	{ path = "issecretvalue", why = "secret values cannot be detected" },
	{ path = "C_EncodingUtil.SerializeCBOR", why = "profile export uses the Lua serializer" },
	{ path = "C_EncodingUtil.DeserializeCBOR", why = "C_EncodingUtil profile strings cannot be imported" },
	{ path = "C_EncodingUtil.CompressString", why = "profile export uses the Lua serializer" },
	{ path = "C_EncodingUtil.DecompressString", why = "C_EncodingUtil profile strings cannot be imported" },
	{ path = "C_EncodingUtil.EncodeBase64", why = "profile export uses the Lua serializer" },
	{ path = "C_EncodingUtil.DecodeBase64", why = "base64 is decoded in Lua" },
	{ path = "C_AddOns.LoadAddOn", why = "the settings window cannot load" },
	{ path = "EditModeManagerFrame", why = "HideBlizzard cannot see Edit Mode" },
	{ path = "EventRegistry.RegisterCallback", why = "HideBlizzard polls for the end of Edit Mode" },
	{ path = "C_Secrets.ShouldAurasBeSecret", why = "aura secrecy cannot be checked" },
	{ path = "geterrorhandler", why = "caught errors are not shown" },
}

local function text(value)
	if issecretvalue and issecretvalue(value) then
		return "<secret>"
	end
	local s = tostring(value)
	if #s > MAX_MESSAGE then
		s = s:sub(1, MAX_MESSAGE - 3) .. "..."
	end
	return s
end

local function append(log, entry)
	log[#log + 1] = entry
	while #log > MAX_ENTRIES do
		table.remove(log, 1)
	end
end

function DevTest.Log(module, message)
	local entry = { time = time and time() or 0, module = text(module), message = text(message) }
	local data = ns.Store and ns.Store.Data and ns.Store.Data()
	if not data then
		append(pending, entry)
		return
	end
	local log = data.devlog
	if #pending > 0 then
		for i = 1, #pending do
			append(log, pending[i])
		end
		pending = {}
	end
	append(log, entry)
end

function DevTest.AddCheck(name, fn)
	if type(name) ~= "string" or name == "" then
		error("KstyleUI.DevTest.AddCheck: name must be text", 2)
	end
	if type(fn) ~= "function" then
		error("KstyleUI.DevTest.AddCheck: fn must be a function that returns ok, detail", 2)
	end
	checks[#checks + 1] = { name = name, fn = fn }
end

local function resolve(path)
	local node = _G
	for part in path:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

function DevTest.Run()
	local passed, failed, warned = 0, 0, 0
	local function result(status, name, detail)
		if status == "PASS" then
			passed = passed + 1
		elseif status == "FAIL" then
			failed = failed + 1
		else
			warned = warned + 1
		end
		DevTest.Log("DevTest", status .. " " .. name .. (detail and (": " .. detail) or ""))
	end
	DevTest.Log("DevTest", "run started: KstyleUI " .. tostring(ns.VERSION) .. ", build " .. tostring(ns.CODE_BUILD))

	local Store, Modules = ns.Store, ns.Modules
	if Store.IsLoaded() then
		local data = Store.Data()
		local status = data.version == Store.DB_VERSION and "PASS" or "WARN"
		result(status, "store", "version " .. tostring(data.version) .. ", profile " .. tostring(Store.ProfileName()))
	else
		result("FAIL", "store", "the saved settings did not load")
	end

	local registered = {}
	for _, name in ipairs(Modules.List()) do
		registered[name] = true
		if Modules.IsEnabled(name) then
			if Modules.IsRunning(name) then
				result("PASS", "module " .. name, "running")
			elseif Modules.HasFailed(name) then
				result("FAIL", "module " .. name, "switched on, but its Enable failed")
			else
				result("FAIL", "module " .. name, "switched on, but not running yet")
			end
		end
	end
	if Store.IsLoaded() then
		local names = {}
		for name in pairs(ns.Features.modules) do
			names[#names + 1] = name
		end
		table.sort(names)
		for _, name in ipairs(names) do
			if not registered[name] and Store.Module(name).enabled == true then
				result("FAIL", "module " .. name, "switched on, but KstyleUI_" .. name .. " is not loaded")
			end
		end
	end

	local errors = ns.ErrorCount()
	if errors == 0 and #blocked == 0 then
		result("PASS", "errors", "none caught since login")
	else
		local detail = errors .. " Lua errors caught, " .. #blocked .. " blocked actions"
		if #blocked > 0 then
			detail = detail .. ": " .. table.concat(blocked, ", ")
		end
		result("FAIL", "errors", detail)
	end

	for _, probe in ipairs(PROBES) do
		if resolve(probe.path) ~= nil then
			result("PASS", "api " .. probe.path)
		elseif probe.required then
			result("FAIL", "api " .. probe.path, "missing")
		else
			result("WARN", "api " .. probe.path, "missing: " .. probe.why)
		end
	end

	if Store.IsLoaded() then
		local exported, path = Store.Export()
		if not exported then
			result("FAIL", "export", tostring(path))
		else
			local payload, err = Store.Decode(exported)
			if payload then
				result("PASS", "export", "round trip via " .. tostring(path) .. ", " .. #exported .. " characters")
			else
				result("FAIL", "export", "round trip via " .. tostring(path) .. " failed: " .. tostring(err))
			end
		end
	end

	for _, check in ipairs(checks) do
		local ok, good, detail = pcall(check.fn)
		if not ok then
			result("FAIL", check.name, "error: " .. text(good))
		else
			result(good and "PASS" or "FAIL", check.name, detail ~= nil and text(detail) or nil)
		end
	end

	DevTest.Log("DevTest", "run finished: " .. passed .. " passed, " .. failed .. " failed, " .. warned .. " warnings")
	ns.Print(string.format(L["Test finished: %d passed, %d failed, %d warnings. Type /reload to save the results to the devlog."], passed, failed, warned))
	return passed, failed, warned
end

local function onBlocked(event, addon, fn)
	if type(addon) == "string" and addon:find("^KstyleUI") then
		local entry = addon .. " " .. tostring(fn)
		if #blocked < MAX_BLOCKED then
			blocked[#blocked + 1] = entry
		end
		DevTest.Log("DevTest", event .. ": " .. entry)
	end
end

ns.Events.Register("DevTest", "ADDON_ACTION_BLOCKED", onBlocked)
ns.Events.Register("DevTest", "ADDON_ACTION_FORBIDDEN", onBlocked)
