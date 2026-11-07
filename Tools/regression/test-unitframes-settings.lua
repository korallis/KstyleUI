-- test-unitframes-settings.lua: the unit frames register off by default, and their settings page lets the player customise every frame.
local U = dofile("Tools/regression/unitframes_env.lua")

local KINDS = { "player", "target", "targettarget", "focus", "focustarget", "pet", "boss" }

-- Off by default: the module registers, but a fresh profile leaves it off and builds nothing.
do
	local env, K = U.New({ enabled = false })
	assert(K.Modules.List()[1] ~= nil, "modules registered")
	local found = false
	for _, name in ipairs(K.Modules.List()) do
		found = found or name == "UnitFrames"
	end
	assert(found, "KstyleUI_UnitFrames registers the UnitFrames module")
	assert(K.Modules.IsEnabled("UnitFrames") == false, "the module is off by default")
	assert(K.Modules.IsRunning("UnitFrames") == false, "an off module does not run")
	for _, frame in ipairs(env._frames) do
		assert(frame._template ~= "SecureUnitButtonTemplate", "an off module makes no unit buttons")
	end
end

local env, K, ns = U.New({ enabled = false })
local Settings = ns.Settings
assert(type(Settings) == "table", "ns.Settings is missing")

-- Defaults: every frame kind has its own table, and the player frame matches the v3 mockups.
local defaults = K.Store.Defaults("UnitFrames")
assert(type(defaults) == "table", "UnitFrames registered its defaults")
assert(defaults.enabled == nil or defaults.enabled == false, "defaults never switch the module on")
for _, kind in ipairs(KINDS) do
	local d = defaults[kind]
	assert(type(d) == "table", "defaults for " .. kind)
	assert(d.enabled == true, kind .. " shows by default")
	for _, key in ipairs({ "portrait", "portraitStyle", "portraitSide", "healthTexture", "healthColor", "healthCustom",
		"healthOrientation", "healthText", "power", "powerHeight", "powerTexture", "powerColor", "powerCustom",
		"powerOrientation", "powerText", "name", "level", "fonts" }) do
		assert(d[key] ~= nil, kind .. " has a default for " .. key)
	end
	for _, element in ipairs({ "name", "health", "power", "level" }) do
		local font = d.fonts[element]
		assert(type(font) == "table" and type(font.font) == "string" and type(font.size) == "number" and type(font.outline) == "string",
			kind .. " has a font, size and outline for its " .. element .. " text")
	end
end
assert(defaults.player.portrait == true and defaults.target.portrait == true, "player and target show portraits by default")
assert(defaults.player.portraitSide == "LEFT" and defaults.target.portraitSide == "RIGHT", "the target frame mirrors the player frame")
assert(defaults.player.healthText == "percent", "player health shows a percentage, as in the mockups")
assert(defaults.player.powerText == "currentMax", "player power shows current and max, as in the mockups")
assert(defaults.targettarget.portrait == false and defaults.pet.portrait == false, "the small frames have no portrait by default")
assert(defaults.hideBlizzard == true, "Blizzard's frames are hidden by default")

-- The settings page: a preview, a frame picker, and the rows the spec requires for each frame.
local schema = K.Options.Get("UnitFrames")
assert(type(schema) == "table", "UnitFrames registered a settings schema")
assert(type(schema.preview) == "function", "the schema has a preview builder")
local edit = K.Options.Row("UnitFrames", "edit")
assert(edit and edit.type == "dropdown", "a dropdown picks the frame to customise")
assert(#edit.options == #KINDS, "the picker lists every frame")

local function row(key, kind)
	local r = K.Options.Row("UnitFrames", key)
	assert(r, "no settings row for " .. key)
	if kind then
		assert(r.type == kind, key .. " is a " .. kind .. " row, got " .. tostring(r.type))
	end
	return r
end

local function values(r)
	local options = r.options
	if type(options) == "function" then
		options = options()
	end
	local out = {}
	for _, option in ipairs(options) do
		out[option.value] = true
	end
	return out
end

for _, kind in ipairs(KINDS) do
	row(kind .. ".enabled", "toggle")
	row(kind .. ".portrait", "toggle")
	local style = values(row(kind .. ".portraitStyle", "dropdown"))
	assert(style.portrait and style.class, kind .. ": the portrait is a 2D portrait or the class icon")
	for _, bar in ipairs({ "health", "power" }) do
		row(kind .. "." .. bar .. "Texture", "texture")
		local sources = values(row(kind .. "." .. bar .. "Color", "dropdown"))
		assert(sources.class and sources.reaction and sources.custom, kind .. " " .. bar .. ": class, reaction or custom colour")
		row(kind .. "." .. bar .. "Custom", "color")
		local orientations = values(row(kind .. "." .. bar .. "Orientation", "dropdown"))
		assert(orientations.RIGHT and orientations.LEFT and orientations.UP and orientations.DOWN, kind .. " " .. bar .. ": four fill directions")
		local formats = values(row(kind .. "." .. bar .. "Text", "dropdown"))
		assert(formats.percent and formats.currentMax and formats.both and formats.none, kind .. " " .. bar .. ": percent, current and max, both, none")
	end
	row(kind .. ".powerHeight", "slider")
	for _, element in ipairs({ "name", "health", "power", "level" }) do
		local fonts = values(row(kind .. ".fonts." .. element .. ".font", "dropdown"))
		assert(fonts.theme, kind .. " " .. element .. ": the font can follow KstyleUI's font")
		row(kind .. ".fonts." .. element .. ".size", "slider")
		local outlines = values(row(kind .. ".fonts." .. element .. ".outline", "dropdown"))
		assert(outlines.NONE and outlines.OUTLINE and outlines.THICKOUTLINE, kind .. " " .. element .. ": outline choices")
	end
end
-- Cast bars and the druid's mana bar choose their colour source and fill direction like every other bar.
for _, kind in ipairs({ "player", "target", "focus", "boss" }) do
	row(kind .. ".castbarTexture", "texture")
	local sources = values(row(kind .. ".castbarColor", "dropdown"))
	assert(sources.class and sources.reaction and sources.custom, kind .. " cast bar: class, reaction or custom colour")
	local orientations = values(row(kind .. ".castbarOrientation", "dropdown"))
	assert(orientations.RIGHT and orientations.LEFT and orientations.UP and orientations.DOWN, kind .. " cast bar: four fill directions")
	assert(defaults[kind].castbarOrientation == "RIGHT", kind .. " cast bar fills left to right by default")
end
local manaDirections = values(row("resource.manaOrientation", "dropdown"))
assert(manaDirections.RIGHT and manaDirections.LEFT and manaDirections.UP and manaDirections.DOWN, "the druid mana bar: four fill directions")
assert(defaults.resource.manaOrientation == "RIGHT", "the druid mana bar fills left to right by default")

local accent = values(row("accent", "dropdown"))
assert(accent.class and accent.custom, "the accent follows the class colour or a custom colour")
row("accentColor", "color")
row("hideBlizzard", "toggle")

-- Only the picked frame's rows show, so the page stays short; module-wide rows always show.
local settings = K.Store.Module("UnitFrames")
settings.edit = "target"
assert(row("target.portrait").showWhen(settings) == true, "the picked frame's rows show")
assert(row("player.portrait").showWhen(settings) == false, "other frames' rows hide")
assert(row("hideBlizzard").showWhen == nil, "module-wide rows always show")
settings.edit = "player"
local custom = row("player.healthCustom")
settings.player.healthColor = "class"
assert(custom.showWhen(settings) == false, "the custom colour shows only for the custom source")
settings.player.healthColor = "custom"
assert(custom.showWhen(settings) == true, "the custom colour shows for the custom source")
settings.player.healthColor = "class"

-- Help text stays under 100 characters (Options.Register checks it) and every row has a label.
for _, r in ipairs(schema) do
	assert(type(r.label) == "string" and r.label ~= "", "every row has a label")
end

-- Value(kind, key) gives the default for a value the setting does not allow, with one devlog line.
K.Store.Module("UnitFrames").player.healthText = "sideways"
assert(Settings.Value("player", "healthText") == "percent", "an unknown choice falls back to the default")
K.Store.Module("UnitFrames").player.powerHeight = 999
assert(Settings.Value("player", "powerHeight") == defaults.player.powerHeight, "a size out of range falls back to the default")
K.Store.Module("UnitFrames").player.healthText = "percent"
K.Store.Module("UnitFrames").player.powerHeight = defaults.player.powerHeight
K.Store.Module("UnitFrames").player.castbarOrientation = "SIDEWAYS"
assert(Settings.Value("player", "castbarOrientation") == "RIGHT", "an unknown fill direction falls back to the default")
K.Store.Module("UnitFrames").player.castbarOrientation = "RIGHT"
K.Store.Module("UnitFrames").resource.manaOrientation = "SIDEWAYS"
assert(Settings.Resource("manaOrientation") == "RIGHT", "an unknown mana fill direction falls back to the default")
K.Store.Module("UnitFrames").resource.manaOrientation = "RIGHT"

-- Font(kind, element) -> path, size, flags. "theme" follows the KstyleUI font; the size follows the text size.
local path, size, flags = Settings.Font("player", "health")
local themePath = K.Tokens.Font("body")
assert(path == themePath, "the theme font follows Appearance's font")
assert(size == defaults.player.fonts.health.size, "the size is the setting at a text size of 1")
assert(flags == "", "no outline by default: text gets the soft shadow")
K.Store.Module("UnitFrames").player.fonts.health.outline = "OUTLINE"
K.Store.Module("UnitFrames").player.fonts.health.font = K.Tokens.FontPath("InterSemiBold")
local chosen, _, chosenFlags = Settings.Font("player", "health")
assert(chosen == K.Tokens.FontPath("InterSemiBold") and chosenFlags == "OUTLINE", "a chosen font and outline apply")
K.Store.Module("UnitFrames").player.fonts.health.font = "Interface\\AddOns\\Nope\\bad|font.ttf"
path = Settings.Font("player", "health")
assert(path == themePath, "a font path the theme rejects falls back to the theme font")

-- Accent(): the theme accent, or the custom colour.
local r, g, b = Settings.Accent()
local ar, ag, ab = K.Theme.Accent()
assert(r == ar and g == ag and b == ab, "the accent follows the class colour by default")
K.Store.Module("UnitFrames").accent = "custom"
K.Store.Module("UnitFrames").accentColor = { r = 0.1, g = 0.2, b = 0.3 }
r, g, b = Settings.Accent()
assert(r == 0.1 and g == 0.2 and b == 0.3, "a custom accent applies")

assert(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
print("unitframes settings ok")
