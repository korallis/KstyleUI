-- test-store-meter-role.lua: saved profiles retain manual meters while fresh installs and new profiles follow the role.
local M = dofile("Tools/regression/meters_env.lua")
local env, K = M.New({ followRole = true, saved = {
	version = 37,
	profiles = { Default = {}, Raid = { Meters = { followRole = true, damage = { shown = false } } } },
} })
for _, name in ipairs({ "Default", "Raid" }) do
	K.Store.SetProfile(name)
	assert(K.Store.Module("Meters").followRole == false, "migration keeps existing profiles on manual meters")
end
assert(K.Store.Module("Meters").damage.shown == false, "existing manual settings survive migration")
assert(env.KstyleUIDB.version == K.Store.DB_VERSION and K.ErrorCount() == 0)
K.Store.CreateProfile("New")
K.Store.SetProfile("New")
assert(K.Store.Module("Meters").followRole == true, "new profiles keep the role-following default")
local _, fresh = M.New({ followRole = true })
assert(fresh.Store.Module("Meters").followRole == true, "fresh installs follow the role by default")
assert(fresh.ErrorCount() == 0)
print("store meter role migration ok")
