-- test-store-tray.lua: migration 26 moves every saved place still at its pre-tray default (bars 1 and 2, the pet and stance bars, the data strip and the lifted centre stack, bar 3 included) onto the new defaults, keeps a custom place, and drops the old tray sizes and the pet and stance rows.
local C = dofile("Tools/regression/core_env.lua")
local env, K = C.New({ saved = {
	version = 25,
	profiles = {
		Default = { ActionBars = { bar1 = { size = 36.7, spacing = 4.6 }, bar2 = { size = 36.7, spacing = 4.6, showEmpty = true }, pet = { rows = 2 }, stance = { rows = 2, growth = "RIGHTUP" } } },
		Healer = { Layout = { preset = "Healer" } },
		Custom = { ActionBars = { bar1 = { size = 40, spacing = 6 } } },
	},
	layouts = {
		Default = {
			["actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = 54 },
			["actionbars.bar2"] = { anchor = "BOTTOM", x = 0, y = 95.3 },
			["actionbars.bar3"] = { anchor = "BOTTOMLEFT", x = 17, y = 431.5 },
			["databars.xp"] = { anchor = "BOTTOM", x = 0, y = 36.5 },
			["unitframes.player"] = { anchor = "BOTTOM", x = 0, y = 138, width = 501 },
			["unitframes.castbar.player"] = { anchor = "BOTTOM", x = 0, y = 385.5 },
		},
		Healer = {},
		Custom = {
			["actionbars.bar1"] = { anchor = "BOTTOM", x = 40, y = 54 },
			["unitframes.player"] = { anchor = "TOPLEFT", x = 20, y = -400 },
		},
	},
} })
local Layouts
do
	local probe, PK = C.New()
	C.Boot(probe)
	Layouts = PK.Setup.Layouts
	local healer = Layouts.Get("Healer")["groupframes.party"]
	env.KstyleUIDB.layouts.Healer["groupframes.party"] = { anchor = healer.anchor, x = healer.x, y = healer.y - Layouts.TRAY_LIFT }
end
C.Boot(env)
local db = env.KstyleUIDB
assert(db.version == K.Store.DB_VERSION and K.ErrorCount() == 0, "the migration finishes without errors")
local default = db.layouts.Default
for _, key in ipairs({ "actionbars.bar1", "actionbars.bar2", "actionbars.bar3", "databars.xp", "unitframes.castbar.player" }) do
	assert(default[key] == nil, key .. " at its old default follows the new one")
end
local player = default["unitframes.player"]
assert(player.anchor == nil and player.x == nil and player.y == nil and player.width == 501, "the player follows the lift and keeps its custom width")
assert(db.layouts.Healer["groupframes.party"] == nil, "the Healer party at its old default follows the lift")
local custom = db.layouts.Custom
assert(custom["actionbars.bar1"].x == 40 and custom["actionbars.bar1"].y == 54, "a custom bar 1 place survives")
assert(custom["unitframes.player"].anchor == "TOPLEFT" and custom["unitframes.player"].y == -400, "a custom player place survives")
local bars = db.profiles.Default.ActionBars
assert(next(bars.bar1) == nil and bars.bar2.size == nil and bars.bar2.spacing == nil and bars.bar2.showEmpty == true, "the old tray sizes reset, other settings stay")
assert(bars.pet.rows == nil and bars.stance.rows == nil and bars.stance.growth == "RIGHTUP", "the old two-row pet and stance folds reset")
assert(db.profiles.Custom.ActionBars.bar1.size == 40 and db.profiles.Custom.ActionBars.bar1.spacing == 6, "a custom bar size survives")
print("store tray migration ok")
