-- test-store-caith-rows.lua: only a player-positioned crest fan opts an old profile out of the new aura rows.
local C = dofile("Tools/regression/core_env.lua")
local env, K = C.New({ saved = {
	version = 41, characters = {}, account = {}, devlog = {},
	profiles = { Default = {}, Moved = {}, Scaled = {}, Chosen = { UnitFrames = { auraLayout = "rows" } } },
	layouts = {
		Default = { ["medallions:cooldowns.essential"] = { anchor = "BOTTOM", x = -321, y = 234 } },
		Moved = { ["medallions:unitframes.crestDebuffs"] = { anchor = "BOTTOM", x = 60, y = 380, scale = 0.7 } },
		Scaled = { ["medallions:unitframes.crestDebuffs"] = { scale = 0.8 } },
		Chosen = { ["unitframes.crestDebuffs"] = { x = 40, y = 500 } },
	},
} })
C.Boot(env)
local db = env.KstyleUIDB
assert(db.version == K.Store.DB_VERSION, "the next migration completes")
assert(not db.profiles.Default.UnitFrames or db.profiles.Default.UnitFrames.auraLayout ~= "fan", "existing unmoved profiles get rows")
assert(db.profiles.Moved.UnitFrames.auraLayout == "fan", "retain a deliberately moved fan")
assert(not db.profiles.Scaled.UnitFrames or db.profiles.Scaled.UnitFrames.auraLayout ~= "fan", "scale alone did not move the fan")
assert(db.profiles.Chosen.UnitFrames.auraLayout == "rows", "an explicit new layout choice wins")
assert(db.layouts.Default["medallions:cooldowns.essential"].x == -321, "saved cooldowns never move")
local moved = db.layouts.Moved["medallions:unitframes.crestDebuffs"]
assert(moved.x == 60 and moved.y == 380 and moved.scale == 0.7, "keep the fan's complete saved placement")
assert(#env._errors == 0, tostring(env._errors[1]))
print("caith migration ok: rows by default, moved fan retained, all positions intact")
