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
	check(db.version == K.Store.DB_VERSION and K.Store.DB_VERSION == 2, "a fresh KstyleUIDB starts at the code's version")
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

	-- Data from a newer KstyleUI is left alone; a failing migration stops and is logged.
	local env2, K2 = CoreEnv.New({ saved = { version = 9, profiles = {} } })
	CoreEnv.Boot(env2)
	check(env2.KstyleUIDB.version == 9, "a newer version is not lowered")
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

print("store ok")
