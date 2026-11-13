-- test-store.lua: KstyleUIDB layout, defaults, profiles, migrations, and export and import with strict rejection of bad strings.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Raises, Module, DeepCopy, DeepEqual = CoreEnv.Raises, CoreEnv.Module, CoreEnv.DeepCopy, CoreEnv.DeepEqual

local function check(cond, message)
	if not cond then
		error(message, 2)
	end
end

-- A module with flat, nested and list defaults, and an options schema that bounds two settings.
local function registerUnitFrames(K)
	K.Modules.Register(Module("UnitFrames", {
		defaults = {
			portraits = true,
			width = 220,
			texture = "Flat",
			player = { scale = 1, healthText = { size = 11, outline = "NONE" } },
			hidden = {},
			order = { "player", "target" },
		},
	}))
	K.Options.Register("UnitFrames", {
		{ type = "toggle", key = "portraits", label = "Portraits", help = "Show portraits on the frames." },
		{ type = "slider", key = "width", label = "Width", help = "Frame width.", min = 100, max = 400, step = 1 },
		{ type = "dropdown", key = "player.healthText.outline", label = "Outline", help = "Text outline.", options = {
			{ value = "NONE", label = "None" }, { value = "OUTLINE", label = "Outline" },
		} },
	})
end

local function boot(opts)
	local env, K = CoreEnv.New(opts)
	registerUnitFrames(K)
	CoreEnv.Boot(env)
	return env, K
end

-- A fresh install ------------------------------------------------------------------------------

do
	local env, K = boot()
	local db = env.KstyleUIDB
	check(type(db) == "table", "ADDON_LOADED creates KstyleUIDB")
	check(db.version == K.Store.DB_VERSION and K.Store.DB_VERSION == 27, "a fresh KstyleUIDB starts at the code's version")
	for _, field in ipairs({ "profiles", "characters", "layouts", "account", "devlog" }) do
		check(type(db[field]) == "table", "KstyleUIDB." .. field .. " must be a table")
	end
	check(db.characters["Realm-Tester"] == "Default", "the character is assigned the Default profile")
	check(K.Store.ProfileName() == "Default")
	check(K.Store.Profile() == db.profiles.Default, "Profile() is the active profile")

	local uf = K.Store.Module("UnitFrames")
	check(uf == K.Store.Profile().UnitFrames, "Module(name) is that module's table in the profile")
	check(uf.enabled == false and uf.portraits == true and uf.width == 220, "defaults read through")
	check(uf.player.healthText.size == 11, "nested defaults read through")
	check(#uf.order == 2 and uf.order[2] == "target", "list defaults read as lists")
	check(K.Store.Module("Bags").enabled == false, "a module whose addon is not loaded still has its switch")
	Raises(function() K.Store.Module("Bagz") end, "unknown settings section Bagz", "Module on an unknown name")
	check(type(K.Store.Layout()) == "table" and K.Store.Layout() == db.layouts.Default, "Layout() is the active profile's layout table")
	check(type(K.Store.Account()) == "table" and K.Store.Account() == db.account, "Account() is the account table")
end

-- Only values that differ from the defaults are saved -----------------------------------------------

do
	local env, K = boot()
	local uf = K.Store.Module("UnitFrames")
	uf.width = 260
	uf.portraits = true -- the default: not saved
	uf.player.healthText.outline = "OUTLINE"
	uf.order = { "target" } -- a list is saved whole
	uf.hidden.focus = true
	K.Store.Layout().player = { anchor = "BOTTOM", x = -262, y = 214 }
	CoreEnv.Logout(env)
	local saved = env.KstyleUIDB.profiles.Default
	local same, where = DeepEqual(saved, {
		UnitFrames = { width = 260, player = { healthText = { outline = "OUTLINE" } }, order = { "target" }, hidden = { focus = true } },
	})
	check(same, "PLAYER_LOGOUT saves only changed values: " .. tostring(where))
	check(env.KstyleUIDB.layouts.Default.player.x == -262, "layouts are saved as they are")
	check(uf.portraits == true and uf.player.scale == 1, "the live table keeps its defaults after logout, for later logout handlers")

	-- The next session reads the saved values over the defaults.
	local env2, K2 = boot({ saved = env.KstyleUIDB })
	local uf2 = K2.Store.Module("UnitFrames")
	check(uf2.width == 260 and uf2.portraits == true and uf2.player.healthText.outline == "OUTLINE" and uf2.player.healthText.size == 11)
	check(#uf2.order == 1 and uf2.order[1] == "target", "a saved list replaces the default list")
	check(uf2.hidden.focus == true)
	check(env2.KstyleUIDB.version == K2.Store.DB_VERSION, "the next session keeps the code's version")
end

-- Damaged saved data is repaired, not trusted -----------------------------------------------------

do
	local saved = {
		version = 1,
		profiles = { Default = { UnitFrames = { width = "wide", player = 5, order = "player", portraits = false } }, Broken = "x" },
		characters = "nope",
		layouts = 7,
		devlog = false,
	}
	local env, K = boot({ saved = saved })
	local db = env.KstyleUIDB
	check(type(db.characters) == "table" and type(db.layouts) == "table" and type(db.account) == "table" and type(db.devlog) == "table", "fields of the wrong type are replaced")
	check(db.profiles.Broken == nil, "a profile that is not a table is dropped")
	local uf = K.Store.Module("UnitFrames")
	check(uf.width == 220, "a value of the wrong type falls back to its default")
	check(type(uf.player) == "table" and uf.player.scale == 1, "a table setting of the wrong type falls back to its default")
	check(type(uf.order) == "table" and uf.order[1] == "player" and #uf.order == 2, "a list setting of the wrong type falls back to its default list")
	uf.order[1] = "focus"
	check(K.Store.Defaults("UnitFrames").order[1] == "player", "a default list is copied, so changing the setting never changes the default")
	check(uf.portraits == false, "valid values survive")
end

-- Profiles: per character, create, copy, rename, delete, reset -------------------------------------

do
	local env, K = boot()
	local S = K.Store
	local changes = {}
	K.Callbacks.Register("ProfileChanged", "test", function(_, new, old)
		changes[#changes + 1] = tostring(new) .. "<" .. tostring(old)
	end)

	check(S.CreateProfile("Raid") == true)
	local ok, err = S.CreateProfile("Raid")
	check(ok == false and err:find("already exists", 1, true), "creating a duplicate fails: " .. tostring(err))
	for _, bad in ipairs({ "", "   ", string.rep("x", 49), "Bad|cffname", "Tab\tname", 5 }) do
		ok, err = S.CreateProfile(bad)
		check(ok == false and type(err) == "string", "a bad profile name is refused: " .. tostring(bad))
	end
	check(S.CreateProfile("  Trimmed  ") == true and S.ListProfiles()[3] == "Trimmed", "names are trimmed")
	local list = S.ListProfiles()
	check(#list == 3 and list[1] == "Default" and list[2] == "Raid", "ListProfiles is sorted")

	S.Module("UnitFrames").width = 300
	check(S.SetProfile("Raid") == true)
	check(S.ProfileName() == "Raid" and env.KstyleUIDB.characters["Realm-Tester"] == "Raid", "SetProfile assigns the character")
	check(S.Module("UnitFrames").width == 220, "the new profile has its own values")
	check(changes[1] == "Raid<Default", "SetProfile fires ProfileChanged(new, old)")
	check(S.SetProfile("Raid") == true and #changes == 1, "setting the active profile again fires nothing")

	-- Copy Default into Raid, the active profile.
	check(S.CopyProfile("Default", "Raid") == true)
	check(S.Module("UnitFrames").width == 300, "CopyProfile copies the settings")
	check(#changes == 2, "copying into the active profile fires ProfileChanged")
	S.Module("UnitFrames").width = 310
	check(env.KstyleUIDB.profiles.Default.UnitFrames.width == 300, "a copy does not share tables with its source")
	ok, err = S.CopyProfile("Nope", "Raid")
	check(ok == false and err:find("Nope", 1, true), "copying a missing profile fails")

	-- Rename the active profile; the character follows it.
	check(S.RenameProfile("Raid", "Dungeon") == true)
	check(S.ProfileName() == "Dungeon" and env.KstyleUIDB.characters["Realm-Tester"] == "Dungeon")
	check(env.KstyleUIDB.profiles.Raid == nil and env.KstyleUIDB.profiles.Dungeon ~= nil)
	check(S.Module("UnitFrames").width == 310, "the renamed profile keeps its values")
	ok, err = S.RenameProfile("Dungeon", "Default")
	check(ok == false and err:find("already exists", 1, true), "renaming onto an existing name fails")

	-- Delete: never the active profile; other characters on it fall back to Default.
	env.KstyleUIDB.characters["Realm-Alt"] = "Trimmed"
	ok, err = S.DeleteProfile("Dungeon")
	check(ok == false and err:find("active", 1, true), "the active profile cannot be deleted")
	check(S.DeleteProfile("Trimmed") == true)
	check(env.KstyleUIDB.profiles.Trimmed == nil and env.KstyleUIDB.characters["Realm-Alt"] == nil, "characters on a deleted profile fall back to Default")
	ok = S.DeleteProfile("Trimmed")
	check(ok == false, "deleting a missing profile fails")

	-- Reset returns the active profile to the defaults and clears its layout.
	S.Layout().player = { anchor = "CENTER", x = 1, y = 2 }
	local before = #changes
	check(S.ResetProfile() == true)
	check(S.Module("UnitFrames").width == 220 and next(S.Layout()) == nil, "ResetProfile restores defaults and clears the layout")
	check(#changes == before + 1, "resetting the active profile fires ProfileChanged")

	-- Another character on the same saved data gets its own assignment.
	CoreEnv.Logout(env)
	local env2, K2 = boot({ saved = env.KstyleUIDB, player = "Alt" })
	check(K2.Store.ProfileName() == "Default", "a new character starts on Default")
	check(env2.KstyleUIDB.characters["Realm-Tester"] == "Dungeon", "other characters keep their profiles")
	local env3, K3 = boot({ saved = env2.KstyleUIDB })
	check(K3.Store.ProfileName() == "Dungeon", "a character gets its profile back on the next login")
	check(env3.KstyleUIDB ~= nil)
end

-- Migrations -----------------------------------------------------------------------------------

do
	local ran = {}
	local env, K = CoreEnv.New({
		saved = { version = 1, profiles = { Default = { UnitFrames = { size = 200 } } } },
	})
	K.Store.DB_VERSION = 3
	K.Store.migrations[2] = function(db)
		ran[#ran + 1] = 2
		for _, profile in pairs(db.profiles) do
			if profile.UnitFrames then
				profile.UnitFrames.width, profile.UnitFrames.size = profile.UnitFrames.size, nil
			end
		end
	end
	K.Store.migrations[3] = function(db)
		ran[#ran + 1] = 3
		check(db.version == 2, "migration 3 runs on version 2 data")
	end
	registerUnitFrames(K)
	CoreEnv.Boot(env)
	check(table.concat(ran, ",") == "2,3", "migrations run in order from the saved version, got " .. table.concat(ran, ","))
	check(env.KstyleUIDB.version == 3)
	check(K.Store.Module("UnitFrames").width == 200, "migrated values are read")

	-- Migration 3 drops the Icons and IconsColour sections the removed icon module kept, in every profile.
do
	local menv = CoreEnv.New({
		saved = { version = 2, profiles = {
			Default = { Icons = { enabled = true, set = "B", tint = "class" }, IconsColour = { enabled = false }, UnitFrames = { enabled = true } },
			Alt = { Icons = { enabled = false } },
		} },
	})
	CoreEnv.Boot(menv)
	check(menv.KstyleUIDB.version == 27, "version 2 data migrates through 3 to 12 to the current 27")
	check(menv.KstyleUIDB.profiles.Default.Icons == nil and menv.KstyleUIDB.profiles.Default.IconsColour == nil, "the Icons sections are gone")
	check(menv.KstyleUIDB.profiles.Alt.Icons == nil, "in every profile")
	check(menv.KstyleUIDB.profiles.Default.UnitFrames.enabled == true, "other sections stay")
	check(#menv._errors == 0, "the migration raises no error: " .. tostring(menv._errors[1]))
end

-- Migration 8 (owner pass 1, 2026-11-09): the Blessings card is gone, so its card section, the one-row buffs the Lumen
-- setup wrote for it and the debuffs' dispellable-first split leave every profile; a player's own other rows stay.
do
	local menv = CoreEnv.New({
		saved = { version = 7, profiles = {
			Default = { Auras = { card = { docked = true }, buffs = { rows = 1, columns = 6 }, debuffs = { dispelFirst = false, rows = 3 } } },
			Alt = { Auras = { buffs = { rows = 3 } } },
			Bare = { UnitFrames = { enabled = true } },
		} },
	})
	CoreEnv.Boot(menv)
	local auras = menv.KstyleUIDB.profiles.Default.Auras
	check(menv.KstyleUIDB.version == 27, "version 7 data migrates to 27")
	check(auras.card == nil, "the card section is gone")
	check(auras.buffs.rows == nil and auras.buffs.columns == 6, "the setup's one buff row goes; the player's columns stay")
	check(auras.debuffs.dispelFirst == nil and auras.debuffs.rows == 3, "the dispellable-first split goes; the player's debuff rows stay")
	check(menv.KstyleUIDB.profiles.Alt.Auras.buffs.rows == 3, "a player's own three rows stay")
	check(menv.KstyleUIDB.profiles.Bare.UnitFrames.enabled == true, "a profile without Auras is untouched")
	check(#menv._errors == 0, "the migration raises no error: " .. tostring(menv._errors[1]))
end

-- Migration 9 (owner, 2026-11-09: the quest card moves to the right rail): the damage and threat cards now stand on
-- the readout at the rail's foot, measured from the bottom right. Layout saves only the fields that differ from the
-- default, so a card the player moved only up or down holds a y and no anchor; read against the new bottom-right
-- default it would leave the screen; one moved to another corner holds an anchor and an x but no y. Each partial
-- entry is completed from the version-8 place (top right, 28 in, 236 down), so it stays where the player put it. Full entries, empty ones and the Tank threat card stay as they are.
do
	local menv = CoreEnv.New({
		saved = { version = 8, profiles = { Default = {}, Tank = { Layout = { preset = "Tank" } } }, layouts = {
			Default = {
				["meters.damage"] = { y = -300 },
				["meters.threat"] = { x = -60, width = 300 },
				["tooltips.anchor"] = { y = 500 },
			},
			Full = { ["meters.damage"] = { anchor = "BOTTOMLEFT", x = 40, y = 40 }, ["meters.threat"] = { anchor = "TOPLEFT", x = 28 } },
			Tank = { ["meters.threat"] = { anchor = "BOTTOM", x = 357, y = 312 }, ["meters.damage"] = { width = 300 } },
		} },
	})
	CoreEnv.Boot(menv)
	local db = menv.KstyleUIDB
	check(db.version == 27, "version 8 data migrates to 27")
	local damage, threat = db.layouts.Default["meters.damage"], db.layouts.Default["meters.threat"]
	check(damage.anchor == "TOPRIGHT" and damage.x == -28 and damage.y == -300, "a damage card moved only down keeps its place from the top right")
	check(threat.anchor == "TOPRIGHT" and threat.x == -60 and threat.y == -236 and threat.width == 300, "a threat card moved only sideways keeps its place and size")
	local tip = db.layouts.Default["tooltips.anchor"]
	check(tip.anchor == "BOTTOMRIGHT" and tip.x == -28 and tip.y == 500, "the tooltip anchor kept its corner and its own y; migration 12 completes it from the version-9 corner")
	local full = db.layouts.Full["meters.damage"]
	check(full.anchor == "BOTTOMLEFT" and full.x == 40 and full.y == 40, "a full entry stays")
	local corner = db.layouts.Full["meters.threat"]
	check(corner.anchor == "TOPLEFT" and corner.x == 28 and corner.y == -236, "a card moved to another corner keeps the y it had from the old default (codex review)")
	local tank = db.layouts.Tank
	check(tank["meters.threat"].anchor == "BOTTOM" and tank["meters.threat"].x == 357, "the Tank threat card stays")
	check(tank["meters.damage"].anchor == nil and tank["meters.damage"].x == nil and tank["meters.damage"].width == 300, "a saved size alone moves with the new default")
	check(#menv._errors == 0, "the migration raises no error: " .. tostring(menv._errors[1]))
end

-- Migration 10 (LEE-20: the picture's chat card): a saved card still at #210's 372 by 260, or Healer's 318 by 260,
-- becomes 393 by 200. A card the player resized stays.
do
	local menv = CoreEnv.New({
		saved = { version = 9, profiles = { Default = {}, Healer = { Layout = { preset = "Healer" } } }, layouts = {
			Default = { ["chat.main"] = { width = 372, height = 260, x = 28 } },
			Healer = { ["chat.main"] = { width = 318, height = 260 } },
			Custom = { ["chat.main"] = { width = 400, height = 180 } },
		} },
	})
	CoreEnv.Boot(menv)
	local db = menv.KstyleUIDB
	check(db.version == 27, "version 9 data migrates to 27")
	check(db.layouts.Default["chat.main"].width == 393 and db.layouts.Default["chat.main"].height == 186 and db.layouts.Default["chat.main"].x == 28, "the old default card takes the picture's size (186 high since migration 16) and keeps its place")
	check(db.layouts.Healer["chat.main"].width == 318 and db.layouts.Healer["chat.main"].height == 186, "Healer keeps the rail width and takes the picture's height")
	check(db.layouts.Custom["chat.main"].width == 400 and db.layouts.Custom["chat.main"].height == 180, "a resized card stays")
	check(#menv._errors == 0, "the migration raises no error: " .. tostring(menv._errors[1]))
end

-- Migration 12 (the owner's picture wins, LEE-20, 2026-11-09): the right rail moves to the picture's places and sizes.
-- A rail element the player never moved, or left at a version-9 (or version-8 card) default, follows the new default:
-- its place and its old default size are cleared, so the screenMargin token still moves it. One the player moved keeps
-- its place, completed from the version-9 default (Layout saves only the fields that differ), and its own size. Bars 4
-- and 5 draw their empty slots again: the Lumen setup wrote showEmpty false for them, which the picture reverses, so
-- that value goes; bar 6's stays.
do
	local menv, MK = CoreEnv.New({
		saved = { version = 9, profiles = {
			Default = { ActionBars = { bar4 = { showEmpty = false }, bar5 = { showEmpty = false, size = 40 }, bar6 = { showEmpty = false } } },
			Tank = { Layout = { preset = "Tank" } },
		}, layouts = {
			Default = {
				["minimap.main"] = { width = 160, height = 160 },
				["meters.damage"] = { width = 318 },
				["meters.threat"] = { anchor = "TOPRIGHT", x = -28, y = -236, width = 318, height = 144 },
				["databars.strip"] = { anchor = "BOTTOMRIGHT", x = -28, y = 28, height = 118 },
				["actionbars.bar4"] = { anchor = "RIGHT", x = -362, y = 0 },
				["actionbars.bar5"] = { y = 120 },
				["auras.buffs"] = { x = -400 },
				["tooltips.anchor"] = { anchor = "BOTTOMRIGHT", x = -28, y = 360 },
			},
			Tank = { ["meters.threat"] = { width = 318 } },
		} },
	})
	CoreEnv.Boot(menv)
	local db = menv.KstyleUIDB
	check(db.version == 27, "version 9 data migrates to 27")
	local layout = db.layouts.Default
	check(layout["minimap.main"] == nil, "the version-9 map size goes, so the map takes the picture's 188")
	check(layout["meters.damage"] == nil, "the old rail width alone goes, so the damage card takes the picture's 269 x 158")
	check(layout["meters.threat"] == nil, "a threat card at the version-8 place and old size follows the new default")
	check(layout["databars.strip"] == nil, "the readout at its old foot follows the new line, its docked height gone")
	check(layout["actionbars.bar4"] == nil, "bar 4 at #208's place moves into the rail")
	local bar5 = layout["actionbars.bar5"]
	check(bar5.anchor == "RIGHT" and bar5.x == -403 and bar5.y == 120, "bar 5 moved only up keeps its place, completed from version 9")
	local buffs = layout["auras.buffs"]
	check(buffs.anchor == "TOPRIGHT" and buffs.x == -400 and buffs.y == -28, "buffs moved only sideways keep their place")
	check(layout["tooltips.anchor"] == nil, "the tooltip anchor at its old default follows the new one")
	check(db.layouts.Tank["meters.threat"].width == 318, "the Tank threat card, in the combat cluster, is left alone")
	local bars = db.profiles.Default.ActionBars
	check(bars.bar4.showEmpty == nil and bars.bar5.showEmpty == nil and bars.bar5.size == 40, "bars 4 and 5 draw their empty slots again; the player's size stays")
	check(bars.bar6.showEmpty == false, "bar 6, off in Lumen, keeps its hidden slots")
	check(#menv._errors == 0, "the migration raises no error: " .. tostring(menv._errors[1]))
	local damage = MK.Layout.Get and MK.Layout.Get("meters.damage")
	check(damage == nil or (damage.anchor == "BOTTOMRIGHT" and damage.y == MK.Tokens.Size("screenMargin")), "the damage card resolves to the rail's foot")
end

-- Migration 16 (LEE-69, the owner's picture wins): the chat card is 186 high, the aura rows are 27.5-unit icons 3.5 apart
-- beside a 1.4-unit inset, and the rail's bars stand on the centre bars' 36.7 / 4.6 slots 1.4 inside the margin. An element
-- at its version-12 default follows the new one; one the player moved keeps its place, completed from the version-12
-- default (Layout saves only the fields that differ); a card the player resized keeps its size.
do
	local menv = CoreEnv.New({
		saved = { version = 12, profiles = {
			Default = { Auras = { buffs = { iconSize = 28, spacing = 3 }, debuffs = { iconSize = 30, spacing = 3 } }, ActionBars = { bar4 = { size = 37, spacing = 4, showEmpty = true }, bar5 = { size = 40, spacing = 4 } } },
			Healer = { Layout = { preset = "Healer" } },
		}, layouts = {
			Default = {
				["chat.main"] = { width = 393, height = 200 },
				["auras.buffs"] = { anchor = "TOPRIGHT", x = -217, y = -17, width = 307, height = 42 },
				["auras.debuffs"] = { x = -400 },
				["actionbars.bar4"] = { anchor = "BOTTOMRIGHT", x = -17, y = 203 },
				["actionbars.bar5"] = { y = 300 },
				["databars.micro"] = { anchor = "BOTTOMRIGHT", x = -152, y = 203 },
				["qol.lootfeed"] = { anchor = "BOTTOMLEFT", x = 17, y = 233 },
				["tooltips.anchor"] = { x = -90 },
			},
			Healer = { ["chat.main"] = { width = 318, height = 200 } },
			Resized = { ["chat.main"] = { width = 393, height = 240 } },
			Wide = { ["chat.main"] = { width = 400, height = 200 } },
			WidthOnly = { ["chat.main"] = { width = 400 } },
			HeightOnly = { ["chat.main"] = { height = 240 } },
			Moved = { ["chat.main"] = { x = 40 } },
			TallDps = { ["chat.main"] = { width = 318, height = 200 } },
			TallSparse = { ["chat.main"] = { width = 318 } },
			TallHigh = { ["chat.main"] = { width = 393, height = 210 } },
			TextHeight = { ["chat.main"] = { width = 393, height = "200" } },
			TallMoved = { ["chat.main"] = { width = 393, height = 210 }, ["qol.lootfeed"] = { x = 40 } },
		} },
	})
	CoreEnv.Boot(menv)
	local db = menv.KstyleUIDB
	check(db.version == 27, "version 12 data migrates to 27")
	check(db.layouts.TallDps["chat.main"].width == 318 and db.layouts.TallDps["chat.main"].height == 200, "a DPS card the player set to the Healer's old size keeps it")
	check(db.layouts.TallSparse["chat.main"].width == 318 and db.layouts.TallSparse["chat.main"].height == 200, "a DPS card narrowed to 318 keeps its 200")
	local tall = db.layouts.TallHigh["qol.lootfeed"]
	check(tall and tall.anchor == "BOTTOMLEFT" and tall.x == 17 and tall.y == 233, "a card taller than the new default keeps the loot feed where it cleared it")
	local tallMoved = db.layouts.TallMoved["qol.lootfeed"]
	check(tallMoved.anchor == "BOTTOMLEFT" and tallMoved.x == 40 and tallMoved.y == 233, "a loot feed the player moved sideways keeps its old height above the taller card")
	check(db.layouts.Default["qol.lootfeed"] == nil, "a card that takes the new default height lets the feed follow it")
	check(db.version == 27 and db.layouts.TextHeight["chat.main"].height == "200", "a saved height that is text does not stop the migration")
	local layout = db.layouts.Default
	check(layout["chat.main"].width == 393 and layout["chat.main"].height == 186, "a card at the old default height takes the picture's 186")
	check(db.layouts.Healer["chat.main"].width == 318 and db.layouts.Healer["chat.main"].height == 186, "Healer keeps its rail width and takes 186")
	check(db.layouts.Resized["chat.main"].width == 393 and db.layouts.Resized["chat.main"].height == 240, "a card the player made taller keeps its height")
	check(db.layouts.Wide["chat.main"].width == 400 and db.layouts.Wide["chat.main"].height == 200, "a card the player made wider keeps its size")
	check(db.layouts.WidthOnly["chat.main"].width == 400 and db.layouts.WidthOnly["chat.main"].height == 200, "a card the player widened, whose height was the default, keeps its 200")
	check(db.layouts.HeightOnly["chat.main"].width == 393 and db.layouts.HeightOnly["chat.main"].height == 240, "a card the player made taller keeps the default width it had")
	check(db.layouts.Moved["chat.main"].width == nil and db.layouts.Moved["chat.main"].height == nil and db.layouts.Moved["chat.main"].x == 40, "a card moved but never resized takes the new default size")
	check(layout["auras.buffs"] == nil, "a buff row at its old place and size follows the new default")
	local debuffs = layout["auras.debuffs"]
	check(debuffs.anchor == "TOPRIGHT" and debuffs.x == -400 and debuffs.y == -67, "debuffs moved only sideways keep their place, completed from version 12")
	check(layout["actionbars.bar4"] == nil and layout["databars.micro"] == nil and layout["qol.lootfeed"] == nil, "the rail's bar 4, the micro menu and the loot feed at their old places follow the new defaults")
	local bar5 = layout["actionbars.bar5"]
	check(bar5.anchor == "BOTTOMRIGHT" and bar5.x == -58 and bar5.y == 300, "bar 5 moved only up keeps its place, completed from version 12")
	local tip = layout["tooltips.anchor"]
	check(tip.anchor == "BOTTOMRIGHT" and tip.x == -90 and tip.y == 295, "the tooltip anchor moved sideways keeps its place")
	local auras = db.profiles.Default.Auras
	check(auras.buffs.iconSize == nil and auras.buffs.spacing == nil, "the old default icon size and spacing go, so the buffs take 27.5 and 3.5")
	check(auras.debuffs.iconSize == 30 and auras.debuffs.spacing == nil, "a size the player chose stays; the old default spacing goes")
	local bars = db.profiles.Default.ActionBars
	check(bars.bar4.size == nil and bars.bar4.spacing == nil and bars.bar4.showEmpty == true, "the rail bars' old 37 and 4 go, so bar 4 takes the centre bars' 36.7 and 4.6")
	check(bars.bar5.size == 40 and bars.bar5.spacing == nil, "a slot size the player chose stays")
	check(#menv._errors == 0, "the migration raises no error: " .. tostring(menv._errors[1]))
end

-- Migration 19 (KSTY-34, the owner's ruling: hide the rail's empty squares): a profile that ran Apply (it has a
-- preset, and Apply wrote showEmpty true for bars 4 and 5) loses that value, so the new default (hidden at rest)
-- applies. A profile with no preset, so no Apply behind the value, keeps the player's own choice, and so does a false.
do
	local menv = CoreEnv.New({
		saved = { version = 18, profiles = {
			Applied = { Layout = { preset = "DPS" }, ActionBars = { bar4 = { showEmpty = true, size = 40 }, bar5 = { showEmpty = true }, bar1 = { showEmpty = true } } },
			Chosen = { ActionBars = { bar4 = { showEmpty = true }, bar5 = { showEmpty = false } } },
			Quiet = { Layout = { preset = "Tank" }, ActionBars = { bar4 = { showEmpty = false } } },
			Empty = { Layout = { preset = "DPS" } },
		}, layouts = {} },
	})
	CoreEnv.Boot(menv)
	local profiles = menv.KstyleUIDB.profiles
	check(menv.KstyleUIDB.version == 27, "version 18 data migrates to 27")
	check(profiles.Applied.ActionBars.bar4.showEmpty == nil and profiles.Applied.ActionBars.bar5.showEmpty == nil, "an applied profile's showEmpty true on bars 4 and 5 goes")
	check(profiles.Applied.ActionBars.bar4.size == 40 and profiles.Applied.ActionBars.bar1.showEmpty == true, "its other settings and bar 1's empty tiles stay")
	check(profiles.Chosen.ActionBars.bar4.showEmpty == true and profiles.Chosen.ActionBars.bar5.showEmpty == false, "with no preset the player's own choice stays")
	check(profiles.Quiet.ActionBars.bar4.showEmpty == false and profiles.Empty.ActionBars == nil, "a false stays and a profile with no bar settings is not given any")
	check(#menv._errors == 0, "the migration raises no error: " .. tostring(menv._errors[1]))
end

-- The owner's own saved data (version 4, 2026-11-09): #208's older bars 2 to 6 at the top left and the damage and
-- threat cards at the old 318 width land on the picture's rail.
do
	local menv = CoreEnv.New({
		saved = { version = 4, profiles = { Default = { Auras = { enabled = true, buffs = { rows = 1 } }, ActionBars = { enabled = true, bar4 = { showEmpty = false }, bar5 = { showEmpty = false } } } }, layouts = {
			Default = {
				["actionbars.bar4"] = { y = -28, x = 526, anchor = "TOPLEFT" },
				["actionbars.bar5"] = { y = -28, x = 403, anchor = "TOPLEFT" },
				["actionbars.bar6"] = { y = -28, x = 444, anchor = "TOPLEFT" },
				["meters.threat"] = { width = 318 },
				["meters.damage"] = { width = 318 },
			},
		} },
	})
	CoreEnv.Boot(menv)
	local layout = menv.KstyleUIDB.layouts.Default
	for _, key in ipairs({ "actionbars.bar4", "actionbars.bar5", "actionbars.bar6", "meters.threat", "meters.damage" }) do
		check(layout[key] == nil, key .. " follows the picture's default, got " .. tostring(layout[key] and (tostring(layout[key].anchor) .. " " .. tostring(layout[key].x))))
	end
	check(menv.KstyleUIDB.profiles.Default.ActionBars.bar4.showEmpty == nil, "bar 4 draws every slot")
	check(#menv._errors == 0, "the migration raises no error: " .. tostring(menv._errors[1]))
end

-- Data from a newer KstyleUI is left alone; a failing migration stops and is logged.
	local env2, K2 = CoreEnv.New()
	env2.KstyleUIDB = { version = K2.Store.DB_VERSION + 1, profiles = {} }
	CoreEnv.Boot(env2)
	check(env2.KstyleUIDB.version == K2.Store.DB_VERSION + 1, "a newer version is not lowered")
	check(K2.Store.ProfileName() == "Default")
	local env3, K3 = CoreEnv.New({ saved = { version = 1, profiles = {} } })
	K3.Store.DB_VERSION = 3
	K3.Store.migrations[2] = function()
		error("migration broke")
	end
	K3.Store.migrations[3] = function()
		error("must not run after a failure")
	end
	CoreEnv.Boot(env3)
	check(env3.KstyleUIDB.version == 1, "a failed migration leaves the version where it was")
	check(#env3._errors == 1 and tostring(env3._errors[1]):find("migration broke", 1, true), "a failed migration is reported once")
end

-- Export and import round trips -------------------------------------------------------------------

local function customise(K)
	local uf = K.Store.Module("UnitFrames")
	uf.enabled = true
	uf.width = 333
	uf.player.healthText.outline = "OUTLINE"
	uf.order = { "focus", "player" }
	uf.texture = "with:colons s5:{T}|and pipes"
	K.Store.Layout().player = { anchor = "BOTTOM", x = -262.5, y = 214, scale = 1.25 }
end

local function roundTrip(exportEncoding, importEncoding, label)
	local env, K = boot({ encoding = exportEncoding })
	customise(K)
	local text = K.Store.Export()
	check(type(text) == "string" and text:sub(1, 6) == "KSUI1:", label .. ": Export returns a KSUI1: string")
	check(not text:find("%s"), label .. ": an export string has no whitespace")

	local env2, K2 = boot({ encoding = importEncoding })
	local ok, name = K2.Store.Import(text)
	check(ok == true and name == "Default (2)", label .. ": import makes a new profile with a free name, got " .. tostring(name))
	check(K2.Store.ProfileName() == name, label .. ": import switches to the imported profile")
	local uf = K2.Store.Module("UnitFrames")
	check(uf.enabled == true and uf.width == 333 and uf.player.healthText.outline == "OUTLINE" and uf.portraits == true, label .. ": settings arrive")
	check(uf.texture == "with:colons s5:{T}|and pipes", label .. ": strings arrive byte for byte")
	check(#uf.order == 2 and uf.order[1] == "focus", label .. ": lists arrive")
	check(K2.Store.Layout().player.x == -262.5 and K2.Store.Layout().player.scale == 1.25, label .. ": the layout arrives")

	-- Wrapped and padded with spaces, as a paste from chat or a forum often is.
	local wrapped = "  " .. text:sub(1, 20) .. "\n" .. text:sub(21, 40) .. " \r\n" .. text:sub(41) .. "\n"
	ok, name = K2.Store.Import(wrapped, "Mine")
	check(ok == true and name == "Mine", label .. ": whitespace in a pasted string is ignored, and a chosen name is used")
	return env, K, text, env2, K2
end

do
	local api = CoreEnv.FakeEncoding()
	local _, _, text = roundTrip(api, api, "C_EncodingUtil")
	check(api.calls.SerializeCBOR >= 1 and api.calls.CompressString >= 1 and api.calls.EncodeBase64 >= 1, "export uses C_EncodingUtil when it exists")
	check(api.calls.DeserializeCBOR >= 1 and api.calls.DecompressString >= 1 and api.calls.DecodeBase64 >= 1, "import uses C_EncodingUtil when it exists")
	for _, method in ipairs(api.methods) do
		check(method == 1, "profiles compress with zlib (Enum.CompressionMethod.Zlib = 1), got " .. tostring(method))
	end

	-- The Lua fallback works with no C_EncodingUtil, and its strings import on a client that has it.
	local _, _, luaText = roundTrip(nil, nil, "Lua fallback")
	roundTrip(nil, CoreEnv.FakeEncoding(), "Lua fallback into C_EncodingUtil")
	local plain = CoreEnv.Base64Decode(luaText:sub(7))
	check(plain and plain:sub(1, 5) == "KSL1:", "the fallback body starts with its KSL1: header")

	-- A C_EncodingUtil string cannot be read without C_EncodingUtil, and the player is told why.
	local env2, K2 = boot()
	local ok, err = K2.Store.Import(text)
	check(ok == false and err:find("C_EncodingUtil", 1, true), "got " .. tostring(err))
	check(env2.KstyleUIDB ~= nil)

	-- When the game's base64 decoder fails, import falls back to the Lua decoder.
	for _, failure in ipairs({ "error", "nothing" }) do
		local flaky = setmetatable({
			DecodeBase64 = function()
				if failure == "error" then
					error("DecodeBase64 failed")
				end
			end,
		}, { __index = api })
		local _, K4 = boot({ encoding = flaky })
		ok, err = K4.Store.Import(luaText)
		check(ok == true, "a failing DecodeBase64 (" .. failure .. ") falls back to the Lua decoder: " .. tostring(err))
		ok, err = K4.Store.Import(text)
		check(ok == true, "the Lua decoder also reads C_EncodingUtil strings when DecodeBase64 fails: " .. tostring(err))
	end

	-- When C_EncodingUtil is present but fails, export falls back to Lua and logs the path.
	local broken = CoreEnv.FakeEncoding()
	broken.SerializeCBOR = function()
		error("cbor failed")
	end
	local env3, K3 = boot({ encoding = broken })
	local fallback = K3.Store.Export()
	local raw = CoreEnv.Base64Decode(fallback:sub(7))
	check(raw and raw:sub(1, 5) == "KSL1:", "a failing C_EncodingUtil falls back to the Lua serializer")
	local logged = false
	for _, entry in ipairs(env3.KstyleUIDB.devlog) do
		logged = logged or (entry.module == "Store" and entry.message:find("Lua", 1, true) ~= nil)
	end
	check(logged, "the export path is logged to the devlog")
end

-- Hostile, foreign and truncated strings are rejected before anything changes ------------------------

local function rejects(K, env, text, want, label)
	local before = DeepCopy(env.KstyleUIDB)
	local active = K.Store.ProfileName()
	local ok, err = K.Store.Import(text)
	check(ok == false, label .. ": Import must reject it")
	check(type(err) == "string" and err ~= "", label .. ": Import must say why")
	check(err:lower():find(want:lower(), 1, true), label .. ": the reason must mention '" .. want .. "', got: " .. err)
	-- The devlog may record the rejection; nothing else may change.
	before.devlog, env.KstyleUIDB.devlog = nil, env.KstyleUIDB.devlog
	local after = DeepCopy(env.KstyleUIDB)
	after.devlog = nil
	local same, where = DeepEqual(before, after)
	check(same, label .. ": a rejected import changed KstyleUIDB at " .. tostring(where))
	check(K.Store.ProfileName() == active, label .. ": a rejected import changed the active profile")
	local payload, decodeErr = K.Store.Decode(text)
	check(payload == nil and decodeErr == err, label .. ": Decode gives the same reason")
end

local function goodPayload()
	return {
		kind = "KstyleUI profile",
		version = 1,
		name = "Shared",
		settings = { UnitFrames = { enabled = true, width = 250 } },
		layout = { player = { anchor = "BOTTOM", x = 0, y = 200 } },
	}
end

local function variants(change)
	local payload = goodPayload()
	change(payload)
	return payload
end

do
	local api = CoreEnv.FakeEncoding()
	local env, K = boot({ encoding = api })
	K.Store.Module("UnitFrames").width = 240

	-- The crafted strings are valid when unchanged, so each rejection below is for its one change.
	local ok, name = K.Store.Import(CoreEnv.CraftCBOR(api, goodPayload()))
	check(ok and name == "Shared", "a crafted CBOR payload imports: " .. tostring(name))
	ok, name = K.Store.Import(CoreEnv.CraftLua(goodPayload()))
	check(ok and name == "Shared (2)", "a crafted Lua payload imports: " .. tostring(name))
	K.Store.SetProfile("Default")
	local good = K.Store.Export()

	-- Not a string, empty, or not ours.
	rejects(K, env, nil, "paste", "nil")
	rejects(K, env, "", "paste", "an empty string")
	rejects(K, env, "   \n ", "paste", "whitespace")
	rejects(K, env, "!WA:2!S3xxlTTXXzq", "not a KstyleUI profile", "a WeakAuras string")
	rejects(K, env, "!E1!ABCDEFGHIJKLMNOP", "not a KstyleUI profile", "an ElvUI string")
	rejects(K, env, "!PLATER:2!ABCDEF", "not a KstyleUI profile", "a Plater string")
	rejects(K, env, "hello world", "not a KstyleUI profile", "plain text")
	rejects(K, env, "KSUI2:" .. good:sub(7), "newer", "a newer format")
	rejects(K, env, string.rep("A", 200000), "too long", "an oversized paste")

	-- Truncated or corrupt.
	rejects(K, env, good:sub(1, #good - 1), "incomplete", "one character cut")
	rejects(K, env, good:sub(1, math.floor(#good / 2)), "incomplete", "cut in half")
	local cut = good:sub(1, 6 + math.floor((#good - 6) / 8) * 4)
	rejects(K, env, cut, "incomplete", "cut on a base64 block boundary")
	rejects(K, env, "KSUI1:", "incomplete", "the prefix alone")
	rejects(K, env, "KSUI1:@@@@####", "incomplete", "bad base64 characters")
	rejects(K, env, "KSUI1:QUJD=QUJD", "incomplete", "padding in the middle")
	local luaGood = CoreEnv.CraftLua(goodPayload())
	rejects(K, env, luaGood:sub(1, #luaGood - 4), "incomplete", "a truncated Lua string")
	local body = CoreEnv.WriteLua(goodPayload())
	rejects(K, env, CoreEnv.CraftLua(body, { length = #body + 1 }), "incomplete", "a Lua body shorter than its header")
	rejects(K, env, CoreEnv.CraftLua(body, { checksum = 12345 }), "incomplete", "a Lua body with a bad checksum")
	rejects(K, env, CoreEnv.CraftLua(body:sub(1, -2)), "incomplete", "a Lua body missing its last brace")
	rejects(K, env, CoreEnv.CraftLua(body .. "T"), "incomplete", "a Lua body with trailing data")
	rejects(K, env, CoreEnv.CraftLua("{s4:kinds16:KstyleUI profiles7:versionn0x10;}"), "incomplete", "a hex number")
	rejects(K, env, CoreEnv.CraftLua("{s4:kinds16:KstyleUI profiles7:versionn1e999;}"), "incomplete", "an infinite number")
	rejects(K, env, CoreEnv.CraftLua("{s4:kinds99999999:x}"), "incomplete", "a string longer than the data")
	rejects(K, env, CoreEnv.CraftLua("{s1:as1:as1:as1:b}"), "incomplete", "a duplicate key")
	rejects(K, env, CoreEnv.CraftLua(string.rep("{s1:a", 200) .. "T" .. string.rep("}", 200)), "incomplete", "deep nesting in the Lua format")
	rejects(K, env, CoreEnv.CraftLua("loadstring('x')()"), "incomplete", "Lua code instead of data")
	rejects(K, env, CoreEnv.CraftCBOR(api, goodPayload()):sub(1, -5), "incomplete", "a truncated zlib stream")

	-- A decompression bomb.
	local bomb = CoreEnv.FakeEncoding()
	local env2, K2 = boot({ encoding = bomb })
	bomb.DecompressString = function()
		return string.rep("x", 3 * 1024 * 1024)
	end
	rejects(K2, env2, CoreEnv.CraftCBOR(bomb, goodPayload()), "too large", "a payload that inflates past the cap")

	-- Well-formed strings whose content is wrong.
	local function payloadCase(change, want, label)
		rejects(K, env, CoreEnv.CraftCBOR(api, variants(change)), want, label .. " (CBOR)")
		local ok2, lua = pcall(CoreEnv.CraftLua, variants(change))
		if ok2 then
			rejects(K, env, lua, want, label .. " (Lua)")
		end
	end
	rejects(K, env, CoreEnv.CraftCBOR(api, "just a string"), "not a KstyleUI profile", "a payload that is not a table")
	payloadCase(function(p) p.kind = "WeakAuras" end, "not a KstyleUI profile", "a foreign kind")
	payloadCase(function(p) p.kind = nil end, "not a KstyleUI profile", "no kind")
	payloadCase(function(p) p.version = K.Store.DB_VERSION + 1 end, "newer", "a newer profile version")
	payloadCase(function(p) p.version = 0 end, "version", "version 0")
	payloadCase(function(p) p.version = 1.5 end, "version", "a fractional version")
	payloadCase(function(p) p.version = "1" end, "version", "a string version")
	payloadCase(function(p) p.extra = true end, "extra", "an unexpected top-level field")
	payloadCase(function(p) p.name = "|cffff0000Evil|r" end, "name", "a name with escape codes")
	payloadCase(function(p) p.name = string.rep("n", 200) end, "name", "a long name")
	payloadCase(function(p) p.settings = "x" end, "settings", "settings that are not a table")
	payloadCase(function(p) p.settings.Hacks = { enabled = true } end, "Hacks", "an unknown module")
	payloadCase(function(p) p.settings.UnitFrames.secret = 1 end, "UnitFrames.secret", "an unknown setting")
	payloadCase(function(p) p.settings.UnitFrames.width = "250" end, "UnitFrames.width", "a setting of the wrong type")
	payloadCase(function(p) p.settings.UnitFrames.width = 9000 end, "UnitFrames.width", "a slider value out of range")
	payloadCase(function(p) p.settings.UnitFrames.player = { healthText = { outline = "THICKNESS" } } end, "UnitFrames.player.healthText.outline", "a dropdown value that is not an option")
	payloadCase(function(p) p.settings.UnitFrames.player = 3 end, "UnitFrames.player", "a number where a table belongs")
	payloadCase(function(p) p.settings.UnitFrames.enabled = "yes" end, "UnitFrames.enabled", "a switch that is not a boolean")
	payloadCase(function(p) p.settings.Bags = { enabled = 1 } end, "Bags.enabled", "a switch of an unloaded module that is not a boolean")
	payloadCase(function(p) p.settings.UnitFrames.texture = string.rep("t", 5000) end, "too long", "a huge string")
	payloadCase(function(p) p.settings.UnitFrames.texture = "a\0b" end, "control", "a control character")
	payloadCase(function(p) p.layout = { player = "here" } end, "layout", "a layout element that is not a table")
	payloadCase(function(p) p.layout = { [string.rep("k", 100)] = { x = 1 } } end, "too long", "a long layout key")

	-- Values only CBOR can carry.
	rejects(K, env, CoreEnv.CraftCBOR(api, variants(function(p) p.settings.UnitFrames.width = 0 / 0 end)), "number", "NaN")
	rejects(K, env, CoreEnv.CraftCBOR(api, variants(function(p) p.settings.UnitFrames.width = math.huge end)), "number", "infinity")
	rejects(K, env, CoreEnv.CraftCBOR(api, variants(function(p) p.settings.UnitFrames[true] = 1 end)), "key", "a boolean key")
	rejects(K, env, CoreEnv.CraftCBOR(api, variants(function(p) p.settings.UnitFrames[{}] = 1 end)), "key", "a table key")
	local deep = {}
	local node = deep
	for _ = 1, 100 do
		node.x = {}
		node = node.x
	end
	rejects(K, env, CoreEnv.CraftCBOR(api, variants(function(p) p.layout.deep = deep end)), "deep", "deep nesting")
	local wide = {}
	for i = 1, 30000 do
		wide["k" .. i] = i
	end
	rejects(K, env, CoreEnv.CraftCBOR(api, variants(function(p) p.layout.wide = wide end)), "too many", "too many values")

	-- A dropdown that lists its options at run time is checked against that list too.
	K.Store.RegisterDefaults("Fonts", { face = "Body", broken = "Body" })
	K.Options.Register("Fonts", {
		{ type = "dropdown", key = "face", label = "Face", help = "The font face.", options = function()
			return { { value = "Body", label = "Body" }, { value = "Display", label = "Display" } }
		end },
		{ type = "dropdown", key = "broken", label = "Broken", help = "A list that fails.", options = function()
			error("no font list")
		end },
	})
	local function fonts(settings)
		return variants(function(p)
			p.settings.Fonts = settings
		end)
	end
	rejects(K, env, CoreEnv.CraftCBOR(api, fonts({ face = "Comic" })), "Fonts.face", "a run-time dropdown value that is not an option")
	rejects(K, env, CoreEnv.CraftCBOR(api, fonts({ broken = "Body" })), "Fonts.broken", "a run-time dropdown whose list fails")
	ok, name = K.Store.Import(CoreEnv.CraftCBOR(api, fonts({ face = "Display" })))
	check(ok and K.Store.Module("Fonts").face == "Display", "a run-time dropdown value that is an option imports: " .. tostring(name))
	K.Store.SetProfile("Default")

	-- Decode reads a good string without applying it.
	local before = DeepCopy(env.KstyleUIDB)
	local payload = K.Store.Decode(good)
	check(type(payload) == "table" and payload.settings.UnitFrames.width == 240 and payload.name == "Default", "Decode returns the payload")
	before.devlog, env.KstyleUIDB.devlog = nil, env.KstyleUIDB.devlog
	local after = DeepCopy(env.KstyleUIDB)
	after.devlog = nil
	check(DeepEqual(before, after), "Decode applies nothing")
end

-- The Lua codec on its own ------------------------------------------------------------------------

do
	local _, K = CoreEnv.New()
	local Codec = K.Codec
	for input, want in pairs({ [""] = "", f = "Zg==", fo = "Zm8=", foo = "Zm9v", foob = "Zm9vYg==", fooba = "Zm9vYmE=", foobar = "Zm9vYmFy" }) do
		check(Codec.EncodeBase64(input) == want, "base64 of '" .. input .. "' (RFC 4648 test vector)")
		check(Codec.DecodeBase64(want) == input, "base64 decode of '" .. want .. "'")
	end
	local bytes = {}
	for i = 0, 255 do
		bytes[#bytes + 1] = string.char(i)
	end
	local all = table.concat(bytes)
	check(Codec.DecodeBase64(Codec.EncodeBase64(all)) == all, "base64 round-trips every byte")
	check(Codec.EncodeBase64(all) == CoreEnv.Base64Encode(all), "the core's base64 matches the reference")
	for _, bad in ipairs({ "Zg=", "Zg===", "Z===", "Zm9v!", "Zg==Zg==", "=Zg=" }) do
		check(Codec.DecodeBase64(bad) == nil, "malformed base64 is refused: " .. bad)
	end
	check(Codec.Adler32("Wikipedia") == 300286872, "Adler-32 of 'Wikipedia'")

	local value = {
		all = all, empty = "", n = { 0, -1, 1.5, 2 ^ 53, -2 ^ 40, 1e-7, 1e300, 0.1 }, flags = { yes = true, no = false },
		[7] = "seven", nested = { a = { b = { c = "d" } } },
	}
	local text = Codec.Serialize(value)
	check(text == CoreEnv.WriteLua(value), "Serialize writes the documented format with sorted keys")
	local back = Codec.Deserialize(text)
	check(DeepEqual(back, value), "Serialize and Deserialize round-trip")
	Raises(function() Codec.Serialize({ f = function() end }) end, "function", "Serialize of a function")
	Raises(function() Codec.Serialize({ x = 0 / 0 }) end, "finite", "Serialize of NaN")
	Raises(function() Codec.Serialize({ [true] = 1 }) end, "key", "Serialize of a boolean key")
end

do
	local env, K = CoreEnv.New({ saved = {
		version = 16, profiles = { Default = {}, Custom = {}, Sized = {} },
		layouts = {
			Default = { ["minimap.main"] = { anchor = "TOPRIGHT", x = -17, y = -17 } },
			Custom = { ["minimap.main"] = { anchor = "TOPLEFT", x = 40, y = -50, width = 240, height = 240 } },
			Sized = { ["minimap.main"] = { x = -17, width = 220 } },
		},
	} })
	CoreEnv.Boot(env)
	local layouts = K.Store.Data().layouts
	check(layouts.Default["minimap.main"] == nil, "the old minimap inset follows the corrected default")
	check(DeepEqual(layouts.Custom["minimap.main"], { anchor = "TOPLEFT", x = 40, y = -50, width = 240, height = 240 }), "a custom minimap placement and size stay unchanged")
	check(DeepEqual(layouts.Sized["minimap.main"], { width = 220 }), "a custom minimap size keeps following the default position")
end

-- Migration 20 (KSTY-33): the boss column moved 74.6 units in beside the quest card's column. A saved column at the
-- old default goes to the new place, in DPS and Tank by taking the default and in Healer, where it can only be a DPS
-- place kept across a preset switch, by moving it there; a column the player moved stays where it is.
do
	local saved = {
		version = 18,
		profiles = { DPS = { Layout = { preset = "DPS" } }, Moved = { Layout = { preset = "Tank" } }, Healer = { Layout = { preset = "Healer" } } },
		layouts = {
			DPS = { ["unitframes.boss"] = { anchor = "BOTTOMRIGHT", x = -530.4, y = 752 } },
			Moved = { ["unitframes.boss"] = { anchor = "BOTTOMRIGHT", x = -700, y = 760 } },
			Healer = { ["unitframes.boss"] = { anchor = "BOTTOMRIGHT", x = -530.4, y = 752 } },
		},
		characters = {}, account = {}, devlog = {},
	}
	local menv = boot({ saved = saved })
	local db = menv.KstyleUIDB
	check(db.version == 27, "version 18 data migrates to 27")
	check(db.layouts.DPS["unitframes.boss"] == nil, "a DPS boss column at the old default takes the new default")
	local moved = db.layouts.Moved["unitframes.boss"]
	check(moved and moved.x == -700 and moved.y == 760, "a boss column the player moved stays where it is")
	local healer = db.layouts.Healer["unitframes.boss"]
	check(healer and healer.anchor == "BOTTOMRIGHT" and math.abs(healer.x + 605) < 1e-6 and healer.y == 752, "a Healer profile's DPS-placed column moves with the DPS default")
end


-- Migration 22 (KSTY-50): the minimap became a card with its zone above it, so the map moved 22 units down to leave
-- the zone room under the screen's top margin. A map saved at the old default takes the new default; a map the
-- player moved stays. The overhaul's defaults for the map's buttons (on hover) and its texts (outline with a soft
-- shadow, the world layer) replace the old defaults a profile saved; any other choice stays.
do
	local saved = {
		version = 21,
		profiles = {
			Default = { Minimap = { column = { hover = false }, zone = { outline = "" }, clock = { outline = "" }, coords = { outline = "THICKOUTLINE" } } },
			Moved = { Minimap = { column = { hover = true }, zone = { outline = "OUTLINE" } } },
		},
		layouts = {
			Default = { ["minimap.main"] = { anchor = "TOPRIGHT", x = -16, y = -16 } },
			Moved = { ["minimap.main"] = { anchor = "TOPRIGHT", x = -40, y = -60 } },
		},
		characters = {}, account = {}, devlog = {},
	}
	local menv = boot({ saved = saved })
	local db = menv.KstyleUIDB
	check(db.version == 27, "version 21 data migrates to 27")
	check(db.layouts.Default["minimap.main"] == nil, "a map at the old default takes the new default under the zone heading")
	local moved = db.layouts.Moved["minimap.main"]
	check(moved and moved.x == -40 and moved.y == -60, "a map the player moved stays where it is")
	local minimap = db.profiles.Default.Minimap
	check(minimap.column.hover == true, "the old default of buttons at rest becomes buttons on hover")
	check(minimap.zone.outline == "world" and minimap.clock.outline == "world", "the old default soft shadow becomes the world layer's outline and shadow")
	check(minimap.coords.outline == "THICKOUTLINE", "an outline the player chose stays")
	check(db.profiles.Moved.Minimap.zone.outline == "OUTLINE", "in every profile")
	check(#menv._errors == 0, "the migration raises no error: " .. tostring(menv._errors[1]))
end

-- Migration 23 (KSTY-50): the chat's tabs follow the overhaul's mock-up, the selected one gilt over a gilt underline,
-- so a profile that kept the old default of gold text takes the underline; any other tab style stays.
do
	local saved = {
		version = 22,
		profiles = { Default = { Chat = { tabStyle = "plain" } }, Filled = { Chat = { tabStyle = "filled" } } },
		layouts = {}, characters = {}, account = {}, devlog = {},
	}
	local menv = boot({ saved = saved })
	local db = menv.KstyleUIDB
	check(db.version == 27, "version 22 data migrates to 27")
	check(db.profiles.Default.Chat.tabStyle == "underline", "the old default tab style becomes the gilt underline")
	check(db.profiles.Filled.Chat.tabStyle == "filled", "a tab style the player chose stays")
	check(#menv._errors == 0, "the migration raises no error: " .. tostring(menv._errors[1]))
end

print("store ok")
