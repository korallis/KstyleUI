-- test-auras-model.lua: KstyleUI_Auras's model: settings resolved and clamped, growth and sort mapped to the engine's names, element sizes, footprints, capacity and the preview's timer text.
local A = dofile("Tools/regression/auras_env.lua")

local _, K, ns = A.New({ layout = true })
local Model = assert(ns.Model, "KstyleUI_Auras has no Model")

local function check(cond, message)
	if not cond then
		error(message, 2)
	end
end

local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 1e-9
end

-- Defaults: the module is off, and the defaults fit the element-keys footprints at 1080.
check(Model.defaults.enabled == false, "the module is off by default")
check(K.Features.modules.Auras == false, "the switch in Features is off")
local d = Model.defaults
local buffs = Model.Group(d, "buffs")
local debuffs = Model.Group(d, "debuffs")
local timer = Model.Timer(d)
local bw, bh = Model.Footprint(buffs, timer)
local dw, dh = Model.Footprint(debuffs, timer)
check(bw <= 420 and bh <= 76, "the buff footprint at defaults fits 420 x 76, got " .. bw .. " x " .. bh)
check(dw <= 420 and dh <= 38, "the debuff footprint at defaults fits 420 x 38, got " .. dw .. " x " .. dh)
check(buffs.rows == 2 and debuffs.rows == 1, "two rows of buffs and one of debuffs by default")
check(buffs.growth == "LEFT_DOWN" and debuffs.growth == "LEFT_DOWN", "both groups grow left from under the minimap")

-- Growth: the corner the panel grows from and the engine's direction names.
local cases = {
	{ "LEFT_DOWN", "TOPRIGHT", "Left", "Down" },
	{ "LEFT_UP", "BOTTOMRIGHT", "Left", "Up" },
	{ "RIGHT_DOWN", "TOPLEFT", "Right", "Down" },
	{ "RIGHT_UP", "BOTTOMLEFT", "Right", "Up" },
}
for _, case in ipairs(cases) do
	local anchor, h, v = Model.Growth(case[1])
	check(anchor == case[2] and h == case[3] and v == case[4], "growth " .. case[1] .. " maps to " .. case[2] .. ", got " .. tostring(anchor))
end
local anchor = Model.Growth("SIDEWAYS")
check(anchor == "TOPRIGHT", "an unknown growth falls back to left and down")

-- Sort: setting value to the engine's AuraContainerSortMethod and direction names.
local sorts = {
	{ "time", false, "ExpirationOnly", "Normal" },
	{ "time", true, "ExpirationOnly", "Reverse" },
	{ "name", false, "NameOnly", "Normal" },
	{ "applied", false, "AuraInstanceIDOnly", "Normal" },
	{ "blizzard", true, "Default", "Reverse" },
	{ "nonsense", false, "ExpirationOnly", "Normal" },
}
for _, case in ipairs(sorts) do
	local method, direction = Model.Sort(case[1], case[2])
	check(method == case[3] and direction == case[4], "sort " .. case[1] .. " maps to " .. case[3] .. " " .. case[4] .. ", got " .. tostring(method) .. " " .. tostring(direction))
end

-- Element size: the icon plus the timer under it, or the icon alone.
local g = Model.Group({ buffs = { iconSize = 30, spacing = 4, rowSpacing = 2, rows = 3, columns = 5 } }, "buffs")
local below = Model.Timer({ timer = { format = "short", position = "below", size = 10 } })
local inside = Model.Timer({ timer = { format = "short", position = "inside", size = 10 } })
local none = Model.Timer({ timer = { format = "none", position = "below", size = 10 } })
local w, h = Model.ElementSize(g, below)
check(w == 30 and h == 41, "a timer under a 30-unit icon adds its size plus 1, got " .. w .. " x " .. h)
w, h = Model.ElementSize(g, inside)
check(w == 30 and h == 30, "a timer inside the icon adds nothing")
w, h = Model.ElementSize(g, none)
check(w == 30 and h == 30, "no timer adds nothing")

-- Footprint: columns and rows of elements with their gaps; no gap after the last one.
w, h = Model.Footprint(g, below)
check(w == 5 * 30 + 4 * 4 and h == 3 * 41 + 2 * 2, "5 columns by 3 rows, got " .. w .. " x " .. h)

-- Line size: exactly the columns fit on a line, and one more does not.
local line = Model.LineSize(g, below)
check(line >= 5 * 30 + 4 * 4, "five 30-unit icons with 4-unit gaps fit on a line of " .. line)
check(line < 6 * 30 + 5 * 4, "a sixth icon does not fit on a line of " .. line)

-- Capacity: the frames one group may show, less the weapon enchantments that share its rows.
check(Model.Capacity(g, 0) == 15, "3 rows of 5 hold 15 auras")
check(Model.Capacity(g, 2) == 13, "two weapon enchantments take two of the 15 places")
check(Model.Capacity(g, 40) == 0, "capacity never goes below 0")

-- Clamping: values a damaged profile could hold.
local bad = Model.Group({ buffs = { iconSize = 900, spacing = -5, rowSpacing = "x", rows = 2.7, columns = 0 / 0, growth = 4, sort = {}, reverse = "yes" } }, "buffs")
check(bad.iconSize == Model.LIMITS.iconSize.max, "an icon size above the maximum clamps")
check(bad.spacing == 0, "a negative spacing clamps to 0")
check(bad.rowSpacing == d.buffs.rowSpacing, "a spacing that is not a number takes the default")
check(bad.rows == 2, "rows round down to a whole number")
check(bad.columns == d.buffs.columns, "NaN columns take the default")
check(bad.growth == d.buffs.growth and bad.sort == d.buffs.sort, "unknown choices take the defaults")
check(bad.reverse == false, "a reverse switch that is not a boolean is off")
local missing = Model.Group({}, "debuffs")
check(missing.iconSize == d.debuffs.iconSize and missing.dispel == true, "a missing group takes every default")
local t = Model.Timer({ timer = { format = "fancy", position = "left", size = 2, outline = "HUGE", expiring = 99, font = 5 } })
check(t.format == d.timer.format and t.position == d.timer.position, "unknown timer choices take the defaults")
check(t.size == Model.LIMITS.timerSize.min and t.expiring == Model.LIMITS.expiring.max, "timer size and warning clamp")
check(t.outline == d.timer.outline and t.font == d.timer.font, "a bad outline or font takes the default")
check(type(d.timer.font) == "string" and d.timer.font ~= "", "the default timer font is a font path")

-- Outline: the setting to SetFont flags.
check(Model.Flags("NONE") == "" and Model.Flags("OUTLINE") == "OUTLINE" and Model.Flags("THICKOUTLINE") == "THICKOUTLINE", "outline flags")

-- The preview's timer text, which follows the engine's default formatter: seconds up to 90, then
-- minutes, hours and days rounded up, and tenths of a second under 3 seconds in the decimal format.
local times = {
	{ 24, "short", "24s" },
	{ 90, "short", "90s" },
	{ 91, "short", "2m" },
	{ 480, "short", "8m" },
	{ 179, "short", "3m" },
	{ 5400, "short", "90m" },
	{ 5401, "short", "2h" },
	{ 200000, "short", "3d" },
	{ 125, "long", "2m 5s" },
	{ 3700, "long", "1h 1m" },
	{ 45, "long", "45s" },
	{ 2.46, "decimal", "2.4" },
	{ 24, "decimal", "24s" },
	{ 24, "none", "" },
}
for _, case in ipairs(times) do
	local text = Model.FormatTime(case[1], case[2])
	check(text == case[3], case[2] .. " " .. case[1] .. " s reads " .. case[3] .. ", got " .. tostring(text))
end

-- The accent: the class colour, or the custom colour when the player picks one.
check(near(select(1, Model.AccentColor({ accent = { source = "custom", color = { r = 0.25, g = 0.5, b = 0.75 } } })), 0.25), "a custom accent uses its colour")
local cr, cg, cb = Model.AccentColor({ accent = { source = "class" } })
local ar, ag, ab = K.Theme.Accent()
check(near(cr, ar) and near(cg, ag) and near(cb, ab), "the class accent follows Theme.Accent")
local fr = Model.AccentColor({ accent = { source = "custom", color = { r = "red" } } })
check(near(fr, ar), "a broken custom colour falls back to the class accent")

print("auras model ok")
