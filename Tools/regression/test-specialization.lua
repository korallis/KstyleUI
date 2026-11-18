-- test-specialization.lua: profiles follow specs or assigned roles, settle after combat, and preserve character assignments.
local C = dofile("Tools/regression/core_env.lua")

local function setup(env)
	env._spec, env._role = 1, "NONE"
	env.GetNumSpecializations = function() return 2 end
	env.C_SpecializationInfo = {
		GetSpecialization = function() return env._spec end,
		GetSpecializationInfo = function(index)
			if index == 1 then return 71, "Arms", nil, nil, "DAMAGER" end
			if index == 2 then return 73, "Protection", nil, nil, "TANK" end
		end,
	}
	env.UnitGroupRolesAssigned = function() return env._role end
end

local env, K = C.New({ setup = setup })
C.Boot(env)
local S = K.Specialization
assert(S.Enabled(), "specialization profiles default on")
assert(#S.Choices() == 2 and S.Choices()[2].label == "Protection")
assert(S.Profile("spec:71") == "Default" and S.Profile("spec:73") == "Default", "every spec starts on the active profile")
K.Store.SetProfile("Manual")
env._spec = 2
env.FireEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
assert(K.Store.ProfileName() == "Manual" and S.Profile("spec:71") == "Manual", "defaults follow the current profile until a spec is explicitly assigned")
K.Store.SetProfile("Default")
assert(K.Store.CreateProfile("Tank"))
env._spec = 2
env.FireEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
assert(K.Store.ProfileName() == "Default", "the default mapping changes nothing")
env._spec = 1
env.FireEvent("ACTIVE_TALENT_GROUP_CHANGED")
assert(S.Assign("spec:73", "Tank"))
assert(K.Store.ProfileName() == "Default", "assigning another spec leaves this one alone")
local changed = 0
K.Callbacks.Register("ProfileChanged", "test", function() changed = changed + 1 end)
env.SetCombat(true)
env._spec = 2
env.FireEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
env.FireEvent("ACTIVE_TALENT_GROUP_CHANGED")
assert(K.Store.ProfileName() == "Default" and S.Role() == "DAMAGER", "combat retains the applied profile and role")
assert(K.Combat.Pending() == 1, "duplicate changes share one queued settlement")
env.SetCombat(false)
assert(K.Store.ProfileName() == "Tank" and S.Role() == "TANK" and changed == 1, "combat end uses the existing ProfileChanged path once")
env._role = "HEALER"
env.FireEvent("PLAYER_ROLES_ASSIGNED")
assert(S.Role() == "HEALER", "assigned role overrides spec role")
assert(K.Store.RenameProfile("Tank", "Defence"))
assert(S.Profile("spec:73") == "Defence", "renaming preserves spec mappings")
S.SetEnabled(false)
env._spec = 1
env.FireEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
assert(K.Store.ProfileName() == "Defence", "off stops automatic switching")
S.SetEnabled(true)
assert(K.Store.ProfileName() == "Default")
assert(K.Store.DeleteProfile("Defence"))
assert(S.Profile("spec:73") == "Default", "deleting a profile redirects its assignments")
K.Store.SetProfile("Manual")
env.FireEvent("GROUP_ROSTER_UPDATE")
assert(K.Store.ProfileName() == "Manual", "roster updates do not undo a manual profile choice")
C.Logout(env)
local again, K2 = C.New({ saved = env.KstyleUIDB, setup = setup })
C.Boot(again)
assert(K2.Specialization.Profile("spec:73") == "Default", "mappings survive logout")
local export = assert(K2.Store.Export())
local payload = assert(K2.Store.Decode(export))
assert(payload.account == nil and payload.specializationProfiles == nil, "exports do not carry another character's assignments")
local alt, A = C.New({ saved = env.KstyleUIDB, setup = function(e)
	setup(e)
	e.UnitName = function() return "Alt" end
end })
C.Boot(alt)
assert(A.Specialization.Profile("spec:73") == "Default", "another character starts with its own current profile")
A.Store.CreateProfile("AltTank")
A.Specialization.Assign("spec:73", "AltTank")
assert(K2.Specialization.Profile("spec:73") == "Default", "assignments are isolated by character")
again._spec = again.Secret(2)
again.FireEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
assert(K2.Specialization.Role() == "DAMAGER", "secret spec indices never reach the info API")
again._spec = 2
again.C_SpecializationInfo.GetSpecializationInfo = function() return again.Secret(73), "Protection", nil, nil, again.Secret("TANK") end
again.FireEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
assert(K2.Specialization.Role() == "DAMAGER", "secret spec IDs and roles are ignored")

local fallback, F = C.New({ setup = function(e)
	e.UnitGroupRolesAssigned = function() return e._role end
end })
C.Boot(fallback)
assert(#F.Specialization.Choices() == 3 and F.Specialization.Choices()[1].key == "role:TANK", "missing specs show role rows")
F.Store.CreateProfile("Tank")
F.Specialization.Assign("role:TANK", "Tank")
fallback._role = "TANK"
fallback.FireEvent("PLAYER_ROLES_ASSIGNED")
assert(F.Store.ProfileName() == "Tank", "classes without specs use their assigned role")
fallback._role = fallback.Secret("HEALER")
fallback.FireEvent("PLAYER_ROLES_ASSIGNED")
assert(F.Store.ProfileName() == "Tank" and F.Specialization.Role() == "DAMAGER", "secret roles cannot select a profile")
assert(K.ErrorCount() == 0 and K2.ErrorCount() == 0 and F.ErrorCount() == 0 and A.ErrorCount() == 0)
print("specialization profiles ok")
