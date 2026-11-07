-- test-features.lua: every switch is a boolean that is off by default, each module folder has one, and Get is strict.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local core = {}
for _, path in ipairs(TocFiles("%.lua$")) do
	if not path:match("^KstyleUI_") then
		core[#core + 1] = path
	end
end
local Features = Load(core, Stubs.NewEnv()).KstyleUI.Features
assert(type(Features) == "table", "KstyleUI.Features is missing")
assert(type(Features.Get) == "function", "KstyleUI.Features.Get is missing")

-- Every store is a table of booleans, all off: code defaults leave everything off. Functions such as
-- Get are the service's API, not stores.
local stores = 0
for store, switches in pairs(Features) do
	if type(switches) ~= "function" then
		assert(type(switches) == "table", "Features." .. tostring(store) .. " is not a store table")
		stores = stores + 1
		for key, value in pairs(switches) do
			assert(type(key) == "string", "Features." .. store .. " has a key that is not a string")
			assert(type(value) == "boolean", "Features." .. store .. "." .. key .. " is not a boolean")
			assert(value == false, "Features." .. store .. "." .. key .. " is on by default; code defaults leave it off")
		end
	end
end
assert(type(Features.modules) == "table", "Features.modules is missing")
assert(type(Features.account) == "table", "Features.account is missing")

-- One module switch per KstyleUI_<Module> folder, named <Module>, and no switch without a folder.
local folders = {}
local pipe = assert(io.popen("ls -1d KstyleUI_*/ 2>/dev/null"))
for line in pipe:lines() do
	local module = line:match("^KstyleUI_(%w+)/?$")
	if module then
		folders[module] = true
	end
end
pipe:close()
assert(next(folders), "no KstyleUI_<Module> folders found")
for module in pairs(folders) do
	assert(Features.modules[module] ~= nil, "Features.modules has no switch for KstyleUI_" .. module)
end
for module in pairs(Features.modules) do
	assert(folders[module], "Features.modules." .. module .. " has no KstyleUI_" .. module .. " folder")
end

-- Get returns a known switch and errors on an unknown store or key, naming what it did not know.
assert(Features.Get("modules", "UnitFrames") == false, "Get must return the UnitFrames switch")
local function rejects(store, key, want)
	local ok, err = pcall(Features.Get, store, key)
	assert(not ok, "Get(" .. tostring(store) .. ", " .. tostring(key) .. ") must error")
	assert(tostring(err):find(want, 1, true), "wrong error for Get(" .. tostring(store) .. ", " .. tostring(key) .. "): " .. tostring(err))
end
rejects("modules", "UnitFrame", "unknown key UnitFrame")
rejects("modules", nil, "unknown key nil")
rejects("profiles", "UnitFrames", "unknown store profiles")
rejects("Get", "UnitFrames", "unknown store Get")
rejects(nil, "UnitFrames", "unknown store nil")

-- A module's declared defaults must agree with its switch here, and the switch is the module's default.
local function freshCore()
	local env = Load(core, Stubs.NewEnv())
	return env, env.KstyleUI
end
local function noop() end
for _, enabled in ipairs({ true, "no", 0 }) do
	local _, K = freshCore()
	local ok, err = pcall(K.Modules.Register, { name = "UnitFrames", defaults = { enabled = enabled }, Enable = noop, Disable = noop })
	assert(not ok and tostring(err):find("defaults.enabled", 1, true), "a module default switch of " .. tostring(enabled) .. " must be refused, got " .. tostring(err))
	ok, err = pcall(K.Store.RegisterDefaults, "UnitFrames", { enabled = enabled })
	assert(not ok and tostring(err):find("defaults.enabled", 1, true), "RegisterDefaults must refuse it too, got " .. tostring(err))
end
do
	local env, K = freshCore()
	K.Modules.Register({ name = "UnitFrames", defaults = { enabled = false, width = 220 }, Enable = noop, Disable = noop })
	K.Modules.Register({ name = "ActionBars", Enable = noop, Disable = noop })
	env.FireEvent("ADDON_LOADED", "KstyleUI", false)
	assert(K.Store.Module("UnitFrames").enabled == false and K.Store.Module("ActionBars").enabled == false, "a module's switch defaults to Features.modules")
	for module in pairs(Features.modules) do
		assert(K.Store.Module(module).enabled == Features.Get("modules", module), "Store.Module(" .. module .. ").enabled must match Features")
	end
end

print("features ok: " .. stores .. " stores")
