-- test-store-groupframes.lua: KSTY-57's migration 29: the sizes the old defaults and the DPS, Tank and Healer layouts saved (the 77-unit raid tile, 40 and 46-unit rows, the 8-unit party gap) follow the KSTY-47 mock-ups' rows, a Healer profile's party, raid, boss frames and combat text still at the old Healer places follow the new ones, the DPS places, and every other saved size and place stays the player's.
local C = dofile("Tools/regression/core_env.lua")
local penv, PK = C.New()
C.Boot(penv)
local old = PK.Setup.Layouts.HealerMoves()
local raidOld, bossOld = old["groupframes.raid"], old["unitframes.boss"]
local function at(place)
	return { anchor = place[1], x = place[2], y = place[3] }
end
local env, K = C.New({ saved = {
	version = 26,
	profiles = {
		DPS = { GroupFrames = { party = { height = 40, spacing = 8 }, raid = { width = 77, height = 40, groupsPerRow = 4 } }, Layout = { preset = "DPS" } },
		Healer = { GroupFrames = { party = { height = 46, spacing = 8 }, raid = { width = 77, height = 46 } }, Layout = { preset = "Healer" },
			UnitFrames = { boss = { auraPosition = "RIGHT", auraGrowth = "RIGHT_DOWN", growth = "DOWN" } } },
		Moved = { Layout = { preset = "Healer" }, UnitFrames = { boss = { auraPosition = "RIGHT", auraGrowth = "RIGHT_DOWN" } } },
		Custom = { GroupFrames = { party = { height = 52, spacing = 6, width = 300 }, raid = { width = 90, height = 44 } } },
		Bare = { GroupFrames = { enabled = true } },
		Odd = { GroupFrames = { party = "broken", raid = { width = "77" } } },
	},
	layouts = {
		DPS = { ["unitframes.boss"] = at(bossOld) },
		Healer = { ["groupframes.raid"] = at(raidOld), ["unitframes.boss"] = at(bossOld), ["groupframes.party"] = at(old["groupframes.party"]), ["combattext.player"] = at(old["combattext.player"]) },
		Moved = { ["groupframes.raid"] = { anchor = "CENTER", x = 40, y = 12 }, ["unitframes.boss"] = { anchor = "TOPLEFT", x = 60, y = -90 } },
	},
} })
C.Boot(env)
local profiles = env.KstyleUIDB.profiles
local dps, healer, custom = profiles.DPS.GroupFrames, profiles.Healer.GroupFrames, profiles.Custom.GroupFrames
assert(dps.party.height == nil and dps.party.spacing == nil, "the DPS party follows the new 39-unit rows and 13-unit gap")
assert(dps.raid.width == nil and dps.raid.height == nil, "the DPS raid follows the new 116 by 36 row")
assert(dps.raid.groupsPerRow == 4, "the layout's four groups a row stay")
assert(healer.party.height == 43 and healer.party.spacing == nil, "the Healer party takes the Healer layout's new 43-unit rows")
assert(healer.raid.height == nil and healer.raid.width == nil, "the Healer raid takes the new 36-unit rows at the new width")
assert(custom.party.height == 52 and custom.party.spacing == 6 and custom.party.width == 300, "a player's own party sizes stay")
assert(custom.raid.width == 90 and custom.raid.height == 44, "and their raid sizes")
assert(profiles.Bare.GroupFrames.enabled == true and profiles.Odd.GroupFrames.party == "broken" and profiles.Odd.GroupFrames.raid.width == "77", "odd saved data is left alone")
local layouts = env.KstyleUIDB.layouts
assert(layouts.Healer["groupframes.raid"] == nil and layouts.Healer["unitframes.boss"] == nil, "a Healer profile's raid and boss frames at the old Healer places follow the new defaults")
assert(layouts.Healer["groupframes.party"] == nil and layouts.Healer["combattext.player"] == nil, "and so do its party and combat text")
assert(layouts.Moved["groupframes.raid"].anchor == "CENTER" and layouts.Moved["unitframes.boss"].x == 60, "places the player chose stay")
assert(layouts.DPS["unitframes.boss"].anchor == bossOld[1], "another layout's entry at the same spot is left alone")
local healerBoss, movedBoss = profiles.Healer.UnitFrames.boss, profiles.Moved.UnitFrames.boss
assert(healerBoss.auraPosition == "LEFT" and healerBoss.auraGrowth == "LEFT_DOWN" and healerBoss.growth == "UP", "boss frames moved to the DPS column hang their debuffs left, towards the centre, and grow up from their foot")
assert(movedBoss.auraPosition == "RIGHT" and movedBoss.auraGrowth == "RIGHT_DOWN", "boss frames the player placed keep their debuffs' side")
assert(env.KstyleUIDB.version == K.Store.DB_VERSION and K.ErrorCount() == 0, "the migration finishes without errors")
print("store groupframes migration ok")
