-- test-suite-load.lua: the whole suite in one stub game. The core and every module load in TOC order, the first-run setup switches every module on, and after a reload every module runs through the lifecycle with no Lua error.
--
-- Session 1 is an account's first login: no saved data, the setup opens, and Apply with every module
-- on starts each one. Session 2 is the /reload after it: the saved data comes back and every module
-- starts at PLAYER_LOGIN. Session 2 then opens every settings page, enters Layout Mode, enters and
-- leaves combat, switches to the gamepad interface and back, runs /kstyle test, switches profiles,
-- and turns every module off and on again.
--
-- The game here is the shared stubs plus the aura engine fake and a baseline of Forever APIs that
-- every client has (each name is in Blizzard_APIDocumentationGenerated or SecureStateDriver.lua). The
-- baseline only fills a name the stubs leave empty: the player exists, is not in a group, has no
-- target, no actions and no cast. Per-module tests cover behaviour; this test covers the modules
-- running side by side.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Auras = dofile("Tools/regression/auras_env.lua")

local CORE = "KstyleUI"

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- Addons in load order: the core first, then each module folder in the order the walker lists it.
local order, files, onDemand = { CORE }, { [CORE] = {} }, {}
for _, path in ipairs(TocFiles("%.lua$")) do
	local addon = path:match("^(KstyleUI_[%w_]+)/") or CORE
	if not files[addon] then
		files[addon] = {}
		order[#order + 1] = addon
		onDemand[addon] = ("\n" .. read(addon .. "/" .. addon .. ".toc")):match("\n##%s*LoadOnDemand%s*:%s*1") ~= nil
	end
	local list = files[addon]
	list[#list + 1] = path
end
assert(#order > 10, "expected the core and every module addon, found " .. #order .. " addons")

local function Fill(env, name, value)
	if env[name] == nil then
		env[name] = value
	end
end

local function Game(env)
	Auras.Engine(env)
	Fill(env, "UnitClass", function(unit)
		if unit == "player" then
			return "Hunter", "HUNTER", 3
		end
	end)
	Fill(env, "UnitIsPlayer", function(unit)
		return unit == "player"
	end)
	Fill(env, "UnitLevel", function(unit)
		return env.UnitExists(unit) and 60 or 0
	end)
	Fill(env, "UnitHealth", function()
		return env.Secret(3000)
	end)
	Fill(env, "UnitHealthMax", function()
		return 4000
	end)
	Fill(env, "UnitPower", function()
		return 2000
	end)
	Fill(env, "UnitPowerMax", function()
		return 4000
	end)
	Fill(env, "UnitPowerType", function()
		return 0, "MANA"
	end)
	Fill(env, "UnitIsConnected", function(unit)
		return env.UnitExists(unit)
	end)
	Fill(env, "UnitIsDeadOrGhost", function()
		return false
	end)
	Fill(env, "UnitCastingInfo", function() end)
	Fill(env, "UnitChannelInfo", function() end)
	Fill(env, "IsInGroup", function()
		return false
	end)
	Fill(env, "IsInRaid", function()
		return false
	end)
	Fill(env, "RegisterUnitWatch", function() end)
	Fill(env, "UnregisterUnitWatch", function() end)
	Fill(env, "C_ActionBar", {
		HasAction = function()
			return false
		end,
		GetActionTexture = function() end,
		GetActionText = function() end,
		GetActionDisplayCount = function() end,
		GetActionCooldownDuration = function() end,
		IsUsableAction = function()
			return false, false
		end,
		EnableActionRangeCheck = function() end,
	})
	-- Macro conditions the stubs do not know, such as group:raid, vehicleui or stealth, are false for a
	-- player alone with no form, and their no-forms are true.
	env.Condition = function(part)
		return part:sub(1, 2) == "no"
	end
	env.C_AddOns = {
		LoadAddOn = function(name)
			if not files[name] then
				return false, "MISSING"
			end
			if not env._addons[name] then
				Load(files[name], env)
				env.FireEvent("ADDON_LOADED", name, false)
			end
			return true
		end,
		IsAddOnLoaded = function(name)
			local loaded = env._addons[name] ~= nil
			return loaded, loaded
		end,
		DoesAddOnExist = function(name)
			return files[name] ~= nil
		end,
	}
	env._printed = {}
	env.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		env._printed[#env._printed + 1] = table.concat(parts, " ")
	end
end

-- Start(saved) -> env, KstyleUI. Loads every addon the game loads at startup, firing ADDON_LOADED
-- after each one, as the client does, then PLAYER_LOGIN.
local function Start(saved)
	local env = Stubs.NewEnv()
	env.KstyleUIDB = saved
	Game(env)
	for _, addon in ipairs(order) do
		if not onDemand[addon] then
			local ok, err = pcall(Load, files[addon], env)
			assert(ok, addon .. " failed to load: " .. tostring(err))
			env.FireEvent("ADDON_LOADED", addon, false)
		end
	end
	env.FireEvent("PLAYER_LOGIN")
	env.RunTimers()
	return env, env.KstyleUI
end

-- Clean(env, K, stage) fails with every error caught so far, then forgets them.
local function Clean(env, K, stage)
	local lines = {}
	for _, err in ipairs(env._errors) do
		lines[#lines + 1] = "  " .. tostring(err)
	end
	assert(#lines == 0 and K.ErrorCount() == 0, stage .. ": " .. math.max(#lines, K.ErrorCount()) .. " Lua errors:\n" .. table.concat(lines, "\n"))
end

local function Running(K)
	local on, off = {}, {}
	for _, name in ipairs(K.Modules.List()) do
		if K.Modules.IsRunning(name) and not K.Modules.HasFailed(name) then
			on[#on + 1] = name
		else
			off[#off + 1] = name
		end
	end
	return on, off
end

local function AllRunning(env, K, stage)
	Clean(env, K, stage)
	local _, off = Running(K)
	assert(#off == 0, stage .. ": these modules are not running: " .. table.concat(off, ", "))
end

-- Every module folder that loads at startup registers a module with its own name.
local function CheckRegistered(K)
	local registered = {}
	for _, name in ipairs(K.Modules.List()) do
		registered[name] = true
	end
	for _, addon in ipairs(order) do
		local name = addon:match("^KstyleUI_(.+)$")
		if name and not onDemand[addon] then
			assert(registered[name], addon .. " loaded but registered no module named " .. name)
		end
	end
end

-- Session 1: first login on a new account ---------------------------------------------------------

local env, K = Start(nil)
Clean(env, K, "first login")
CheckRegistered(K)
local on = Running(K)
assert(#on == 0, "code defaults leave every module off, but these run on first login: " .. table.concat(on, ", "))
assert(K.Setup.IsShown(), "the first-run setup opens on an account's first login")

local choice = K.Setup.NewChoice()
for _, entry in ipairs(K.Setup.PICKER) do
	assert(K.Setup.Available(entry.name), "the setup cannot switch on " .. entry.name .. ": its addon did not load or register")
	assert(choice.modules[entry.name] == true, "the setup starts with " .. entry.name .. " on")
end
assert(K.Setup.Apply(choice), "Setup.Apply refused the default choice")
env.RunTimers()
AllRunning(env, K, "after the setup's Apply")
for _, entry in ipairs(K.Setup.PICKER) do
	assert(K.Modules.IsEnabled(entry.name), "Apply left " .. entry.name .. " switched off")
end
env.FireEvent("PLAYER_LOGOUT")
Clean(env, K, "logout after the setup")
local saved = CoreEnv.DeepCopy(env.KstyleUIDB)

-- Session 2: the reload ---------------------------------------------------------------------------

env, K = Start(saved)
AllRunning(env, K, "login after the reload")
assert(not K.Setup.IsShown(), "the setup opens once per account")
for _, entry in ipairs(K.Setup.PICKER) do
	assert(K.Modules.IsRunning(entry.name), entry.name .. " did not start at login after the reload")
end

-- The settings window loads on demand and opens every page.
assert(K.Options.Open(), "the settings window did not open")
env.RunTimers()
local Options = env._addons.KstyleUI_Options
assert(Options and Options.Pages, "KstyleUI_Options did not load")
local pages = Options.Pages.List()
for _, page in ipairs(pages) do
	assert(K.Options.Open(page.id), "the settings window did not open the " .. page.id .. " page")
	env.RunTimers()
	Clean(env, K, "settings page " .. page.id)
end
for _, entry in ipairs(K.Setup.PICKER) do
	assert(Options.Pages.Find(pages, entry.name), "the settings window has no page or section for " .. entry.name)
end

-- Layout Mode, then combat leaves it.
assert(K.Layout.Enter(), "Layout Mode did not open")
env.RunTimers()
assert(#K.Layout.Elements() > 0, "no element registered with Layout")
Clean(env, K, "Layout Mode")
env.SetCombat(true)
env.RunTimers()
assert(not K.Layout.IsActive(), "entering combat leaves Layout Mode")
env.SetCombat(false)
env.RunTimers()
AllRunning(env, K, "after combat")

-- The gamepad interface and back.
local Input = env.Enum.InputDeviceInterfaceType
env._interfaceStyle = Input.Gamepad
env.FireEvent("INPUT_DEVICE_INTERFACE_TRANSITION", Input.Gamepad, Input.Mkb)
env.RunTimers()
Clean(env, K, "switch to the gamepad interface")
env._interfaceStyle = Input.Mkb
env.FireEvent("INPUT_DEVICE_INTERFACE_TRANSITION", Input.Mkb, Input.Gamepad)
env.RunTimers()
AllRunning(env, K, "switch back from the gamepad interface")

-- /kstyle test: every module check runs. A check that probes for a Blizzard frame or API this stub
-- game lacks may fail; a check that raises an error, a module that is not running, an error caught
-- since login and a failed profile export may not.
env.SlashCmdList.KSTYLE("test")
env.RunTimers()
Clean(env, K, "/kstyle test")
local finished, broken = nil, {}
for _, entry in ipairs(env.KstyleUIDB.devlog) do
	if entry.module == "DevTest" then
		local message = entry.message
		if message:find("^run started") then
			finished, broken = nil, {}
		elseif message:find("^run finished") then
			finished = message
		elseif message:find("^FAIL module ") or message:find("^FAIL errors") or message:find("^FAIL store")
			or message:find("^FAIL export") or message:find("^FAIL [^:]+: error: ") then
			broken[#broken + 1] = "  " .. message
		end
	end
end
assert(finished, "/kstyle test wrote no result to the devlog")
assert(#broken == 0, "/kstyle test: " .. finished .. "\n" .. table.concat(broken, "\n"))

-- A new profile starts with every module off, and switching back starts them again.
local profile = K.Store.ProfileName()
assert(K.Store.SetProfile("Suite"), "could not create and switch to a new profile")
env.RunTimers()
Clean(env, K, "switch to a new profile")
on = Running(K)
assert(#on == 0, "a new profile has every module off, but these still run: " .. table.concat(on, ", "))
assert(K.Store.SetProfile(profile), "could not switch back to " .. tostring(profile))
env.RunTimers()
AllRunning(env, K, "switch back to the first profile")

-- Every module off, then on again, without a reload.
for _, name in ipairs(K.Modules.List()) do
	K.Modules.Disable(name)
end
env.RunTimers()
Clean(env, K, "turn every module off")
on = Running(K)
assert(#on == 0, "these modules still run after Disable: " .. table.concat(on, ", "))
for _, name in ipairs(K.Modules.List()) do
	K.Modules.Enable(name)
end
env.RunTimers()
AllRunning(env, K, "turn every module on again")

env.FireEvent("PLAYER_LOGOUT")
Clean(env, K, "logout")

print("suite loads: " .. #order .. " addons, " .. #K.Modules.List() .. " modules, " .. #pages .. " settings pages")
