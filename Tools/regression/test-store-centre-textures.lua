-- test-store-centre-textures.lua: the picture's Flat defaults migrate once without disguising a later Glass choice.
local Core = dofile("Tools/regression/core_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local env, K = Core.New()
local paths = {}
for _, item in ipairs(K.Tokens.MediaList("statusbar")) do
	paths[item.key] = item.path
end
local saved = {
	version = 12,
	profiles = {
		Default = {
			UnitFrames = { player = { castbarTexture = "Glass" }, target = { style = "column", castbarTexture = paths.Glass }, focus = { castbarTexture = "Glass" } },
			DataBars = { xp = { texture = "Glass" }, rep = { texture = paths.Glass }, honor = { texture = "Glass" } },
		},
		Legacy = { UnitFrames = { player = { style = "plate", castbarTexture = paths.Glass }, target = { style = "lumen", castbarTexture = "Glass" } }, DataBars = { xp = { texture = paths.Glass } } },
		Custom = { UnitFrames = { player = { castbarTexture = paths.Soft }, target = { castbarTexture = "Soft" } }, DataBars = { xp = { texture = paths.Soft } } },
		Sparse = { UnitFrames = { player = false, target = 9 }, DataBars = { xp = false } },
	},
}
env.KstyleUIDB = saved
local custom = Core.DeepCopy(saved.profiles.Custom)
local list = K.Tokens.MediaList
K.Tokens.MediaList = function(kind)
	local items = list(kind)
	if kind == "statusbar" then
		local reordered = {}
		for i = 2, #items do reordered[#reordered + 1] = items[i] end
		reordered[#reordered + 1] = items[1]
		return reordered
	end
	return items
end
Core.Boot(env)
local profiles = env.KstyleUIDB.profiles
assert(profiles.Default.UnitFrames.player.castbarTexture == paths.Flat, "a saved Glass key migrates to the picker-visible Flat path")
assert(profiles.Default.UnitFrames.target.castbarTexture == paths.Flat, "a saved Glass path migrates without relying on media order")
assert(profiles.Default.DataBars.xp.texture == paths.Flat and profiles.Legacy.DataBars.xp.texture == paths.Flat, "XP migrates both Glass aliases in every profile")
assert(profiles.Default.UnitFrames.focus.castbarTexture == "Glass", "non-caption cast settings are untouched")
assert(profiles.Default.DataBars.rep.texture == paths.Glass and profiles.Default.DataBars.honor.texture == "Glass", "other data bars are untouched")
assert(profiles.Legacy.UnitFrames.player.castbarTexture == paths.Glass and profiles.Legacy.UnitFrames.target.castbarTexture == "Glass", "saved legacy cast styles retain Glass")
assert(Core.DeepEqual(profiles.Custom, custom), "other selected textures survive")
assert(env.KstyleUIDB.version == 17 and #env._errors == 0, "the migration reaches version 17 without errors")

local function profile(module)
	return { version = 14, profiles = { Default = module } }
end
local legacy = { enabled = true, player = { style = "plate" }, target = { style = "lumen" } }
local le, LK, lns = U.New({ saved = profile({ UnitFrames = Core.DeepCopy(legacy) }) })
local function legacyPaint(key, module, casts)
	for _, kind in ipairs({ "player", "target" }) do
		assert(module[kind].castbarTexture == paths.Glass, key .. " pins the omitted old Glass default")
		assert(casts.Get(kind)[1].bar.texturePath == paths.Glass, key .. " paints legacy Glass")
	end
end
legacyPaint("migration", LK.Store.Module("UnitFrames"), lns.CastBars)
Core.Logout(le)
local _, LK2, lns2 = U.New({ saved = le.KstyleUIDB })
legacyPaint("next session", LK2.Store.Module("UnitFrames"), lns2.CastBars)
local ok, imported = LK2.Store.Import(Core.CraftLua({ kind = "KstyleUI profile", version = 14, name = "Legacy", settings = { UnitFrames = legacy } }))
assert(ok, tostring(imported))
legacyPaint("import", LK2.Store.Module("UnitFrames"), lns2.CastBars)

local ue, UK, uns = U.New({ saved = profile({ UnitFrames = { enabled = true, player = { castbarTexture = paths.Glass }, target = { castbarTexture = "Glass" } } }) })
for _, kind in ipairs({ "player", "target" }) do
	assert(UK.Store.Module("UnitFrames")[kind].castbarTexture == paths.Flat, "the cast picker reads Flat after migration")
	local cb = kind == "player" and uns.CastBars.Get(kind)[1] or uns.CastBars.Inline(kind)[1]
	assert(cb.bar.texturePath == paths.Flat, "the migrated caption cast paints Flat")
	for _, choice in ipairs({ "Glass", paths.Glass }) do
		UK.Options.Write("UnitFrames", kind .. ".castbarTexture", choice)
		assert(cb.bar.texturePath == paths.Glass, "a post-migration Glass choice paints Glass")
	end
end
Core.Logout(ue)
local _, UK2, uns2 = U.New({ saved = ue.KstyleUIDB })
assert(UK2.Store.Module("UnitFrames").player.castbarTexture == paths.Glass and uns2.CastBars.Get("player")[1].bar.texturePath == paths.Glass, "a later Glass choice survives the next session")

local de, DK, dns = D.New({ saved = profile({ DataBars = { xp = { texture = paths.Glass } } }) })
assert(DK.Store.Module("DataBars").xp.texture == paths.Flat and dns.Bars.views.xp.fill.texturePath == paths.Flat, "the XP picker and paint agree after migration")
for _, choice in ipairs({ "Glass", paths.Glass }) do
	DK.Options.Write("DataBars", "xp.texture", choice)
	assert(dns.Bars.views.xp.fill.texturePath == paths.Glass and dns.Bars.views.xp.track.texturePath == paths.Glass, "a post-migration Glass choice paints both XP layers")
end
Core.Logout(de)
local _, DK2, dns2 = D.New({ saved = de.KstyleUIDB })
assert(DK2.Store.Module("DataBars").xp.texture == paths.Glass and dns2.Bars.views.xp.track.texturePath == paths.Glass, "XP does not remigrate a later Glass choice")
print("store centre textures ok")
