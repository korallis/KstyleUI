-- test-store-characters.lua: Store lists each known character's profile and assigns any of them to an existing profile.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local function saved()
	return {
		version = 1,
		profiles = { Default = {}, Raid = {}, Solo = {} },
		characters = { ["Realm-Tester"] = "Default", ["Realm-Alt"] = "Solo" },
		layouts = {},
		account = {},
		devlog = {},
	}
end

local function boot(data)
	local env, K = CoreEnv.New({ saved = data })
	local changes = {}
	K.Callbacks.Register("ProfileChanged", "test", function(_, new, old)
		changes[#changes + 1] = { new, old }
	end)
	CoreEnv.Boot(env)
	return env, K, changes
end

-- Before the saved data loads, nothing is known and nothing changes -------------------------------

do
	local _, K = CoreEnv.New({ saved = saved() })
	local list = K.Store.Characters()
	assert(type(list) == "table" and next(list) == nil, "Characters is empty before the saved data loads")
	local ok, err = K.Store.AssignCharacter("Realm-Alt", "Raid")
	assert(ok == false and err:find("has not loaded", 1, true), "AssignCharacter waits for the saved data")
end

-- Characters returns a copy of every assignment ------------------------------------------------------

do
	local env, K = boot(saved())
	local list = K.Store.Characters()
	assert(list["Realm-Tester"] == "Default" and list["Realm-Alt"] == "Solo", "Characters lists each character's profile")
	list["Realm-Alt"] = "Raid"
	assert(env.KstyleUIDB.characters["Realm-Alt"] == "Solo", "Characters returns a copy")
	assert(K.Store.CharacterKey() == "Realm-Tester", "CharacterKey names the logged-in character")
end

-- Another character moves to an existing profile without touching the active one --------------------

do
	local env, K, changes = boot(saved())
	local ok, err = K.Store.AssignCharacter("Realm-Alt", "Raid")
	assert(ok == true, tostring(err))
	assert(env.KstyleUIDB.characters["Realm-Alt"] == "Raid", "the assignment is saved")
	assert(K.Store.ProfileName() == "Default", "the active profile stays")
	assert(#changes == 0, "assigning another character fires no ProfileChanged")
end

-- The logged-in character switches profile, as SetProfile does --------------------------------------

do
	local env, K, changes = boot(saved())
	assert(K.Store.AssignCharacter("Realm-Tester", "Raid") == true)
	assert(K.Store.ProfileName() == "Raid", "the active profile switches")
	assert(env.KstyleUIDB.characters["Realm-Tester"] == "Raid")
	assert(#changes == 1 and changes[1][1] == "Raid" and changes[1][2] == "Default", "ProfileChanged fires once")
end

-- Unknown characters, missing profiles and bad names are refused with a reason ----------------------

do
	local env, K, changes = boot(saved())
	local ok, err = K.Store.AssignCharacter("Realm-Nobody", "Raid")
	assert(ok == false and err:find("Realm-Nobody", 1, true), "an unknown character is refused: " .. tostring(err))
	ok, err = K.Store.AssignCharacter("Realm-Alt", "Missing")
	assert(ok == false and err == "There is no profile named Missing.", "a missing profile is refused: " .. tostring(err))
	ok = K.Store.AssignCharacter("Realm-Tester", "Missing")
	assert(ok == false and K.Store.ProfileName() == "Default", "the logged-in character is not moved to a profile that does not exist")
	ok, err = K.Store.AssignCharacter("Realm-Alt", "")
	assert(ok == false and type(err) == "string", "an empty name is refused")
	assert(env.KstyleUIDB.characters["Realm-Alt"] == "Solo", "a refused assignment changes nothing")
	assert(#changes == 0)
end

print("store characters ok")
