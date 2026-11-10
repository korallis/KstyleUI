-- test-store-centre.lua: version 9 centre layout and settings migration.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local copy = CoreEnv.DeepCopy

local old = {
	["unitframes.player"] = { "BOTTOM", 0, 200, 490, 80 },
	["unitframes.target"] = { "TOP", 0, -742.5, 490, 84 },
	["unitframes.resource"] = { "BOTTOM", 0, 286, 120, 14 },
	["unitframes.castbar.player"] = { "BOTTOM", 0, 602, 272, 30 },
	["cooldowns.essential"] = { "BOTTOM", 0, 308, 243, 38 },
	["cooldowns.utility"] = { "BOTTOM", 218, 308, 161, 38 },
	["cooldowns.buffs"] = { "BOTTOM", -259, 308, 243, 38 },
	["cooldowns.bars"] = { "BOTTOM", -259, 354, 243, 43 },
	["meters.swing"] = { "BOTTOM", 0, 352, 260, 8 },
	["actionbars.bar1"] = { "BOTTOM", 0, 68, 489, 38 },
	["actionbars.bar2"] = { "BOTTOM", 0, 109, 489, 38 },
	["actionbars.bar3"] = { "BOTTOM", 0, 150, 489, 38 },
	["databars.xp"] = { "BOTTOM", 0, 52, 489, 4 },
}

local layout = {}
for key, v in pairs(old) do
	layout[key] = { anchor = v[1], x = v[2], y = v[3], width = v[4], height = v[5] }
end
local env, K = CoreEnv.New({ saved = {
	version = 9,
	profiles = { Default = {}, Old = {}, Custom = {}, Scaled = { Appearance = { uiScale = 1 } } },
	layouts = {
		Old = layout,
		Custom = {
			["unitframes.player"] = { x = 17, width = 501, height = 80 },
			["unitframes.target"] = { anchor = "TOPLEFT", x = 42, height = 90 },
			["actionbars.bar1"] = { width = 500 },
			["databars.xp"] = { y = 70, width = 489, height = 7 },
		},
		Scaled = { ["unitframes.target"] = { anchor = "TOP", x = 0, y = -540 } },
	},
} })
local r, g, b = K.Tokens.Color("rare")
local texture = K.Tokens.MediaList("statusbar")[1].path
env.KstyleUIDB.profiles.Old = {
	Appearance = { uiScale = 16 / 19 },
	UnitFrames = {
		player = { style = "lumen", healthColor = "class", castbarColor = "class", castbarCaps = false, powerHeight = 5, healthTexture = texture, powerTexture = texture, fonts = { name = { size = 17 } } },
		target = { style = "lumen", healthColor = "reaction", castbarCaps = false, castbarIcon = true, healthOrientation = "RIGHT", powerOrientation = "RIGHT", auraSpacing = 2, auraSize = 28, auraColumns = 14, auraPosition = "CENTER", healthTexture = texture, powerTexture = texture, fonts = { name = { size = 17 }, health = { size = 12 }, cast = { size = 13 } } },
	},
	ActionBars = { enabled = false, bar1 = { size = 38, spacing = 3 }, bar2 = { enabled = false, size = 38, spacing = 3, showEmpty = false } },
	Cooldowns = { accent = "class", essential = { size = 38, spacing = 3, timerSize = 13, countSize = 11, readyGlow = true }, buffs = { size = 38, spacing = 3, growth = "center", timerSize = 12, countSize = 10 } },
	DataBars = { xp = { text = "percentRested", border = true, restedColor = { r = r, g = g, b = b, a = 0.5 } } },
}
env.KstyleUIDB.profiles.Custom = {
	Appearance = { uiScale = 16 / 19 },
	UnitFrames = {
		player = { style = "plate", healthColor = "class", healthTexture = texture, powerTexture = texture, fonts = { name = { size = 17 } } },
		target = { style = "plate", healthColor = "reaction", castbarIcon = true, healthTexture = texture, fonts = { name = { size = 17 }, health = { size = 12 }, cast = { size = 13 } } },
	},
	ActionBars = { enabled = false, bar1 = { size = 39, spacing = 4 }, bar2 = { size = 40, spacing = 5, showEmpty = true } },
	Cooldowns = { accent = "custom", essential = { size = 40, spacing = 4, timerSize = 14, countSize = 12, readyGlow = false }, buffs = { size = 40, spacing = 4, growth = "left", timerSize = 14, countSize = 11 } },
	DataBars = { enabled = false, xp = { text = "none", border = false, restedColor = { r = r, g = g, b = b, a = 0.6 } } },
}
env.KstyleUIDB.profiles.CustomLumen = {
	UnitFrames = {
		player = { style = "lumen", healthColor = "custom", healthCustom = { r = 0.1, g = 0.2, b = 0.3 }, healthTexture = "custom texture", powerTexture = "custom power", fonts = { name = { size = 19, font = "custom font", outline = "OUTLINE" } } },
		target = { healthColor = "custom", fonts = { name = { size = 18, font = "custom font" }, health = { size = 15 } } },
	},
}
env.KstyleUIDB.profiles.CustomStyle = { UnitFrames = {
	player = { style = "column", healthColor = "class", healthTexture = texture, fonts = { name = { size = 17 } } },
	target = { style = "column", healthColor = "reaction", powerTexture = texture, fonts = { health = { size = 12 }, cast = { size = 13 } } },
} }
local customSettings = copy(env.KstyleUIDB.profiles.Custom)
local customLumen = copy(env.KstyleUIDB.profiles.CustomLumen)
local customStyle = copy(env.KstyleUIDB.profiles.CustomStyle)
customLumen.UnitFrames.player.style = nil
CoreEnv.Boot(env)
local db = env.KstyleUIDB
assert(db.version == 10 and #env._errors == 0, "version 9 migrates without errors")
local now = K.Setup.Layouts.Get("DPS")
for key in pairs(old) do
	local entry, place = db.layouts.Old[key], now[key]
	assert(entry.anchor == place.anchor and entry.x == place.x and entry.y == place.y, key .. " moves to the new reference: " .. tostring(entry.anchor) .. "," .. tostring(entry.x) .. "," .. tostring(entry.y) .. " expected " .. tostring(place.anchor) .. "," .. tostring(place.x) .. "," .. tostring(place.y))
	assert(entry.width == nil and entry.height == nil, key .. " drops only the old default dimensions")
end
local custom = db.layouts.Custom
assert(custom["unitframes.player"].anchor == "BOTTOM" and custom["unitframes.player"].x == 17 and custom["unitframes.player"].y == 200 and custom["unitframes.player"].width == 501 and custom["unitframes.player"].height == nil, "partial player position uses old defaults and custom width survives")
assert(custom["unitframes.target"].anchor == "TOPLEFT" and custom["unitframes.target"].x == 42 and custom["unitframes.target"].y == -742.5 and custom["unitframes.target"].height == 90, "partial target position uses its old TOP offset")
assert(custom["actionbars.bar1"].anchor == now["actionbars.bar1"].anchor and custom["actionbars.bar1"].y == now["actionbars.bar1"].y and custom["actionbars.bar1"].width == 500, "size-only entry follows the new position")
assert(custom["databars.xp"].anchor == "BOTTOM" and custom["databars.xp"].x == 0 and custom["databars.xp"].y == 70 and custom["databars.xp"].width == nil and custom["databars.xp"].height == 7, "custom position and dimension survive")
local scaled = db.layouts.Scaled["unitframes.target"]
assert(scaled.anchor == now["unitframes.target"].anchor and scaled.x == now["unitframes.target"].x and scaled.y == now["unitframes.target"].y, "old TOP offset includes the root-height lift")
assert(CoreEnv.DeepEqual(db.profiles.Custom, customSettings), "custom settings and disabled modules survive")
assert(CoreEnv.DeepEqual(db.profiles.CustomLumen, customLumen), "custom Lumen colours, textures and fonts survive while the old style resets")
assert(CoreEnv.DeepEqual(db.profiles.CustomStyle, customStyle), "a non-Lumen style retains even values matching old defaults")
local defaults = db.profiles.Old
assert(defaults.ActionBars.enabled == false, "disabled state survives")
assert(defaults.ActionBars.bar2.enabled == nil, "the old disabled bar 2 default resets")
assert(defaults.Cooldowns.accent == nil and defaults.Cooldowns.essential.countSize == nil and defaults.Cooldowns.essential.readyGlow == nil, "old cooldown accent, count size and ready glow reset")
local player, target = defaults.UnitFrames.player, defaults.UnitFrames.target
assert(player.fonts.name.size == nil and target.fonts.name.size == nil and target.fonts.health.size == nil and target.fonts.cast.size == nil, "old UnitFrames font sizes reset")
player.fonts, target.fonts = nil, nil
assert(next(player) == nil and next(target) == nil, "matching old UnitFrames settings and textures reset")
for _, group in ipairs({ defaults.ActionBars.bar1, defaults.ActionBars.bar2, defaults.Cooldowns.essential, defaults.Cooldowns.buffs, defaults.DataBars.xp }) do
	assert(next(group) == nil, "only matching old defaults are cleared")
end

local imported = { kind = "KstyleUI profile", version = 9, name = "Imported", settings = { Appearance = { uiScale = 16 / 19 } }, layout = {
	["unitframes.player"] = { x = 17 },
	["unitframes.target"] = { anchor = "TOP", x = 0, y = -742.5 },
} }
local ok, name = K.Store.Import(CoreEnv.CraftLua(imported))
assert(ok, tostring(name))
local result = db.layouts[name]
assert(result["unitframes.player"].anchor == "BOTTOM" and result["unitframes.player"].x == 17 and result["unitframes.player"].y == 200, "import completes partial positions using old defaults")
assert(result["unitframes.target"].anchor == now["unitframes.target"].anchor and result["unitframes.target"].y == now["unitframes.target"].y, "import migrates old target")
print("store centre ok")
