-- test-unitframes-geometry.lua: where a unit frame's portrait, bars and texts sit at any size, and the text formats that never read a secret.
local U = dofile("Tools/regression/unitframes_env.lua")

local env, K, ns = U.New({ enabled = false })
local Geometry, Format = ns.Geometry, ns.Format
assert(type(Geometry) == "table" and type(Format) == "table", "ns.Geometry and ns.Format are missing")

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local function base(overrides)
	local s = {
		portrait = true, portraitSide = "LEFT", level = true, name = true, power = true, powerHeight = 5,
		healthText = "percent", powerText = "currentMax",
		fonts = { name = { size = 11 }, health = { size = 11 }, power = { size = 9 }, level = { size = 9 } },
	}
	for k, v in pairs(overrides or {}) do
		s[k] = v
	end
	return s
end

-- Text columns: none is 0, and longer formats take more room.
assert(Format.ColumnWidth("none", 11) == 0, "no text takes no room")
local pct, cur, cm, both = Format.ColumnWidth("percent", 11), Format.ColumnWidth("current", 11), Format.ColumnWidth("currentMax", 11), Format.ColumnWidth("both", 11)
assert(pct > 0 and pct < cur and cur < cm and cm < both, "percent < current < current and max < both")
assert(Format.ColumnWidth("percent", 22) > pct, "a bigger font takes more room")

-- The full frame at the 1080 reference, as the kit sheet draws it (docs/design/mockups/05_kit_hunter.jpg):
-- a 46-unit portrait over the outer end of one glass panel, the name on top, a long health track with the
-- percentage at its right end, current and max under it, and a thin power bar on the glass's bottom edge.
local function mid(r)
	return r.y + r.h / 2
end
local g = Geometry.Frame(base({ healthText = "both" }), 266, 46, 1)
assert(not g.compact, "46 units tall is a full frame")
assert(near(g.portrait.x, 0) and near(g.portrait.y, 0) and near(g.portrait.w, 46) and near(g.portrait.h, 46), "the portrait is the frame's height, at the left")
assert(g.panel.x > 46 and near(g.panel.x + g.panel.w, 266) and near(g.panel.h, 46), "the bars' column fills the rest of the frame")

-- One glass shape runs under the portrait, and the portrait stands proud of it.
local glass = g.glass
assert(glass, "the frame has one glass shape")
assert(near(glass.x, g.portrait.x + g.portrait.w / 2), "the glass starts under the portrait's centre, so the portrait overlaps its outer end")
assert(near(glass.x + glass.w, 266), "the glass runs to the frame's far end")
assert(glass.y > 0 and near(glass.y + glass.h, 46 - glass.y), "the glass sits inside the portrait's height, the same at the top and bottom")

-- One long health track and a thin power bar under it, both across the column's inner width.
local pad = g.health.x - g.panel.x
assert(pad > 0 and near(g.health.x + g.health.w, g.panel.x + g.panel.w - pad), "the health track spans the column, with the same padding at both ends")
assert(near(g.power.x, g.health.x) and near(g.power.w, g.health.w), "the power bar runs under the whole health track")
assert(near(g.power.h, 5), "the power bar is the chosen height")
assert(near(g.power.y + g.power.h, glass.y + glass.h - 2), "the power bar sits on the glass's bottom edge, inside its two bevel lines")
assert(g.name and mid(g.name) < g.health.y, "the name sits above the health track")
assert(near(g.name.x, g.health.x), "the name starts where the track starts")

-- The percentage at the track's right end, current and max under it, the power text on the same row at the left.
assert(math.abs(mid(g.healthText) - mid(g.health)) < 0.5, "the health text is centred on the track")
local trackEnd = g.health.x + g.health.w
assert(g.healthText.x >= g.health.x and g.healthText.x + g.healthText.w < trackEnd and g.healthText.x + g.healthText.w > trackEnd - 4, "the health text sits inside the track's right end")
assert(g.healthSub, "both: current and max show under the track")
assert(mid(g.healthSub) > g.health.y + g.health.h and mid(g.healthSub) < g.power.y, "current and max sit between the track and the power bar")
assert(near(g.healthSub.x + g.healthSub.w, g.healthText.x + g.healthText.w), "current and max are right-aligned with the percentage")
assert(g.powerText and near(mid(g.powerText), mid(g.healthSub)), "the power text shares the row under the track")
assert(near(g.powerText.x - g.health.x, trackEnd - (g.healthText.x + g.healthText.w)), "the power text starts as far in from the track's left end as the health text ends from its right")
assert(g.powerText.x + g.powerText.w <= g.healthSub.x + 1e-6, "the power text stops before current and max")
assert(g.badge and g.badge.w >= 14, "the level badge is at least 14 units")
assert(near(g.badge.x, 0) and near(g.badge.y + g.badge.h, 46), "the badge sits in the portrait's bottom outer corner")
assert(g.levelText == nil, "the level shows in the badge, not in the name row")

-- Mirrored for the target: the portrait on the right, over the glass's right end; the texts read the same way.
local m = Geometry.Frame(base({ healthText = "both", portraitSide = "RIGHT" }), 266, 46, 1)
assert(near(m.portrait.x, 220), "a right portrait sits at the right edge")
assert(near(m.panel.x, 0) and m.panel.x + m.panel.w < 220, "the column sits left of it")
assert(near(m.glass.x, 0) and near(m.glass.x + m.glass.w, 220 + 23), "the target's glass runs from the left edge under its portrait")
assert(near(m.badge.x + m.badge.w, 266), "the badge sits in the portrait's bottom right corner")
assert(near(m.health.x + m.health.w - (m.healthText.x + m.healthText.w), trackEnd - (g.healthText.x + g.healthText.w)), "the target's percentage still ends at the track's right end, as the player's does")

-- No portrait: the glass is the whole frame and the level moves into the name row.
local n = Geometry.Frame(base({ portrait = false }), 266, 46, 1)
assert(n.portrait == nil and n.badge == nil, "no portrait, no badge")
assert(near(n.panel.x, 0) and near(n.panel.w, 266), "the column spans the frame")
assert(near(n.glass.x, 0) and near(n.glass.y, 0) and near(n.glass.w, 266) and near(n.glass.h, 46), "without a portrait the glass is the whole frame")
assert(n.levelText and n.levelText.x >= n.name.x + n.name.w, "the level sits at the right of the name row")

-- A narrow frame keeps half its width for the bars.
local narrow = Geometry.Frame(base(), 60, 46, 1)
assert(near(narrow.portrait.w, 30), "the portrait never takes more than half the frame's width")

-- Switching parts off gives their room to the health track.
local noPower = Geometry.Frame(base({ healthText = "both", power = false }), 266, 46, 1)
assert(noPower.power == nil and noPower.powerText == nil and noPower.health.h > g.health.h, "no power bar: the track grows")
local noName = Geometry.Frame(base({ healthText = "both", name = false }), 266, 46, 1)
assert(noName.name == nil and noName.health.h > g.health.h, "no name row: the track grows")
local percentOnly = Geometry.Frame(base({ healthText = "percent", powerText = "none" }), 266, 46, 1)
assert(percentOnly.healthSub == nil and percentOnly.powerText == nil, "a percentage alone needs no row under the track")
assert(percentOnly.health.h > g.health.h and near(percentOnly.health.w, g.health.w), "without that row the track grows taller, never wider")
local noText = Geometry.Frame(base({ healthText = "none", powerText = "none" }), 266, 46, 1)
assert(noText.healthText == nil and noText.healthSub == nil and noText.powerText == nil, "no text")
assert(near(noText.health.w, g.health.w) and near(noText.power.w, noText.health.w), "the track's width never depends on its text")

-- Taller and wider frames scale the parts.
local big = Geometry.Frame(base({ healthText = "both" }), 400, 80, 1)
assert(near(big.portrait.w, 80) and big.health.h > g.health.h and big.health.w > g.health.w, "a bigger frame gets bigger parts")
local bigText = Geometry.Frame(base({ healthText = "both" }), 266, 46, 1.3)
assert(near(bigText.health.w, g.health.w), "a larger text size never takes width from the track")
assert(bigText.healthSub == nil and bigText.health.h >= math.ceil(11 * 1.3 * 0.85), "a larger text size drops the row under the track before the track gets too short for its text")

-- The compact frame: target of target, pet and focus target at 120 x 24.
local c = Geometry.Frame(base({ portrait = false, power = false, level = false }), 120, 24, 1)
assert(c.compact, "24 units tall is a compact frame")
assert(c.name and near(c.name.y, c.health.y) and near(c.name.h, c.health.h), "the name sits inside the health bar")
assert(c.healthText and c.healthText.x + c.healthText.w <= c.health.x + c.health.w + 1e-6, "the health text sits inside the bar, at its right")
assert(c.name.x + c.name.w <= c.healthText.x, "the name stops before the health text")
assert(near(c.health.y + c.health.h + c.health.y, 24), "without a power bar the health bar fills the height")
assert(c.healthSub == nil, "a compact frame has no row under its bar")
assert(near(c.glass.x, 0) and near(c.glass.w, 120) and near(c.glass.h, 24), "the compact glass is the whole frame")
local cp = Geometry.Frame(base({ portrait = true, power = true, powerHeight = 3, level = true }), 120, 24, 1)
assert(near(cp.portrait.w, 24) and cp.badge == nil, "a compact frame can have a portrait, but no level badge")
assert(cp.power and near(cp.power.h, 3) and cp.power.y > cp.health.y, "a compact frame can have a thin power bar")
assert(near(cp.glass.x, 12) and near(cp.glass.y, 0) and near(cp.glass.h, 24), "a compact glass runs under its portrait at the full height")

-- Big text never pushes a part out of the frame: the row under the track gives way first, then the name, and every text stays inside.
local crowded = Geometry.Frame(base({ healthText = "both", fonts = { name = { size = 32 }, health = { size = 11 }, power = { size = 9 }, level = { size = 9 } } }), 266, 46, 1)
for key, part in pairs(crowded) do
	if type(part) == "table" then
		assert(part.y >= 0 and part.y + part.h <= 46 + 1e-6, key .. " stays inside the frame")
	end
end
assert(crowded.health.h >= 2 and crowded.power and crowded.power.h == 5, "the bars keep their room")
local huge = Geometry.Frame(base({ healthText = "both", fonts = { name = { size = 32 }, health = { size = 32 }, power = { size = 32 }, level = { size = 32 } } }), 266, 46, 1)
for key, part in pairs(huge) do
	if type(part) == "table" then
		assert(part.y >= 0 and part.y + part.h <= 46 + 1e-6, "huge text: " .. key .. " stays inside the frame")
	end
end
assert(huge.health.h >= 2, "huge text: the track keeps some height")
local tall = Geometry.Frame(base({ powerHeight = 24 }), 266, 46, 1)
assert(tall.power.y + tall.power.h <= 46 + 1e-6 and tall.health.h >= 2, "a power bar taller than the room shrinks")

-- At the smallest width Layout allows, the bars keep the column's width and the texts stay apart.
for _, format in ipairs({ "percent", "currentMax", "both" }) do
	local small = Geometry.Frame(base({ healthText = format }), 120, 46, 1)
	assert(small.health.w > 0 and near(small.power.w, small.health.w), format .. ": the bars keep the column's width at 120 units")
	assert(small.healthText.x >= small.panel.x and small.healthText.x + small.healthText.w <= small.panel.x + small.panel.w + 1e-6, format .. ": the health text stays inside the column")
	if small.healthSub then
		assert(small.powerText.x + small.powerText.w <= small.healthSub.x + 1e-6, format .. ": the two texts under the track never overlap")
	end
end

-- No two texts overlap at any full-frame height Layout allows, with the default fonts or larger ones: the
-- track keeps room for its own text, and the row under it shows only when it fits whole. A glyph box is the
-- text's centre plus and minus 0.35 of its size, the cap height of the kit's fonts with a little room.
local function glyphs(r, size)
	return mid(r) - 0.35 * size, mid(r) + 0.35 * size
end
local function apart(a, sa, b, sb)
	local a1, a2 = glyphs(a, sa)
	local b1, b2 = glyphs(b, sb)
	return a2 <= b1 + 1e-6 or b2 <= a1 + 1e-6
end
local FONT_SETS = { { 11, 12, 9 }, { 11, 16, 9 }, { 12, 14, 10 }, { 14, 20, 12 }, { 9, 9, 8 }, { 16, 24, 14 } }
for _, sizes in ipairs(FONT_SETS) do
	local nameSize, healthSize, powerSize = sizes[1], sizes[2], sizes[3]
	for height = 36, 160 do
		local s = base({ healthText = "both", powerHeight = 3, fonts = { name = { size = nameSize }, health = { size = healthSize }, power = { size = powerSize }, level = { size = 9 } } })
		local f = Geometry.Frame(s, 266, height, 1)
		local where = "fonts " .. table.concat(sizes, "/") .. " at " .. height .. " units: "
		local t1, t2 = glyphs(f.healthText, healthSize)
		assert(t1 >= f.health.y - 1e-6 and t2 <= f.health.y + f.health.h + 1e-6, where .. "the health text fits inside its track")
		if f.healthSub then
			assert(apart(f.healthText, healthSize, f.healthSub, healthSize * Geometry.DETAIL_SHARE), where .. "the percentage and current and max never overlap")
		end
		if f.powerText then
			assert(f.healthSub or s.healthText ~= "both", where .. "the power text shows only with the row under the track")
			assert(apart(f.healthText, healthSize, f.powerText, powerSize), where .. "the health and power texts never overlap")
		end
		if f.name then
			assert(apart(f.name, nameSize, f.healthText, healthSize), where .. "the name and the health text never overlap")
		end
	end
end
local short = Geometry.Frame(base({ healthText = "both", powerHeight = 3, fonts = { name = { size = 11 }, health = { size = 12 }, power = { size = 9 }, level = { size = 9 } } }), 266, 36, 1)
assert(short.name and short.healthSub == nil and short.powerText == nil, "at 36 units the defaults keep the name and drop the row under the track")

-- A frame never gets a negative size, even far below the minimum.
local tiny = Geometry.Frame(base(), 10, 4, 1)
for _, part in pairs(tiny) do
	if type(part) == "table" then
		assert(part.w >= 0 and part.h >= 0, "no negative sizes")
	end
end

-- Boss slots: five frames stacked downward with gaps.
local slots = Geometry.Slots(5, 10, 266, 330)
assert(#slots == 5, "five slots")
assert(near(slots[1].y, 0) and near(slots[1].h, 58) and near(slots[2].y, 68) and near(slots[5].y + slots[5].h, 330), "58 units each, 10 apart")

-- Health text, for each format. Health is always secret; the stub raises on any comparison or arithmetic.
local text = env.CreateFrame("Frame"):CreateFontString(nil, "OVERLAY", "GameFontHighlight")
local function show(format, unit)
	Format.Health(text, unit or "player", format)
	return U.Shown(env, text)
end
assert(show("percent") == "78%", "percent: " .. show("percent"))
assert(show("current") == "3120", "current: " .. show("current"))
assert(show("currentMax") == "3120 / 3980", "current and max: " .. show("currentMax"))
assert(show("both") == "3120 / 3980  78%", "both: " .. show("both"))
assert(show("none") == "", "none")
env._units.player.dead = true
assert(show("percent") == K.L["Dead"], "a dead unit shows Dead")
env._units.player.dead, env._units.player.ghost = false, true
assert(show("percent") == K.L["Ghost"], "a ghost shows Ghost")
env._units.player.ghost, env._units.player.offline = false, true
assert(show("percent") == K.L["Offline"], "an offline unit shows Offline")
env._units.player.offline = false

-- Power text, with plain and secret values.
assert((function()
	Format.Power(text, "player", "currentMax")
	return U.Shown(env, text)
end)() == "2000 / 4000", "power current and max")
env._restricted = true
Format.Power(text, "player", "percent")
assert(U.Shown(env, text) == "50%", "a secret power percentage still shows: " .. U.Shown(env, text))
Format.Power(text, "player", "both")
assert(U.Shown(env, text) == "2000 / 4000  50%", "secret power, both")
env._restricted = false

-- A full frame splits "both": the percentage at the track's end, current and max under it.
assert(Format.Main("both") == "percent" and Format.Main("currentMax") == "currentMax" and Format.Main("none") == "none", "the text at the track's end")
local detail = env.CreateFrame("Frame"):CreateFontString(nil, "OVERLAY", "GameFontHighlight")
local function showDetail(format)
	Format.HealthDetail(detail, "player", format)
	return U.Shown(env, detail)
end
assert(showDetail("both") == "3120 / 3980", "both: current and max under the track: " .. showDetail("both"))
for _, format in ipairs({ "percent", "current", "currentMax", "none" }) do
	assert(showDetail(format) == "", format .. ": nothing under the track")
end
env._units.player.dead = true
assert(showDetail("both") == "", "a dead unit shows Dead once, at the track's end")
env._units.player.dead = false

-- Without a curve API the percentage falls back to current and max, and says so once in the devlog.
env.C_CurveUtil, env.CurveConstants = nil, nil
Format.ResetCurve()
assert(show("percent") == "3120 / 3980", "no curve: current and max instead of a wrong percentage")
assert(showDetail("both") == "", "no curve: current and max show once, not twice")

assert(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
print("unitframes geometry ok")
