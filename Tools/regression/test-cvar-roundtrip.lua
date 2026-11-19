-- test-cvar-roundtrip.lua: G4 drives every CVar-writing module and setup, then checks that disabling it and reloading gives every recorded CVar back to the player.
local Core = dofile("Tools/regression/core_env.lua")
local MODULES = { "Chat", "CombatText", "Meters", "Nameplates", "QoL" }
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
	local fixture = dofile("Tools/regression/" .. module:lower() .. "_env.lua")
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
	end
	env.RunTimers()
	assert(K.Modules.IsRunning(module), module .. " must run")
	assert(#env._errors == 0, tostring(env._errors[1]))
	return env, K, ns, values, writes
end

local failures = {}
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
print("test-cvar-roundtrip: ok")
