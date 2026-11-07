-- test-lifecycle.lua: Callbacks, Events and the module lifecycle: registered at load, started at PLAYER_LOGIN, events only while on.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Raises, Module, Count = CoreEnv.Raises, CoreEnv.Module, CoreEnv.Count

-- Callbacks ------------------------------------------------------------------------------------

do
	local env, K = CoreEnv.New()
	local C = K.Callbacks
	local got = {}
	local a, b = {}, {}
	C.Register("ThemeChanged", a, function(owner, x, y)
		got[#got + 1] = { "a", owner, x, y }
	end)
	C.Register("ThemeChanged", b, function(owner, x)
		got[#got + 1] = { "b", owner, x }
	end)
	C.Fire("ThemeChanged", 1, 2)
	assert(#got == 2 and got[1][1] == "a" and got[2][1] == "b", "subscribers run in the order they registered")
	assert(got[1][2] == a and got[1][3] == 1 and got[1][4] == 2, "a subscriber gets its owner, then the fired arguments")

	-- Registering again with the same owner replaces the function; it does not add a second one.
	got = {}
	C.Register("ThemeChanged", a, function()
		got[#got + 1] = "a2"
	end)
	C.Fire("ThemeChanged")
	assert(#got == 2 and got[1] == "a2", "re-registering an owner replaces its function in place")

	-- Owner-based unregister: one event, or every event the owner holds.
	got = {}
	C.Register("ScaleChanged", a, function()
		got[#got + 1] = "scale-a"
	end)
	C.Unregister("ThemeChanged", b)
	C.Fire("ThemeChanged")
	assert(#got == 1 and got[1] == "a2", "Unregister removes only that owner from that event")
	C.UnregisterAll(a)
	got = {}
	C.Fire("ThemeChanged")
	C.Fire("ScaleChanged")
	assert(#got == 0, "UnregisterAll removes the owner from every event")

	-- Names are strict, so a typo fails at once instead of never firing.
	Raises(function() C.Register("ThemeChange", a, function() end) end, "unknown callback ThemeChange", "Register")
	Raises(function() C.Fire("ProfileChange") end, "unknown callback ProfileChange", "Fire")
	Raises(function() C.Register("ThemeChanged", nil, function() end) end, "owner", "Register without an owner")
	Raises(function() C.Register("ThemeChanged", a, "Restyle") end, "function", "Register without a function")
	for _, name in ipairs({ "ThemeChanged", "ClassChanged", "ScaleChanged", "ProfileChanged", "IconsChanged", "SettingChanged", "ReloadNeeded" }) do
		C.Fire(name)
	end

	-- A subscriber that errors is reported to the error handler, and the others still run.
	got = {}
	C.Register("ClassChanged", "bad", function()
		error("boom")
	end)
	C.Register("ClassChanged", "good", function()
		got[#got + 1] = "good"
	end)
	C.Fire("ClassChanged")
	assert(#got == 1, "a failing subscriber must not stop the next one")
	assert(#env._errors == 1 and tostring(env._errors[1]):find("boom", 1, true), "the error goes to the game's error handler")
	assert(K.ErrorCount() == 1, "KstyleUI counts the errors it caught")

	-- Unregistering during a Fire skips the removed subscriber and still calls each other one once;
	-- a subscriber added during a Fire runs from the next Fire.
	C.UnregisterAll("bad")
	C.UnregisterAll("good")
	local order = {}
	C.Register("IconsChanged", "first", function()
		order[#order + 1] = "first"
		C.Unregister("IconsChanged", "second")
		C.Register("IconsChanged", "late", function()
			order[#order + 1] = "late"
		end)
	end)
	C.Register("IconsChanged", "second", function()
		order[#order + 1] = "second"
	end)
	C.Register("IconsChanged", "third", function()
		order[#order + 1] = "third"
	end)
	C.Fire("IconsChanged")
	assert(table.concat(order, ",") == "first,third", "got " .. table.concat(order, ","))
	order = {}
	C.Fire("IconsChanged")
	assert(table.concat(order, ",") == "first,third,late", "got " .. table.concat(order, ","))
end

-- Events ---------------------------------------------------------------------------------------

do
	local env, K = CoreEnv.New()
	local E = K.Events
	CoreEnv.Boot(env)

	-- A core service may register at any time. Its frame appears only when it first registers.
	local frames = #env._frames
	local got = {}
	E.Register("TestService", "BAG_UPDATE", function(event, bag)
		got[#got + 1] = event .. ":" .. tostring(bag)
	end)
	assert(#env._frames == frames + 1, "the first Register creates the owner's one event frame")
	E.Register("TestService", "BAG_UPDATE_DELAYED", function(event)
		got[#got + 1] = event
	end)
	assert(#env._frames == frames + 1, "an owner keeps one frame for all its events")
	env.FireEvent("BAG_UPDATE", 3)
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(got[1] == "BAG_UPDATE:3" and got[2] == "BAG_UPDATE_DELAYED", "handlers get the event name and payload")

	E.Unregister("TestService", "BAG_UPDATE")
	env.FireEvent("BAG_UPDATE", 4)
	assert(#got == 2, "Unregister stops one event")
	E.UnregisterAll("TestService")
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(#got == 2, "UnregisterAll stops every event of the owner")

	-- Unit events honour their unit filter.
	E.RegisterUnit("TestService", "UNIT_HEALTH", function(_, unit)
		got[#got + 1] = unit
	end, "player", "target")
	env.FireEvent("UNIT_HEALTH", "focus")
	env.FireEvent("UNIT_HEALTH", "target")
	assert(got[#got] == "target" and #got == 3, "RegisterUnit passes its units to the frame")

	-- A handler that errors is reported and counted, so /kstyle test sees it, and other frames still get the event.
	local errorsBefore = K.ErrorCount()
	local seen = 0
	E.Register("FailingService", "PLAYER_FLAGS_CHANGED", function()
		error("handler broke")
	end)
	E.Register("TestService", "PLAYER_FLAGS_CHANGED", function(_, unit)
		seen = seen + 1
		assert(unit == "player", "arguments still reach the handler")
	end)
	env.FireEvent("PLAYER_FLAGS_CHANGED", "player")
	assert(seen == 1, "the next frame still gets the event")
	assert(K.ErrorCount() == errorsBefore + 1, "an event handler error is counted")
	assert(tostring(env._errors[#env._errors]):find("handler broke", 1, true), "an event handler error goes to the error handler")

	-- A module may register only while it is on.
	Raises(function()
		E.Register("UnitFrames", "PLAYER_TARGET_CHANGED", function() end)
	end, "UnitFrames is off", "Register for a module that is off")
	Raises(function() E.Register("TestService", "BAG_UPDATE", nil) end, "function", "Register without a function")
end

-- Modules: registration --------------------------------------------------------------------------

do
	local _, K = CoreEnv.New()
	local M = K.Modules
	Raises(function() M.Register(Module("NotAModule")) end, "unknown key NotAModule", "an unknown module name")
	Raises(function() M.Register({ name = "UnitFrames", Disable = function() end }) end, "Enable", "a module without Enable")
	Raises(function() M.Register({ name = "UnitFrames", Enable = function() end }) end, "Disable", "a module without Disable")
	Raises(function()
		M.Register(Module("UnitFrames", { defaults = { enabled = true } }))
	end, "defaults.enabled", "a module whose default switch differs from Features")
	M.Register(Module("UnitFrames"))
	Raises(function() M.Register(Module("UnitFrames")) end, "already registered", "a second registration")
	assert(M.IsEnabled("UnitFrames") == false, "a module is off before the saved data loads")
	Raises(function() M.IsEnabled("Nope") end, "unknown key Nope", "IsEnabled on an unknown module")
end

-- Modules: off by default, free while off ---------------------------------------------------------

do
	local env, K = CoreEnv.New()
	local def = Module("UnitFrames", { defaults = { width = 220 } })
	K.Modules.Register(def)
	local frames = #env._frames
	CoreEnv.Boot(env)
	assert(#def.calls == 0, "code defaults leave every module off, so Enable never runs")
	assert(K.Modules.IsEnabled("UnitFrames") == false and K.Modules.IsRunning("UnitFrames") == false)
	assert(#env._frames == frames, "a module that is off costs no frames")
	assert(K.Store.Module("UnitFrames").width == 220, "its defaults are still readable")
end

-- Modules: a saved switch starts the module at PLAYER_LOGIN, even in combat ----------------------

do
	local saved = { version = 1, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {} }
	local env, K = CoreEnv.New({ saved = saved })
	local events = {}
	local def = Module("UnitFrames", {
		onEnable = function()
			K.Events.Register("UnitFrames", "PLAYER_TARGET_CHANGED", function(event)
				events[#events + 1] = event
			end)
			K.Callbacks.Register("ThemeChanged", "UnitFrames", function()
				events[#events + 1] = "ThemeChanged"
			end)
		end,
	})
	local other = Module("ActionBars")
	K.Modules.Register(def)
	K.Modules.Register(other)
	CoreEnv.LoadSaved(env)
	assert(#def.calls == 0, "modules do not start at ADDON_LOADED")
	env._combat = true
	CoreEnv.Login(env)
	assert(def.calls[1] == "Enable" and #def.calls == 1, "an enabled module starts at PLAYER_LOGIN, even in combat")
	assert(#other.calls == 0, "a module that is off stays off")
	assert(K.Modules.IsEnabled("UnitFrames") and K.Modules.IsRunning("UnitFrames"))
	env._combat = false

	env.FireEvent("PLAYER_TARGET_CHANGED")
	K.Callbacks.Fire("ThemeChanged")
	assert(#events == 2, "a running module gets its events and callbacks")

	-- Disable unregisters the module's events and its callbacks, even ones the module forgot.
	K.Modules.Disable("UnitFrames")
	assert(def.calls[2] == "Disable", "Disable runs the module's Disable")
	env.FireEvent("PLAYER_TARGET_CHANGED")
	K.Callbacks.Fire("ThemeChanged")
	assert(#events == 2, "a disabled module gets no events and no callbacks")
	assert(K.Modules.IsEnabled("UnitFrames") == false and K.Store.Module("UnitFrames").enabled == false)
	assert(not CoreEnv.Printed(env, "reload"), "a replace module needs no reload")

	-- Enable out of combat runs now; in combat it waits for PLAYER_REGEN_ENABLED.
	K.Modules.Enable("UnitFrames")
	assert(def.calls[3] == "Enable", "Enable out of combat runs at once")
	env.SetCombat(true)
	K.Modules.Disable("UnitFrames")
	assert(#def.calls == 3, "Disable in combat waits")
	assert(K.Modules.IsEnabled("UnitFrames") == false, "the switch changes at once")
	K.Modules.Enable("UnitFrames")
	env.SetCombat(false)
	assert(#def.calls == 3, "a switch that ends where it started does nothing after combat")
	env.SetCombat(true)
	K.Modules.Disable("UnitFrames")
	env.SetCombat(false)
	assert(def.calls[4] == "Disable" and #def.calls == 4, "the queued change runs after combat")
end

-- Modules: the game's real order: module addons load after the core's ADDON_LOADED ----------------

do
	local saved = { version = 1, profiles = { Default = { UnitFrames = { enabled = true } } } }
	local env, K = CoreEnv.New({ saved = saved })
	CoreEnv.LoadSaved(env)
	local def = Module("UnitFrames")
	K.Modules.Register(def)
	local other = Module("ActionBars")
	K.Modules.Register(other)
	K.Modules.Enable("ActionBars")
	assert(#def.calls == 0 and #other.calls == 0, "a module that registers or is switched on before PLAYER_LOGIN waits for it")
	CoreEnv.Login(env)
	assert(def.calls[1] == "Enable" and other.calls[1] == "Enable", "both start at PLAYER_LOGIN")
	assert(#def.calls == 1 and #other.calls == 1, "each starts once")
end

-- Modules: a reskin module asks for a reload when it is turned off -------------------------------

do
	local saved = { version = 1, profiles = { Default = { Skins = { enabled = true } } } }
	local env, K = CoreEnv.New({ saved = saved })
	local def = Module("Skins", { reskin = true })
	K.Modules.Register(def)
	local asked
	K.Callbacks.Register("ReloadNeeded", "test", function(_, name)
		asked = name
	end)
	CoreEnv.Boot(env)
	assert(K.Modules.NeedsReload() == false)
	K.Modules.Disable("Skins")
	assert(def.calls[2] == "Disable", "a reskin module still runs Disable")
	assert(K.Modules.NeedsReload() == true and asked == "Skins", "turning off a reskin module asks for a reload")
	assert(CoreEnv.Printed(env, "/reload"), "the player is told to type /reload")
end

-- Modules: a failing Enable is reported and does not stop the others ------------------------------

do
	local saved = { version = 1, profiles = { Default = { UnitFrames = { enabled = true }, ActionBars = { enabled = true } } } }
	local env, K = CoreEnv.New({ saved = saved })
	local bad = Module("UnitFrames", {
		onEnable = function()
			K.Events.Register("UnitFrames", "PLAYER_TARGET_CHANGED", function() end)
			error("enable failed")
		end,
	})
	local good = Module("ActionBars")
	K.Modules.Register(bad)
	K.Modules.Register(good)
	CoreEnv.Boot(env)
	assert(#env._errors == 1 and tostring(env._errors[1]):find("enable failed", 1, true), "the error is reported")
	assert(good.calls[1] == "Enable", "the next module still starts")
	assert(K.Modules.IsRunning("UnitFrames") == false, "a module whose Enable failed is not running")
	assert(Count(bad.calls, "Disable") == 1, "a failed Enable is cleaned up with Disable")
	for _, frame in ipairs(env._frames) do
		assert(not frame:IsEventRegistered("PLAYER_TARGET_CHANGED"), "a failed module keeps no events")
	end
end

-- Modules: a module that registers after login, and profile changes ------------------------------

do
	local saved = { version = 1, profiles = { Default = {}, Raid = { ActionBars = { enabled = true } } } }
	local env, K = CoreEnv.New({ saved = saved })
	CoreEnv.Boot(env)
	local def = Module("ActionBars")
	K.Modules.Register(def)
	assert(#def.calls == 0, "a module that registers after login stays off when its switch is off")
	K.Store.SetProfile("Raid")
	assert(def.calls[1] == "Enable", "switching to a profile that turns a module on starts it")
	K.Store.SetProfile("Default")
	assert(def.calls[2] == "Disable", "switching back stops it")
	K.Store.SetProfile("Raid")
	local late = Module("Chat")
	K.Store.Profile().Chat.enabled = true
	K.Modules.Register(late)
	assert(late.calls[1] == "Enable", "a module that registers after login starts at once when its switch is on")
	local names = K.Modules.List()
	-- The core's Icons service registers the Icons module at load, before any module addon.
	assert(names[1] == "Icons" and names[2] == "ActionBars" and names[3] == "Chat" and #names == 3, "List gives the registered modules in order")
end

print("lifecycle ok")
