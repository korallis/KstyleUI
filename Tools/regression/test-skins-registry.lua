-- test-skins-registry.lua: KstyleUI_Skins registers one switch per window and skins each window only after its Blizzard addon loads and the window first shows.
local S = dofile("Tools/regression/skins_env.lua")
local CoreEnv = S.W.CoreEnv
local Raises = CoreEnv.Raises

-- Fake(env, key, fields) -> a skin definition whose Apply records its calls in def.applied.
local function Fake(key, fields)
	local def = { key = key, label = "Window " .. key, help = "Restyles the " .. key .. " window.", applied = 0 }
	for k, v in pairs(fields or {}) do
		def[k] = v
	end
	local apply = def.onApply
	def.onApply = nil
	function def.Apply(self)
		assert(self == def, "Apply runs with the definition as self")
		def.applied = def.applied + 1
		if apply then
			apply(self)
		end
	end
	return def
end

-- At load the module only registers: no frames, a switch per window, off by default ----------------

do
	local frames
	local env, K, ns = S.New({
		before = function(env, _, ns)
			frames = #env._frames
			ns.Skins.Add(Fake("testA", { addon = "Blizzard_TestA", frame = "TestAFrame" }))
		end,
	})
	assert(#env._frames == frames, "Module.lua created frames at load")
	assert(K.Modules.IsEnabled("Skins") == false, "Skins is off by default")
	assert(not K.Modules.IsRunning("Skins"), "Skins does not run until it is enabled")
	local defaults = K.Store.Defaults("Skins")
	assert(defaults.enabled == false)
	assert(type(defaults.testA) == "table" and defaults.testA.enabled == true, "each window's skin is on once the module is on")
	local row = K.Options.Row("Skins", "testA.enabled")
	assert(row and row.type == "toggle" and row.label == "Window testA", "one toggle per window, labelled with the window's name")
	local keys = {}
	for _, def in ipairs(ns.Skins.List()) do
		keys[#keys + 1] = def.key
		assert(K.Options.Row("Skins", def.key .. ".enabled"), def.key .. " has no switch in the settings")
	end
	assert(keys[#keys] == "testA", "skins keep the order Skins.xml loads them in")
	assert(type(K.Options.Preview("Skins")) == "function", "the module has a live preview")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Nothing runs for a window whose Blizzard addon never loads ----------------------------------------

do
	local def = Fake("lazy", { addon = "Blizzard_Lazy", frame = "LazyFrame" })
	local env, K = S.New({ before = function(_, _, ns) ns.Skins.Add(def) end })
	K.Modules.Enable("Skins")
	assert(K.Modules.IsRunning("Skins"), "Enable runs")
	assert(def.applied == 0, "the window's addon has not loaded")
	S.LoadAddOn(env, "Blizzard_Other")
	assert(def.applied == 0, "another addon loading changes nothing")
	local B = S.Blizzard(env)
	local window = B.frame("Frame", nil, "LazyFrame")
	window:Hide()
	S.LoadAddOn(env, "Blizzard_Lazy")
	assert(def.applied == 0, "the window has not opened yet")
	S.Show(window)
	assert(def.applied == 1, "the first show skins the window")
	window:Hide()
	S.Show(window)
	assert(def.applied == 1, "a skin is applied once")
	assert(S.Logged(env, "lazy: applied"), "the devlog records the skin")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A window that is already loaded and open is skinned when the module starts ---------------------------

do
	local def = Fake("open", { addon = "Blizzard_Open", frame = "OpenFrame" })
	local env, K = S.New({
		loaded = { Blizzard_Open = true },
		before = function(env, _, ns)
			S.Blizzard(env).frame("Frame", nil, "OpenFrame")
			ns.Skins.Add(def)
		end,
	})
	K.Modules.Enable("Skins")
	assert(def.applied == 1, "a shown window is skinned at once")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A skin with no addon waits only for its window, and one with no frame applies when its addon loads -----

do
	local base = Fake("base", { frame = "BaseFrame" })
	local noFrame = Fake("noframe", { addon = "Blizzard_NoFrame" })
	local env, K = S.New({
		before = function(env, _, ns)
			S.Blizzard(env).frame("Frame", nil, "BaseFrame"):Hide()
			ns.Skins.Add(base)
			ns.Skins.Add(noFrame)
		end,
	})
	K.Modules.Enable("Skins")
	assert(base.applied == 0 and noFrame.applied == 0)
	S.Show(env.BaseFrame)
	assert(base.applied == 1, "a skin with no addon arms at once and applies on first show")
	S.LoadAddOn(env, "Blizzard_NoFrame")
	assert(noFrame.applied == 1, "a skin with no frame applies when its addon loads")
end

-- Without C_AddOns, a window whose frame exists counts as loaded ------------------------------------------

do
	local def = Fake("bare", { addon = "Blizzard_Bare", frame = "BareFrame" })
	local env, K = S.New({
		loaded = false,
		before = function(env, _, ns)
			S.Blizzard(env).frame("Frame", nil, "BareFrame")
			ns.Skins.Add(def)
		end,
	})
	assert(env.C_AddOns == nil)
	K.Modules.Enable("Skins")
	assert(def.applied == 1, "the frame exists, so its addon has loaded")
end

-- A window whose switch is off is never skinned, and switching it on arms it -------------------------

do
	local def = Fake("switch", { addon = "Blizzard_Switch", frame = "SwitchFrame" })
	local env, K = S.New({ loaded = { Blizzard_Switch = true }, before = function(env, _, ns)
		S.Blizzard(env).frame("Frame", nil, "SwitchFrame")
		ns.Skins.Add(def)
	end })
	K.Options.Write("Skins", "switch.enabled", false)
	K.Modules.Enable("Skins")
	assert(def.applied == 0, "a window whose switch is off is left alone")
	S.Show(env.SwitchFrame)
	assert(def.applied == 0, "showing it changes nothing")
	K.Options.Write("Skins", "switch.enabled", true)
	assert(def.applied == 1, "switching the window on skins it while the module runs")
	K.Options.Write("Skins", "switch.enabled", false)
	assert(K.Widgets.DialogHost():IsShown(), "switching a skinned window off asks for a reload")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A profile that switches off an already skinned window asks for a reload ------------------------------

do
	local def = Fake("profiled", { frame = "ProfiledFrame" })
	local env, K = S.New({ before = function(env, _, ns)
		S.Blizzard(env).frame("Frame", nil, "ProfiledFrame")
		ns.Skins.Add(def)
	end })
	K.Modules.Enable("Skins")
	assert(def.applied == 1)
	K.Store.CopyProfile(K.Store.ProfileName(), "Other")
	K.Store.SetProfile("Other")
	assert(not K.Widgets.DialogHost():IsShown(), "a profile that keeps the window on asks for nothing")
	K.Store.Module("Skins").profiled.enabled = false
	K.Store.CopyProfile("Other", "Third")
	K.Store.SetProfile("Third")
	assert(K.Modules.IsRunning("Skins"), "the module still runs on the new profile")
	assert(K.Widgets.DialogHost():IsShown(), "the new profile switches the skinned window off, so a reload is needed")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A failing skin is reported and the rest still apply ---------------------------------------------------

do
	local bad = Fake("bad", { onApply = function() error("broken skin") end })
	local good = Fake("good")
	local env, K = S.New({ before = function(_, _, ns)
		ns.Skins.Add(bad)
		ns.Skins.Add(good)
	end })
	K.Modules.Enable("Skins")
	assert(bad.applied == 1 and good.applied == 1, "both skins ran")
	assert(K.ErrorCount() >= 1, "the error was reported")
	assert(S.Logged(env, "bad: Apply failed"), "the devlog records the failure")
	assert(K.Modules.IsRunning("Skins"), "one failing skin does not stop the module")
end

-- /kstyle test reports each window: applied, waiting for its addon or window, switched off, or failed -------------

do
	local bad = Fake("broken", { onApply = function() error("broken skin") end })
	local shown = Fake("shown")
	local closed = Fake("closed", { frame = "ClosedFrame" })
	local lazy = Fake("ondemand", { addon = "Blizzard_OnDemand" })
	local off = Fake("off")
	local env, K = S.New({ before = function(env, _, ns)
		S.Blizzard(env).frame("Frame", nil, "ClosedFrame"):Hide()
		for _, def in ipairs({ bad, shown, closed, lazy, off }) do
			ns.Skins.Add(def)
		end
	end })
	K.Options.Write("Skins", "off.enabled", false)
	K.Modules.Enable("Skins")
	K.Modules.Enable("Skins")
	K.DevTest.Run()
	local lines = {}
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "DevTest" and tostring(entry.message):find("skin windows", 1, true) then
			lines[#lines + 1] = entry.message
		end
	end
	assert(#lines == 1, "one line for the skins, however often the module started, got " .. #lines)
	local line = lines[1]
	assert(line:find("^FAIL"), "a failed skin fails the check: " .. line)
	assert(line:find("failed: broken", 1, true) and line:find("shown", 1, true), line)
	assert(line:find("waiting: ", 1, true) and line:find("closed, ondemand", 1, true) and line:find("off: off", 1, true), line)
end

-- Combat holds a skin until it ends ---------------------------------------------------------------------

do
	local def = Fake("combat", { frame = "CombatFrame" })
	local env, K = S.New({ before = function(env, _, ns)
		S.Blizzard(env).frame("Frame", nil, "CombatFrame"):Hide()
		ns.Skins.Add(def)
	end })
	K.Modules.Enable("Skins")
	env.SetCombat(true)
	S.Show(env.CombatFrame)
	assert(def.applied == 0, "no skin is applied in combat")
	env.SetCombat(false)
	assert(def.applied == 1, "the skin applies when combat ends")
end

-- Disable stops arming; skins already applied ask for a reload ----------------------------------------

do
	local early = Fake("early", { frame = "EarlyFrame" })
	local late = Fake("late", { addon = "Blizzard_Late", frame = "LateFrame" })
	local env, K = S.New({ before = function(env, _, ns)
		S.Blizzard(env).frame("Frame", nil, "EarlyFrame")
		ns.Skins.Add(early)
		ns.Skins.Add(late)
	end })
	K.Modules.Enable("Skins")
	assert(early.applied == 1)
	K.Modules.Disable("Skins")
	assert(not K.Modules.IsRunning("Skins"))
	assert(K.Modules.NeedsReload(), "a reskin module asks for a reload when turned off")
	S.Blizzard(env).frame("Frame", nil, "LateFrame")
	S.LoadAddOn(env, "Blizzard_Late")
	assert(late.applied == 0, "nothing arms after Disable")
	K.Modules.Enable("Skins")
	assert(late.applied == 1, "enabling again arms the waiting skin")
	assert(early.applied == 1, "a skin is never applied twice")
end

-- Add checks its definition, and closes once the module registers ----------------------------------------

do
	local _, _, ns = S.New({ before = function(_, _, ns)
		Raises(function() ns.Skins.Add("character") end, "a table", "a definition that is not a table")
		Raises(function() ns.Skins.Add(Fake("Bad Key")) end, "key", "a key that is not a lower-camel name")
		Raises(function() ns.Skins.Add(Fake("text")) end, "reserved", "a key the shared settings use")
		Raises(function() ns.Skins.Add(Fake("nolabel", { label = "" })) end, "label", "a skin without a label")
		Raises(function() ns.Skins.Add(Fake("longhelp", { help = string.rep("x", 100) })) end, "help", "help over 100 characters")
		local noApply = Fake("noapply")
		noApply.Apply = nil
		Raises(function() ns.Skins.Add(noApply) end, "Apply", "a skin without Apply")
		Raises(function() ns.Skins.Add(Fake("addon", { addon = 5 })) end, "addon", "an addon that is not a name")
		Raises(function() ns.Skins.Add(Fake("own", { defaults = { enabled = false } })) end, "switch", "a skin that sets its own switch")
		Raises(function() ns.Skins.Add(Fake("norows", { rows = { {} } })) end, "defaults", "rows without defaults")
		ns.Skins.Add(Fake("twice"))
		Raises(function() ns.Skins.Add(Fake("twice")) end, "already", "a key added twice")
	end })
	Raises(function() ns.Skins.Add(Fake("tooLate")) end, "Skins.xml", "a skin added after the module registered")
end

-- A bad extra row stops the module from loading, with the row's key in the error ----------------------------

do
	Raises(function()
		S.New({ before = function(_, _, ns)
			ns.Skins.Add(Fake("rows", { defaults = { size = 1 }, rows = { { type = "slider", key = "size", label = "Size", help = "Size.", min = 2, max = 3, step = 1 } } }))
		end })
	end, "rows.size", "a slider default outside its range")
end

-- A skin's own settings live under its key, and its rows show only while its window is switched on ----------

do
	local def = Fake("extra", {
		defaults = { borders = true },
		rows = { { type = "toggle", key = "borders", label = "Borders", help = "Draws borders." } },
	})
	local _, K, ns = S.New({ before = function(_, _, ns) ns.Skins.Add(def) end })
	local row = K.Options.Row("Skins", "extra.borders")
	assert(row and row.type == "toggle", "the extra row is keyed under the skin")
	assert(K.Store.Defaults("Skins").extra.borders == true)
	assert(ns.Skins.Setting("extra", "borders") == true, "Setting reads the skin's value")
	K.Options.Write("Skins", "extra.enabled", false)
	assert(row.showWhen(K.Store.Module("Skins")) == false, "hidden while the window is off")
	assert(ns.Skins.Setting("extra", "nope") == nil)
end

-- An applied skin hears its own settings change, and a profile change -----------------------------------

do
	local heard = {}
	local def = Fake("hears", {
		defaults = { borders = true },
		rows = { { type = "toggle", key = "borders", label = "Borders", help = "Draws borders." } },
	})
	function def.OnSetting(self, field, value)
		assert(self == def)
		heard[#heard + 1] = { field = field, value = value }
	end
	local _, K = S.New({ before = function(_, _, ns) ns.Skins.Add(def) end })
	K.Options.Write("Skins", "hears.borders", false)
	assert(#heard == 0, "a skin that has not applied hears nothing")
	K.Modules.Enable("Skins")
	K.Options.Write("Skins", "hears.borders", true)
	assert(#heard == 1 and heard[1].field == "borders" and heard[1].value == true, "the field without the skin's key, and the value")
	K.Options.Write("Skins", "text.size", 1.1)
	assert(#heard == 1, "shared look settings are not the skin's own")
	K.Store.CopyProfile(K.Store.ProfileName(), "Another")
	K.Store.SetProfile("Another")
	assert(#heard == 2 and heard[2].field == nil, "a profile change tells the skin every setting may have changed")
end

print("skins registry ok")
