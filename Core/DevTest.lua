-- DevTest.lua: /kstyle test smoke checks and the devlog in KstyleUIDB.
local _, ns = ...

local DevTest = {}
ns.DevTest = DevTest

local L = ns.L
local MAX_ENTRIES = 500
local MAX_MESSAGE = 1000
local MAX_BLOCKED = 50

local pending = {}
local checks = {}
local blocked = {}

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
