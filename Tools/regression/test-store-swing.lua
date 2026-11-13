-- test-store-swing.lua: KSTY-60 item 13 moves the Frames swing timer off the player cast bar into its own slot 8 units above the class resource (migration 33): a saved swing at the old default, from before or after the tray lift, follows the new slot; a moved or resized swing and the Orbs slot are kept.
local C = dofile("Tools/regression/core_env.lua")
local probe, PK = C.New()
C.Boot(probe)
local Layouts = PK.Setup.Layouts
local LIFT = Layouts.TRAY_LIFT
local now = Layouts.Get("DPS")["meters.swing"]
assert(now.anchor == "BOTTOM" and now.x == 0 and math.abs(now.y - (421 + 14 + 8 + LIFT)) < 1e-6, "the Frames swing slot is 8 above the class resource, got " .. tostring(now.y))
assert(#probe._errors == 0, tostring(probe._errors[1]))

local function old(y)
	return { anchor = "BOTTOM", x = 0, y = y }
end
local custom = { anchor = "BOTTOM", x = 120, y = 300 }
local env, K = C.New({ saved = {
	version = 30,
	profiles = { Default = {}, Tank = { Layout = { preset = "Tank" } }, Custom = {}, Resized = {}, Orbs = {} },
	layouts = {
		Default = { ["meters.swing"] = old(376.5 + LIFT) },
		Tank = { ["meters.swing"] = old(376.5 + LIFT) },
		Custom = { ["meters.swing"] = C.DeepCopy(custom) },
		Resized = { ["meters.swing"] = { anchor = "BOTTOM", x = 0, y = 376.5 + LIFT, width = 300, height = 10 } },
		Orbs = { ["Orbs:meters.swing"] = { anchor = "BOTTOM", x = 0, y = 333 } },
	},
} })
C.Boot(env)
local layouts = env.KstyleUIDB.layouts
assert(layouts.Default["meters.swing"] == nil and layouts.Tank["meters.swing"] == nil, "an untouched swing at the old default follows the new slot in every preset")
assert(C.DeepEqual(layouts.Custom["meters.swing"], custom), "a moved swing stays where its player put it")
local resized = layouts.Resized["meters.swing"]
assert(resized.anchor == nil and resized.x == nil and resized.y == nil and resized.width == 300 and resized.height == 10, "a resized swing keeps its size and takes the new slot")
assert(C.DeepEqual(layouts.Orbs["Orbs:meters.swing"], { anchor = "BOTTOM", x = 0, y = 333 }), "the Orbs swing is not touched")
assert(env.KstyleUIDB.version == K.Store.DB_VERSION and K.ErrorCount() == 0, "the migration finishes without errors")

local env25, K25 = C.New({ saved = {
	version = 25,
	profiles = { Default = {} },
	layouts = { Default = { ["meters.swing"] = old(376.5) } },
} })
C.Boot(env25)
assert(env25.KstyleUIDB.layouts.Default["meters.swing"] == nil, "a swing saved before the tray lift also follows the new slot")
assert(K25.ErrorCount() == 0, "the older migration path finishes without errors")
print("store swing migration ok")
