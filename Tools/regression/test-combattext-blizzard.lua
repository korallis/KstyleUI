-- test-combattext-blizzard.lua: KstyleUI_CombatText hides Blizzard's own combat text through the game's CVars while it runs, and puts the player's values back when it stops.
local CT = dofile("Tools/regression/combattext_env.lua")

local SELF, TARGETS = CT.SELF, CT.TARGETS
local DAMAGE, HEALING = TARGETS[1], TARGETS[2]

local failures = {}
local function Case(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. ": " .. tostring(err)
	end
end

local function Targets(env, value)
	for _, name in ipairs(TARGETS) do
		if env._cvars[name] ~= value then
			return false
		end
	end
	return true
end

local function Logged(env, text)
	local n = 0
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		n = n + (entry.message:find(text, 1, true) and 1 or 0)
	end
	return n
end

-- Hiding(values) is saved data that hides Blizzard's numbers over targets too. The default keeps them, since
-- they are the only numbers that show just the player's own hits; the cases below test the hide path.
local function Hiding(values)
	values = values or {}
	if values.blizzardTargets == nil then
		values.blizzardTargets = "hide"
	end
	return CT.Saved(values)
end

local function On(opts)
	opts = opts or {}
	opts.saved = opts.saved or Hiding()
	local env, K = CT.New(opts)
	CT.Enable(env, K)
	return env, K
end

local function Off(env, K)
	K.Modules.Disable("CombatText")
	env.RunTimers()
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Relog(env, player, setup) logs out, then in as player with the saved data and every CVar at "0".
local function Relog(env, player, setup)
	CT.CoreEnv.Logout(env)
	return CT.New({ saved = env.KstyleUIDB, player = player, setup = function(e)
		for name in pairs(e._cvars) do
			e._cvars[name] = "0"
		end
		if setup then
			setup(e)
		end
	end })
end

Case("on hides the text over you and the numbers over targets; off brings the player's values back", function()
	local env, K = On({ setup = function(e) e._cvars[HEALING] = "0" end })
	assert(env._cvars[SELF] == "0" and Targets(env, "0"), "on: Blizzard's combat text is off")
	Off(env, K)
	assert(env._cvars[SELF] == "1" and env._cvars[DAMAGE] == "1", "off: the player's values are back")
	assert(env._cvars[HEALING] == "0", "a CVar the player had off stays off")
end)

Case("Keep leaves a CVar alone, and a changed setting hides or restores", function()
	local env, K = On({ saved = Hiding({ blizzardSelf = "keep" }) })
	assert(env._cvars[SELF] == "1" and Targets(env, "0"), "Keep leaves the text over you on")
	for _, write in ipairs(env._cvarWrites) do
		assert(write.name ~= SELF, "Keep never writes the CVar")
	end
	K.Options.Write("CombatText", "blizzardTargets", "keep")
	K.Options.Write("CombatText", "blizzardSelf", "hide")
	env.RunTimers()
	assert(Targets(env, "1") and env._cvars[SELF] == "0", "Keep puts the numbers back; Hide turns the text off")
end)

Case("after a reload nothing is written again, and the player's values still come back", function()
	local env, K = Relog((On()))
	assert(K.Modules.IsRunning("CombatText") and #env._cvarWrites == 0, "an unchanged CVar is not written again")
	Off(env, K)
	assert(env._cvars[SELF] == "1" and Targets(env, "1"), "the player's values survive the reload")
end)

for _, info in ipairs({ true, false }) do
	Case("a CVar saved for every character is remembered once, one saved per character per character (GetCVarInfo " .. tostring(info) .. ")", function()
		local function setup(e)
			e.C_CVar.GetCVarInfo = info and e.C_CVar.GetCVarInfo or nil
		end
		local env, K = Relog(On({ setup = setup }), "Alt", setup)
		assert(K.Modules.IsRunning("CombatText"), "the module starts on the alt")
		Off(env, K)
		assert(Targets(env, "1"), "the numbers over targets come back as the first character had them")
		assert(env._cvars[SELF] == "0", "the alt's own text over you stays as the alt had it")
	end)
end

Case("a change made outside Blizzard's Settings panel is put back; one made in it becomes KstyleUI's setting", function()
	local env, K = On()
	local shown = false
	env.SettingsPanel = { IsShown = function() return shown end }
	env.C_CVar.SetCVar(SELF, "1")
	env.C_CVar.SetCVar(DAMAGE, "1")
	env.RunTimers()
	assert(env._cvars[SELF] == "0" and env._cvars[DAMAGE] == "0", "KstyleUI's values are put back")
	assert(K.Options.Read("CombatText", "blizzardSelf") == "hide" and K.Options.Read("CombatText", "blizzardTargets") == "hide", "the settings stay")
	shown = true
	env.C_CVar.SetCVar(DAMAGE, "1")
	env.RunTimers()
	assert(K.Options.Read("CombatText", "blizzardTargets") == "keep", "Blizzard's choice is KstyleUI's setting now")
	assert(Targets(env, "1") and env._cvars[SELF] == "0", "every number over targets is back; the text over you is not")
	env.C_CVar.SetCVar(SELF, "1")
	env.RunTimers()
	assert(K.Options.Read("CombatText", "blizzardSelf") == "keep" and env._cvars[SELF] == "1", "the text over you follows too")
	assert(#env._errors == 0, tostring(env._errors[1]))
end)

Case("CVars the game loads late are hidden again", function()
	local env, K = On()
	env._cvars[SELF] = "1"
	env.FireEvent("VARIABLES_LOADED")
	env.RunTimers()
	assert(env._cvars[SELF] == "0", "hidden again after the late load")
	Off(env, K)
	assert(env._cvars[SELF] == "1", "off: the late value comes back")
end)

Case("in combat the CVars wait for combat to end", function()
	local env, K = On()
	env.SetCombat(true)
	K.Options.Write("CombatText", "blizzardSelf", "keep")
	env.C_CVar.SetCVar(DAMAGE, "1")
	local writes = #env._cvarWrites
	env.RunTimers()
	assert(#env._cvarWrites == writes, "no CVar write in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(env._cvars[SELF] == "1" and env._cvars[DAMAGE] == "0", "written when combat ends")
end)

Case("a client that refuses a CVar keeps the player's value and logs once", function()
	local env, K = On({ setup = function(e) e._secureCVars[DAMAGE] = true end })
	assert(env._cvars[DAMAGE] == "1" and env._cvars[SELF] == "0" and env._cvars[HEALING] == "0", "only the refused CVar keeps its value")
	K.Options.Write("CombatText", "blizzardTargets", "keep")
	K.Options.Write("CombatText", "blizzardTargets", "hide")
	env.RunTimers()
	assert(Logged(env, DAMAGE) == 1, "the refusal is logged once, got " .. Logged(env, DAMAGE))
	Off(env, K)
	assert(env._cvars[DAMAGE] == "1" and env._cvars[SELF] == "1" and env._cvars[HEALING] == "1", "off: nothing stays hidden")
end)

Case("a refused restore keeps the player's value for the next try", function()
	local env, K = On()
	env._secureCVars[DAMAGE] = true
	K.Options.Write("CombatText", "blizzardTargets", "keep")
	env.RunTimers()
	assert(env._cvars[DAMAGE] == "0" and env._cvars[HEALING] == "1", "only the refused CVar stays hidden")
	env._secureCVars[DAMAGE] = nil
	K.Options.Write("CombatText", "blizzardTargets", "hide")
	K.Options.Write("CombatText", "blizzardTargets", "keep")
	env.RunTimers()
	assert(env._cvars[DAMAGE] == "1", "the next try puts the player's value back")
end)

Case("a client without C_CVar.SetCVar keeps the player's values and logs once", function()
	local env, K = On({ cvar = { noSetCVar = true } })
	K.Options.Write("CombatText", "blizzardTargets", "keep")
	K.Options.Write("CombatText", "blizzardTargets", "hide")
	env.RunTimers()
	assert(env._cvars[SELF] == "1" and Targets(env, "1"), "Blizzard's text stays as the player has it")
	assert(Logged(env, "SetCVar") == 1, "the missing API is logged once, got " .. Logged(env, "SetCVar"))
	Off(env, K)
end)

Case("by default the text over you hides, Blizzard's own-hit numbers over targets stay, and so do restored ones", function()
	local env, K = CT.New({ saved = CT.Saved({}) })
	CT.Enable(env, K)
	assert(K.Options.Read("CombatText", "blizzardTargets") == "keep", "Blizzard's numbers over targets are kept by default")
	assert(K.Options.Read("CombatText", "units.nameplate") == false, "KstyleUI's nameplate numbers, every player's hits, are off by default")
	assert(env._cvars[SELF] == "0" and Targets(env, "1"), "only the text over you is hidden")
	for _, write in ipairs(env._cvarWrites) do
		assert(write.name ~= DAMAGE and write.name ~= HEALING, "the target CVars are never written")
	end
	Off(env, K)
end)

Case("numbers over targets that an earlier default hid come back under the new one", function()
	local env = On()
	assert(Targets(env, "0"), "hidden under the old default")
	CT.CoreEnv.Logout(env)
	local profile = env.KstyleUIDB.profiles.Default.CombatText
	profile.blizzardTargets = nil
	local again, K2 = CT.New({ saved = env.KstyleUIDB, setup = function(e)
		for name, value in pairs(env._cvars) do
			e._cvars[name] = value
		end
	end })
	CT.Enable(again, K2)
	assert(Targets(again, "1") and again._cvars[HEALING] == "1", "the player's numbers are back")
	Off(again, K2)
end)

local function Variables(env)
	env.FireEvent("VARIABLES_LOADED")
	env.RunTimers()
	assert(#env._errors == 0, tostring(env._errors[1]))
end

Case("an alt whose profile has the module off gets the numbers over targets back at login; the main hides them again at its own", function()
	local env = On()
	env.KstyleUIDB.profiles.Off = {}
	env.KstyleUIDB.characters["Realm-Alt"] = "Off"
	local K
	env, K = Relog(env, "Alt", function(e) e._cvars[SELF] = "1" end)
	assert(not K.Modules.IsRunning("CombatText"), "the module is off on the alt")
	Variables(env)
	assert(Targets(env, "1"), "the numbers over targets come back on the alt")
	assert(env._cvars[SELF] == "1", "the alt's own text over it is left alone")
	env, K = Relog(env, "Tester", function(e)
		for _, name in ipairs(TARGETS) do
			e._cvars[name] = "1"
		end
	end)
	Variables(env)
	assert(K.Modules.IsRunning("CombatText") and Targets(env, "0") and env._cvars[SELF] == "0", "the main hides them again")
	Off(env, K)
	assert(Targets(env, "1") and env._cvars[SELF] == "1", "and still puts the player's values back")
end)

Case("a character whose module was turned off on another character gets its own text over it back at login", function()
	local env = On()
	local K
	env, K = Relog(env, "Alt", function(e) e._cvars[SELF] = "1" end)
	assert(K.Modules.IsRunning("CombatText"), "the alt shares the profile, so the module runs")
	Off(env, K)
	assert(env._cvars[SELF] == "1" and Targets(env, "1"), "off on the alt: the alt's values are back")
	env, K = Relog(env, "Tester", function(e)
		for _, name in ipairs(TARGETS) do
			e._cvars[name] = "1"
		end
	end)
	assert(not K.Modules.IsRunning("CombatText") and env._cvars[SELF] == "0", "the main logs in with its text still hidden")
	Variables(env)
	assert(env._cvars[SELF] == "1", "the main's own text over it comes back")
	assert(Targets(env, "1"), "the numbers over targets stay as the player had them")
end)

assert(#failures == 0, #failures .. " failed:\n" .. table.concat(failures, "\n"))
print("test-combattext-blizzard: ok")
