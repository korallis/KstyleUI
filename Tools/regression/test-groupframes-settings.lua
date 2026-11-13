-- test-groupframes-settings.lua: KstyleUI_GroupFrames registers off by default, declares every setting with a schema row, and reads a damaged value as its default.
local G = dofile("Tools/regression/group_env.lua")

local _, K, ns = G.New()

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- Registration: the module is known, off by default, and running nothing.
local listed = false
for _, name in ipairs(K.Modules.List()) do
	listed = listed or name == "GroupFrames"
end
assert(listed, "GroupFrames must register with KstyleUI.Modules.Register")
eq(K.Modules.IsEnabled("GroupFrames"), false, "GroupFrames is off by default")
eq(K.Modules.IsRunning("GroupFrames"), false, "GroupFrames does not run until it is enabled")

-- The footprints from element-keys.md are the defaults.
local d = K.Store.Defaults("GroupFrames")
assert(type(d) == "table", "GroupFrames registers its defaults")
eq(d.party.width, 259, "party width default: the mock-up's 194 row and its 65-unit debuff lane")
eq(d.party.height, 39, "party height default: the name line, a 12-unit bar and a 3-unit power line")
eq(d.party.spacing, 13, "party spacing default: the mock-up's 52-unit pitch")
eq(d.party.card, false, "the party stands bare on the world")
eq(d.raid.width, 116, "raid width default: the 20-player mock-up's cell")
eq(d.raid.height, 36, "raid height default: the name line, an 11-unit bar and a 2-unit power line")
eq(d.raid.spacing, 9, "raid spacing default: the mock-up's 45-unit pitch")
eq(d.raid.groupSpacing, 13, "raid group spacing default: the mock-up's gap between groups")
eq(d.raid.groupsPerRow, 8, "raid groups per row default")
eq(d.raid.card, true, "the raid sits in a card")

-- KSTY-57: the class caption and the health text's place only reach a party frame with a portrait, so the rows
-- offer them only there; a row keeps the percent on its name line.
do
	local find = {}
	for _, row in ipairs(K.Options.Get("GroupFrames")) do
		if row.key then
			find[row.key] = row
		end
	end
	local function shown(key, settings)
		return find[key].showWhen(settings) == true
	end
	local rows = { party = { portrait = false, healthText = "PERCENT", textLayout = "ABOVE" }, raid = { portrait = false, healthText = "PERCENT", textLayout = "ABOVE" } }
	local portrait = { party = { portrait = true, healthText = "PERCENT", textLayout = "ABOVE" }, raid = rows.raid }
	for _, key in ipairs({ "classLine", "healthTextPlace" }) do
		eq(shown("party." .. key, rows), false, "party." .. key .. " hides on a party row")
		eq(shown("party." .. key, portrait), true, "party." .. key .. " shows with the portrait")
		eq(shown("raid." .. key, portrait), false, "raid." .. key .. " never shows: a raid frame is a row")
	end
end

-- Every default has a schema row, and every schema row's key has a default.
local schema = K.Options.Get("GroupFrames")
assert(type(schema) == "table", "GroupFrames registers a schema")
local rows = {}
for _, row in ipairs(schema) do
	if row.key then
		rows[row.key] = row
	end
end
local function walk(node, prefix)
	for key, value in pairs(node) do
		local path = prefix and (prefix .. "." .. key) or key
		if type(value) == "table" and value.r == nil then
			walk(value, path)
		elseif path ~= "enabled" then
			assert(rows[path], "the setting " .. path .. " has no schema row")
		end
	end
end
walk(d, nil)

-- The customisations the spec requires.
local function row(key, rowType)
	local r = rows[key]
	assert(r, "missing schema row " .. key)
	eq(r.type, rowType, key .. " row type")
	return r
end
for _, kind in ipairs({ "party", "raid" }) do
	row(kind .. ".width", "slider")
	row(kind .. ".height", "slider")
	row(kind .. ".spacing", "slider")
	row(kind .. ".growth", "dropdown")
	row(kind .. ".sortBy", "dropdown")
	row(kind .. ".nameSize", "slider")
	row(kind .. ".healthText", "dropdown")
	row(kind .. ".healthTextSize", "slider")
end
row("raid.groupGrowth", "dropdown")
row("raid.groupsPerRow", "slider")
row("raid.unitsPerColumn", "slider")
row("party.showPlayer", "toggle")
row("party.showSolo", "toggle")
row("health.texture", "texture")
row("health.orientation", "dropdown")
local source = row("health.colorSource", "dropdown")
local values = {}
for _, option in ipairs(source.options) do
	values[option.value] = true
end
assert(values.class and values.reaction and values.custom, "health colour offers class, reaction and custom")
row("health.color", "color")
row("text.nameFont", "font")
row("text.nameOutline", "dropdown")
row("text.healthFont", "font")
row("text.healthOutline", "dropdown")
row("accent.source", "dropdown")
row("accent.color", "color")
row("range.alpha", "slider")
assert(type(schema.preview) == "function", "GroupFrames gives the settings window a live preview")

-- A damaged or hand-edited value reads as its default; a number out of range is clamped.
local S = ns.Settings
local saved = K.Store.Module("GroupFrames")
saved.party.growth = "SIDEWAYS"
saved.party.width = 9999
saved.raid.sortBy = 42
saved.health.color = { r = 2, g = "x", b = 0 }
saved.text.nameFont = ""
local party = S.Kind("party")
eq(party.growth, "DOWN", "an unknown growth reads as the default")
eq(party.width, rows["party.width"].max, "a width out of range is clamped")
eq(S.Kind("raid").sortBy, "GROUP", "a sort of the wrong type reads as the default")
local color = S.Get("health.color")
eq(color.r, d.health.color.r, "a colour out of range reads as the default")
eq(S.Get("text.nameFont"), d.text.nameFont, "an empty font reads as the default")
G.Raises(function()
	S.Get("party.nope")
end, "nope", "an unknown setting raises")

print("groupframes settings ok")
