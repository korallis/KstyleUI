-- test-store-threat.lua: only the old untouched DPS/Healer threat slot follows the new combat-cluster default.
local C = dofile("Tools/regression/core_env.lua")
local old = { anchor = "BOTTOMRIGHT", x = -17, y = 17, width = 269, height = 144 }
local custom = { anchor = "TOPLEFT", x = 41, y = -87, width = 240, height = 130 }
local env, K = C.New({ saved = {
	version = 13,
	profiles = {
		Default = {}, Healer = { Layout = { preset = "Healer" } },
		Custom = {}, Partial = {}, Resized = {}, Tank = { Layout = { preset = "Tank" } },
	},
	layouts = {
		Default = { ["meters.threat"] = C.DeepCopy(old) },
		Healer = { ["meters.threat"] = C.DeepCopy(old) },
		Custom = { ["meters.threat"] = C.DeepCopy(custom) },
		Partial = { ["meters.threat"] = { x = -60 } },
		Resized = { ["meters.threat"] = { width = 310 } },
		Tank = { ["meters.threat"] = { anchor = "BOTTOM", x = 357, y = 402, width = 200, height = 112 } },
	},
} })
C.Boot(env)
local layouts = env.KstyleUIDB.layouts
assert(layouts.Default["meters.threat"] == nil and layouts.Healer["meters.threat"] == nil, "only the old untouched position and size inherit the new default")
assert(C.DeepEqual(layouts.Custom["meters.threat"], custom), "a custom position and size are preserved")
local partial = layouts.Partial["meters.threat"]
assert(partial.anchor == "BOTTOMRIGHT" and partial.x == -60 and partial.y == 17, "a partially saved custom position is completed from its old default, not the new anchor")
local resized = layouts.Resized["meters.threat"]
assert(resized.anchor == "BOTTOMRIGHT" and resized.x == -17 and resized.y == 17 and resized.width == 310, "a custom size retains its old position")
local tank = layouts.Tank["meters.threat"]
assert(tank.width == 200 and tank.x == nil and tank.y == nil and tank.anchor == nil, "the Tank entry keeps its size; migration 26 lifts its untouched default position with the tray")
assert(env.KstyleUIDB.version == K.Store.DB_VERSION and K.ErrorCount() == 0, "the migration finishes without errors")
print("store threat migration ok")
