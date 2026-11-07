-- test-devtest.lua: DevTest.Log keeps a capped devlog, /kstyle test runs the smoke checks, and /kstyle dispatches its subcommands.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Module, Printed = CoreEnv.Module, CoreEnv.Printed

local function messages(env, module)
	local out = {}
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == module then
			out[#out + 1] = entry.message
		end
	end
	return out
end

local function find(list, text)
	for _, line in ipairs(list) do
		if line:find(text, 1, true) then
			return line
		end
	end
end

-- DevTest.Log ----------------------------------------------------------------------------------

do
	local env, K = CoreEnv.New()
	K.DevTest.Log("UnitFrames", "logged before the saved data loaded")
	CoreEnv.LoadSaved(env)
	K.DevTest.Log("UnitFrames", "health bar via SetValue")
	local log = env.KstyleUIDB.devlog
	local early, late = messages(env, "UnitFrames")[1], messages(env, "UnitFrames")[2]
	assert(early == "logged before the saved data loaded", "entries logged before ADDON_LOADED are kept, got " .. tostring(early))
	assert(late == "health bar via SetValue", "entries are appended newest last")
	local last = log[#log]
	assert(last.time == env._now and last.module == "UnitFrames", "an entry has its time, module and message")

	for i = 1, 600 do
		K.DevTest.Log("Spam", "entry " .. i)
	end
	assert(#log == 500, "the devlog is capped at 500 entries, got " .. #log)
	assert(log[500].message == "entry 600" and log[1].message == "entry 101", "the oldest entries go first")

	K.DevTest.Log("Spam", string.rep("x", 5000))
	assert(#log[500].message <= 1000, "a long message is shortened")
	K.DevTest.Log("Spam", env.Secret("secret text"))
	assert(log[500].message == "<secret>", "a secret message is never stored")
	K.DevTest.Log(nil, 42)
	assert(log[500].module == "nil" and log[500].message == "42", "any value is logged as text")
end

-- /kstyle test ---------------------------------------------------------------------------------

do
	local saved = { version = 1, profiles = { Default = { UnitFrames = { enabled = true }, Bags = { enabled = true }, ActionBars = { enabled = true } } } }
	local env, K = CoreEnv.New({ saved = saved, encoding = CoreEnv.FakeEncoding() })
	K.Modules.Register(Module("UnitFrames"))
	K.Modules.Register(Module("ActionBars", {
		onEnable = function()
			error("bars broke")
		end,
	}))
	K.DevTest.AddCheck("probe ok", function()
		return true, "fine"
	end)
	K.DevTest.AddCheck("probe failing", function()
		return false, "wrong answer"
	end)
	K.DevTest.AddCheck("probe erroring", function()
		error("probe blew up")
	end)
	CoreEnv.Boot(env)
	env.FireEvent("ADDON_ACTION_BLOCKED", "KstyleUI_ActionBars", "SetBinding()")
	env.FireEvent("ADDON_ACTION_FORBIDDEN", "SomeOtherAddon", "CastSpellByName()")

	local passed, failed = K.DevTest.Run()
	assert(type(passed) == "number" and type(failed) == "number")
	local log = messages(env, "DevTest")
	assert(find(log, "PASS store"), "the store check passes")
	assert(find(log, "PASS module UnitFrames"), "a running module passes")
	assert(find(log, "FAIL module ActionBars"), "a module whose Enable failed fails")
	assert(find(log, "FAIL module Bags"), "a module that is on but whose addon is not loaded fails")
	assert(find(log, "FAIL errors"), "caught Lua errors fail the error check")
	assert(find(log, "KstyleUI_ActionBars"), "a blocked action by a KstyleUI addon is reported")
	assert(not find(log, "SomeOtherAddon"), "other addons' blocked actions are not ours")
	assert(find(log, "PASS export"), "the export round trip passes")
	assert(find(log, "C_EncodingUtil"), "the export check names the path it took")
	assert(find(log, "PASS probe ok: fine"), "an added check that passes")
	assert(find(log, "FAIL probe failing: wrong answer"), "an added check that fails")
	assert(find(log, "FAIL probe erroring"), "an added check that errors fails")
	assert(find(log, "api"), "the API probes run")
	assert(failed >= 5 and passed >= 3, "counts: " .. passed .. " passed, " .. failed .. " failed")
	assert(Printed(env, failed .. " failed"), "the summary is printed")
	assert(Printed(env, "/reload"), "the summary says how to save the log")
end

do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local passed, failed = K.DevTest.Run()
	assert(failed == 0, "a clean session with no modules passes, failed " .. failed)
	assert(passed >= 3)
	local log = messages(env, "DevTest")
	assert(find(log, "WARN"), "a missing optional API is a warning")
	assert(find(log, "Lua"), "without C_EncodingUtil the export check names the Lua path")
end

-- /kstyle --------------------------------------------------------------------------------------

do
	local calls = {}
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	assert(env.SLASH_KSTYLE1 == "/kstyle", "the slash command is /kstyle")
	local slash = env.SlashCmdList.KSTYLE
	assert(type(slash) == "function", "SlashCmdList.KSTYLE is set")

	K.Options.SetWindow(function(page)
		calls[#calls + 1] = "options:" .. tostring(page)
	end)
	slash("")
	slash("   ")
	assert(calls[1] == "options:nil" and calls[2] == "options:nil", "no argument opens the settings")

	slash("layout")
	assert(K.Layout.IsActive(), "layout enters Layout Mode")
	slash("layout")
	assert(not K.Layout.IsActive(), "and leaves it again")
	local layout = K.Layout
	K.Layout = nil
	slash("layout")
	assert(Printed(env, "Layout Mode"), "layout without Layout Mode says it is unavailable")
	K.Layout = layout
	K.Layout = { Toggle = function() calls[#calls + 1] = "layout" end }
	K.Setup = { Open = function() calls[#calls + 1] = "setup" end }
	slash("LAYOUT")
	slash("setup")
	assert(calls[3] == "layout" and calls[4] == "setup", "layout and setup reach their services, case-insensitively")

	local before = #env.KstyleUIDB.devlog
	slash("test")
	assert(#env.KstyleUIDB.devlog > before, "test runs the smoke checks")

	slash("profile")
	assert(Printed(env, "Default"), "profile lists the profiles")
	slash("profile new Raid Team")
	assert(K.Store.ListProfiles()[2] == "Raid Team", "profile new keeps spaces in the name")
	slash("profile use Raid Team")
	assert(K.Store.ProfileName() == "Raid Team")
	K.Store.Module("Bags").enabled = true
	slash("profile copy Default")
	assert(K.Store.Module("Bags").enabled == false, "profile copy copies a profile into the active one")
	slash("profile rename Raid")
	assert(K.Store.ProfileName() == "Raid")
	slash("profile reset")
	slash("profile delete Raid")
	assert(Printed(env, "active"), "a failed profile command prints the reason")
	slash("profile use Default")
	slash("profile delete Raid")
	assert(#K.Store.ListProfiles() == 1)

	env._printed = {}
	slash("dance")
	assert(Printed(env, "/kstyle layout") and Printed(env, "/kstyle profile"), "an unknown command prints the usage")
	env._printed = {}
	slash("help")
	assert(Printed(env, "/kstyle test"), "help prints the usage")
end

print("devtest ok")
