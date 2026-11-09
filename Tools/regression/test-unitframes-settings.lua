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
assert(defaults.player.healthText == "both" and defaults.target.healthText == "both", "player and target health show the percentage and current and max, as the kit sheet does")
assert(defaults.focus.healthText == "both" and defaults.boss.healthText == "both", "so do the other full frames")
assert(defaults.targettarget.healthText == "percent" and defaults.pet.healthText == "percent", "the small frames show a percentage inside the bar")
for _, kind in ipairs({ "player", "target", "focus", "boss" }) do
	assert(defaults[kind].powerText == "none", kind .. ": no power numbers, as on the kit sheet; power shows as the thin bar alone")
end
-- The Lumen mockup's type (arena2/parent/index.html, one unit per pixel): the vitals name 17 over a 15-unit value
-- and a 12-unit level disc; the sigil's name 17 over its 13-unit level line (round 2, Astra #4: the mockup's 20 drowned
-- the cast); the cards' name 16, percentage 14 and 12-unit cap; the pill rows 12. The boss column's compact cards are
-- 258 wide, so their name and percentage are 13: a long boss name in the heading face still fits beside its percentage.
for kind, sizes in pairs({ player = { 17, 15, 10, 12 }, target = { 17, 12, 10, 13 }, focus = { 16, 14, 9, 12 }, boss = { 13, 13, 9, 12 }, pet = { 12, 12, 9, 10 } }) do
	local fonts = defaults[kind].fonts
	assert(fonts.name.size == sizes[1] and fonts.health.size == sizes[2] and fonts.power.size == sizes[3] and fonts.level.size == sizes[4],
		kind .. ": the name, value, power and level sizes follow the Lumen mockup")
end
assert(defaults.player.iconSize == 12 and defaults.target.iconSize == 12, "the status icons on the 70-unit frames are 12 units")
assert(defaults.player.castbarIcon == false and defaults.player.castbarCaps == false, "the player cast bar has no icon and writes the spell as the game does, as the owner's mockup draws Slam")
assert(defaults.target.castbarIcon == true and defaults.target.castbarCaps == false, "the target cast bar keeps its icon for the classic plate, and writes the spell as the game does, as the sigil's cast line reads")
-- The owner's ruling of 2026-11-08: power reads as its type (mana blue, rage red, energy yellow) on every frame; the
-- class colour stays a choice under the same powerColor key, so a saved "class" still applies.
for _, kind in ipairs(KINDS) do
	assert(defaults[kind].powerColor == "power", kind .. ": the power bar takes the power type's colour by default")
end
assert(defaults.player.powerHeight == 5, "the vitals line's power pill is the Lumen mockup's 5 units")
do
	local allowed = {}
	for _, option in ipairs(ns.Settings.CHOICES.powerColor) do
		allowed[option.value] = true
	end
	assert(allowed.power and allowed.class, "the power colour setting still offers the class colour")
end
assert(defaults.pet.powerColor == "power" and defaults.pet.powerHeight == 3, "the compact frames keep the power type's colour and a thin bar")
assert(defaults.player.healthColor == "class", "the player's health fill is the class colour")
assert(defaults.target.healthColor == "reaction", "the target's fill follows its reaction: red when hostile, as on the kit sheet")
assert(defaults.player.powerHeight == 5 and defaults.target.powerHeight == 7, "the vitals power pill is 5 units; the other full frames keep the plate's 7-unit bar")
assert(defaults.player.fonts.health.size == defaults.player.fonts.name.size - 2, "the vitals value is the mockup's 15-unit bold numerals, two under the 17-unit Cinzel name")
for _, kind in ipairs(KINDS) do
	assert(defaults[kind].portraitShape == "round", kind .. ": the portrait is round by default, as the owner's mockup draws it; the design file's octagon is the other choice")
end
assert(defaults.player.fonts.cast.size == 12 and defaults.target.fonts.cast.size == 13, "the cast text is 12 on the player's line and 13 on the sigil's bold cast line (round 2, Astra #4)")
assert(defaults.focus.castbarHeight == 16, "the focus cast bar is 16 units under its 60-unit frame")
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
	local shapes = values(row(kind .. ".portraitShape", "dropdown"))
	assert(shapes.chamfered and shapes.round, kind .. ": the portrait is chamfered or round")
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
	row(kind .. ".castbarCaps", "toggle")
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
assert(row("target.name").showWhen(settings) == true, "the picked frame's rows show")
assert(row("player.name").showWhen(settings) == false, "other frames' rows hide")
assert(row("target.style").showWhen(settings) == true, "each frame picks Lumen or the classic plate")
local styles = values(row("target.style", "dropdown"))
assert(styles.lumen and styles.plate, "the style is Lumen or the classic plate")
assert(row("hideBlizzard").showWhen == nil, "module-wide rows always show")
settings.edit = "player"
local custom = row("player.healthCustom")
settings.player.healthColor = "class"
assert(custom.showWhen(settings) == false, "the custom colour shows only for the custom source")
settings.player.healthColor = "custom"
assert(custom.showWhen(settings) == true, "the custom colour shows for the custom source")
settings.player.healthColor = "class"
local shapeRow = row("player.portraitShape")
settings.player.portrait = false
assert(shapeRow.showWhen(settings) == false, "the portrait shape shows only while the portrait does")
settings.player.portrait = true
assert(shapeRow.showWhen(settings) == true, "the portrait shape shows with the portrait")

-- Help text stays under 100 characters (Options.Register checks it) and every row has a label.
for _, r in ipairs(schema) do
	assert(type(r.label) == "string" and r.label ~= "", "every row has a label")
end

-- Value(kind, key) gives the default for a value the setting does not allow, with one devlog line.
K.Store.Module("UnitFrames").player.healthText = "sideways"
assert(Settings.Value("player", "healthText") == defaults.player.healthText, "an unknown choice falls back to the default")
K.Store.Module("UnitFrames").player.portraitShape = "hexagon"
assert(Settings.Value("player", "portraitShape") == "round", "an unknown portrait shape falls back to round")
K.Store.Module("UnitFrames").player.portraitShape = "round"
assert(Settings.Value("player", "portraitShape") == "round", "round is kept")
K.Store.Module("UnitFrames").player.portraitShape = "chamfered"
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
local themePath = K.Tokens.Font("number")
assert(path == themePath, "the theme font follows Appearance's font, in the health text's Lumen role")
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
