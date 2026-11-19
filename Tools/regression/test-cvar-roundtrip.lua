-- test-cvar-roundtrip.lua: G4 drives every CVar-writing module and setup, then checks that disabling it and reloading gives every recorded CVar back to the player.
local Core = dofile("Tools/regression/core_env.lua")
local MODULES = { "Chat", "CombatText", "Meters", "Nameplates", "QoL" }
local FIXTURES = {}
for _, module in ipairs(MODULES) do FIXTURES[module] = dofile("Tools/regression/" .. module:lower() .. "_env.lua") end
local ORIGINAL = {
	showTimestamps = "%I:%M ", enableFloatingCombatText = "1",
	floatingCombatTextCombatDamage_v2 = "1", floatingCombatTextCombatHealing_v2 = "1",
	floatingCombatTextPetMeleeDamage_v2 = "1", floatingCombatTextPetSpellDamage_v2 = "1",
	damageMeterEnabled = "0", cameraDistanceMaxZoomFactor = "1.3", nameplateShowSelf = "1",
	nameplateMaxDistance = "55", nameplateMaxVerticalDistance = "15", nameplateSelectedScale = "1.4",
	nameplateMinScale = "0.7", nameplateMaxScale = "1.1", nameplateSize = "4", nameplateStackingTypes = "6",
}

local function Copy(source)
	local result = {}
	for name, value in pairs(source) do result[name] = value end
	return result
end

local function Install(env, values, writes)
	env._cvars = values
	env.C_CVar = {
		GetCVar = function(name) return values[name] end,
		GetCVarInfo = function(name)
			if values[name] then return values[name], "0", false, name ~= "damageMeterEnabled", false, false, false end
		end,
		SetCVar = function(name, value)
			assert(not env._combat, "CVar writes must wait for combat to end")
			assert(ORIGINAL[name], "add a player value for the new CVar " .. name)
			if env._refused == name then return false end
			values[name], writes[name] = tostring(value), tostring(value)
			env.FireEvent("CVAR_UPDATE", name, values[name])
			return true
		end,
	}
	env.C_CVar.SetCVarBitfield = function(name, index, enabled)
		local bit = 2 ^ (index - 1)
		local current = tonumber(values[name])
		local present = math.floor(current / bit) % 2 == 1
		return env.C_CVar.SetCVar(name, current + (present == enabled and 0 or (enabled and bit or -bit)))
	end
	env.C_AddOns = env.C_AddOns or {}
	env.C_AddOns.DoesAddOnExist = function() return false end
end

local function Reload(env, values, writes)
	Core.Logout(env)
	local loaded, K = Core.New({ saved = env.KstyleUIDB, setup = function(e) Install(e, values, writes) end })
	Core.LoadSaved(loaded)
	loaded.FireEvent("VARIABLES_LOADED")
	Core.Login(loaded)
	loaded.RunTimers()
	assert(#loaded._errors == 0, tostring(loaded._errors[1]))
	return loaded, K
end

local function Check(module, values, writes)
	assert(next(writes), module .. " must exercise its CVar writer")
	for name, written in pairs(writes) do
		assert(values[name] == ORIGINAL[name], name .. " stayed at " .. tostring(values[name]) .. " after " .. module
			.. " turned off and the UI reloaded (was " .. ORIGINAL[name] .. "); keep the player's value in a Core/CVars.lua memory (wrote " .. written .. ")")
	end
end

local function Start(module)
	local fixture = FIXTURES[module]
	local values, writes = Copy(ORIGINAL), {}
	local env, K, ns = fixture.New({ enable = false, setup = function(e) Install(e, values, writes) end })
	env.FireEvent("VARIABLES_LOADED")
	K.Modules.Enable(module)
	local choice = K.Setup.NewChoice()
	choice.modules = { [module] = true }
	assert(K.Setup.Apply(choice), "setup applies with " .. module)
	if module == "Nameplates" then
		K.Options.Write(module, "shrinkDistant", true)
		K.Options.Write(module, "cvars.enabled", true)
	elseif module == "QoL" then
		K.Options.Write(module, "maxCamera", true)
	elseif module == "Meters" then
		K.Options.Write(module, "damage.mode", "skin")
	end
	env.RunTimers()
	assert(K.Modules.IsRunning(module), module .. " must run")
	local own = ({ Chat = "showTimestamps", CombatText = "enableFloatingCombatText", Meters = "damageMeterEnabled",
		Nameplates = "nameplateMaxDistance", QoL = "cameraDistanceMaxZoomFactor" })[module]
	assert(writes[own] and values[own] ~= ORIGINAL[own], module .. " must change " .. own)
	assert(#env._errors == 0, tostring(env._errors[1]))
	return env, K, ns, values, writes
end

local failures = {}
for _, original in ipairs({ "0", "1" }) do
	local ok, err = pcall(function()
		local values, writes = Copy(ORIGINAL), {}
		values.nameplateShowSelf = original
		local env, K = Core.New({ setup = function(e) Install(e, values, writes) end })
		Core.LoadSaved(env)
		Core.Login(env)
		assert(K.Store.Defaults("Nameplates") == nil, "Nameplates is not loaded")
		assert(K.Setup.Apply(K.Setup.NewChoice()), "setup applies without Nameplates")
		env.RunTimers()
		assert(writes.nameplateShowSelf == nil and values.nameplateShowSelf == original,
			"setup must leave the player's personal-resource CVar alone when Nameplates is not loaded")
		Reload(env, values, writes)
		assert(writes.nameplateShowSelf == nil and values.nameplateShowSelf == original, "reload leaves the unowned CVar alone too")
	end)
	if not ok then failures[#failures + 1] = tostring(err) end
end
for _, module in ipairs(MODULES) do
	for _, offAtReload in ipairs({ false, true }) do
		local ok, err = pcall(function()
			local env, K, _, values, writes = Start(module)
			local recorded = Copy(writes)
			if offAtReload then
				K.Store.Module(module).enabled = false
			else
				K.Modules.Disable(module)
				env.RunTimers()
			end
			Reload(env, values, {})
			Check(module, values, recorded)
		end)
		if not ok then failures[#failures + 1] = module .. " (off at reload: " .. tostring(offAtReload) .. "): " .. tostring(err) end
	end
end
assert(#failures == 0, table.concat(failures, "\n"))

-- Management off restores the custom values, including untouched bits, while personal-resource control stays active.
do
	local env, K, _, values = Start("Nameplates")
	K.Options.Write("Nameplates", "cvars.enabled", false)
	for name in pairs(ORIGINAL) do
		if name:match("^nameplate") and name ~= "nameplateShowSelf" then
			assert(values[name] == ORIGINAL[name], "management off must restore the player's " .. name)
		end
	end
	assert(values.nameplateShowSelf == "0", "management off leaves the separate personal-resource choice")
	K.Modules.Disable("Nameplates")
	assert(values.nameplateShowSelf == "1", "module off gives the personal-resource CVar back too")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The scale hold takes the player's custom values through multiple handoffs and an off-at-reload.
do
	local env, K, _, values, writes = Start("Nameplates")
	for _ = 1, 2 do
		K.Options.Write("Nameplates", "shrinkDistant", false)
		assert(values.nameplateMinScale == "1", "the scale hold runs")
		K.Options.Write("Nameplates", "shrinkDistant", true)
		assert(values.nameplateMinScale == "0.8", "management resumes after the hold")
	end
	K.Options.Write("Nameplates", "shrinkDistant", false)
	K.Options.Write("Nameplates", "cvars.enabled", false)
	K.Store.Module("Nameplates").enabled = false
	Reload(env, values, {})
	Check("Nameplates handoff", values, writes)
end

-- Another addon or the player wins; refused restores retain the memory until the next login.
do
	local env, K, _, values = Start("Nameplates")
	values.nameplateMaxDistance = "33"
	values.nameplateMinScale = "0.9"
	K.Options.Write("Nameplates", "shrinkDistant", false)
	env._refused = "nameplateSize"
	K.Options.Write("Nameplates", "cvars.enabled", false)
	K.Modules.Disable("Nameplates")
	local records = K.Store.Account().nameplateCVars[K.Store.CharacterKey()]
	assert(values.nameplateMaxDistance == "33" and records.nameplateMaxDistance == nil, "leave another writer's value alone")
	assert(records.nameplateSize.original == "4", "a refused restore keeps the player's value")
	Reload(env, values, {})
	assert(values.nameplateSize == "4" and values.nameplateMaxDistance == "33", "reload retries only the held value")
	assert(values.nameplateMinScale == "0.9", "the scale hold returns another writer's value when it took over after management")
end

-- Reload while the module runs but management is off must use its saved records, not session state.
do
	local env, _, _, values, writes = Start("Nameplates")
	Core.Logout(env)
	local loaded, running = FIXTURES.Nameplates.New({ saved = env.KstyleUIDB, enable = false,
		setup = function(e) Install(e, values, {}) end })
	assert(values.nameplateMaxDistance == "40", "management stays active across reload")
	running.Store.Module("Nameplates").cvars.enabled = false
	Core.Logout(loaded)
	loaded, running = FIXTURES.Nameplates.New({ saved = loaded.KstyleUIDB, enable = false,
		setup = function(e) Install(e, values, {}) end })
	assert(running.Modules.IsRunning("Nameplates"), "the module still runs after reload")
	assert(values.nameplateMaxDistance == "55" and values.nameplateStackingTypes == "6", "management off at reload restores saved values")
	running.Modules.Disable("Nameplates")
	Check("Nameplates management off at reload", values, writes)
	assert(#loaded._errors == 0, tostring(loaded._errors[1]))
end
print("test-cvar-roundtrip: ok")
