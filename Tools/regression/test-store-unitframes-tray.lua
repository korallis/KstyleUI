-- test-store-unitframes-tray.lua: migration 27 moves a saved player or target still at its place under the tray (staging after #324) onto the new places above the tray's top edge, and keeps a custom place.
local C = dofile("Tools/regression/core_env.lua")
local probe, PK = C.New()
C.Boot(probe)
local Layouts = PK.Setup.Layouts
local old = Layouts.UnitFrameMoves()
local env, K = C.New({ saved = {
	version = 26,
	profiles = { Default = {}, Custom = {} },
	layouts = {
		Default = {
			["unitframes.player"] = { anchor = "BOTTOM", x = 0, y = old["unitframes.player"][3], width = 501 },
			["unitframes.target"] = { anchor = "BOTTOM", x = 0, y = old["unitframes.target"][3] },
		},
		Custom = {
			["unitframes.player"] = { anchor = "BOTTOM", x = 0, y = 300 },
		},
	},
} })
C.Boot(env)
local db = env.KstyleUIDB
assert(db.version == K.Store.DB_VERSION and K.ErrorCount() == 0, "the migration finishes without errors")
local player = db.layouts.Default["unitframes.player"]
assert(player.anchor == nil and player.y == nil and player.width == 501, "the player at its old place follows the new one and keeps its custom width")
assert(db.layouts.Default["unitframes.target"] == nil, "the target at its old place follows the new one")
assert(db.layouts.Custom["unitframes.player"].y == 300, "a custom player place survives")
local new = Layouts.Default("unitframes.player")
assert(new.y >= Layouts.TRAY_TOP + 6, "the player's element stands above the tray's top edge: " .. new.y .. " against " .. Layouts.TRAY_TOP)
assert(Layouts.Default("unitframes.target").y > new.y, "the target stays above the player")
print("store unit frames tray migration ok")
