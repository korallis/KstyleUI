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

-- The full frame at the 1080 reference: a 46-unit round portrait, then the glass panel with the bars.
local g = Geometry.Frame(base(), 266, 46, 1)
assert(not g.compact, "46 units tall is a full frame")
assert(near(g.portrait.x, 0) and near(g.portrait.y, 0) and near(g.portrait.w, 46) and near(g.portrait.h, 46), "the portrait is the frame's height, at the left")
assert(g.panel.x > 46 and near(g.panel.x + g.panel.w, 266) and near(g.panel.h, 46), "the panel fills the rest of the frame")
assert(g.name and g.name.y < g.health.y, "the name sits above the health bar")
assert(g.health.x > g.panel.x and g.health.y + g.health.h <= g.power.y, "the power bar sits under the health bar")
assert(near(g.healthText.x + g.healthText.w, g.power.x + g.power.w + Format.ColumnWidth("currentMax", 9) + Geometry.TEXT_GAP), "both texts end at the panel's inner edge")
assert(g.healthText.x >= g.health.x + g.health.w, "the health text sits right of the health bar")
assert(g.power.w < g.health.w, "current and max power takes more room than a percentage, so the power bar is shorter")
assert(g.powerText.x >= g.power.x + g.power.w, "the power text sits right of the power bar")
assert(near(g.power.h, 5), "the power bar is the chosen height")
assert(g.badge and g.badge.w >= 14, "the level badge is at least 14 units")
assert(near(g.badge.x, 0) and near(g.badge.y + g.badge.h, 46), "the badge sits in the portrait's bottom outer corner")
assert(g.levelText == nil, "the level shows in the badge, not in the name row")

-- Mirrored for the target.
local m = Geometry.Frame(base({ portraitSide = "RIGHT" }), 266, 46, 1)
assert(near(m.portrait.x, 220), "a right portrait sits at the right edge")
assert(near(m.panel.x, 0) and m.panel.x + m.panel.w < 220, "the panel sits left of it")
assert(near(m.badge.x + m.badge.w, 266), "the badge sits in the portrait's bottom right corner")

-- No portrait: the panel spans the frame and the level moves into the name row.
local n = Geometry.Frame(base({ portrait = false }), 266, 46, 1)
assert(n.portrait == nil and n.badge == nil, "no portrait, no badge")
assert(near(n.panel.x, 0) and near(n.panel.w, 266), "the panel spans the frame")
assert(n.levelText and n.levelText.x >= n.name.x + n.name.w, "the level sits at the right of the name row")

-- A narrow frame keeps half its width for the bars.
local narrow = Geometry.Frame(base(), 60, 46, 1)
assert(near(narrow.portrait.w, 30), "the portrait never takes more than half the frame's width")

-- Switching parts off gives their room to the health bar.
local noPower = Geometry.Frame(base({ power = false }), 266, 46, 1)
assert(noPower.power == nil and noPower.health.h > g.health.h, "no power bar: the health bar grows")
local noName = Geometry.Frame(base({ name = false }), 266, 46, 1)
assert(noName.name == nil and noName.health.h > g.health.h, "no name row: the health bar grows")
local noText = Geometry.Frame(base({ healthText = "none", powerText = "none" }), 266, 46, 1)
assert(noText.healthText == nil and noText.health.w > g.health.w and near(noText.power.w, noText.health.w), "no text: the bars fill the width")

-- Taller and wider frames scale the parts.
local big = Geometry.Frame(base(), 400, 80, 1)
assert(near(big.portrait.w, 80) and big.health.h > g.health.h and big.health.w > g.health.w, "a bigger frame gets bigger parts")
local bigText = Geometry.Frame(base(), 266, 46, 1.3)
assert(bigText.health.w < g.health.w, "a larger text size takes more room from the bars")

-- The compact frame: target of target, pet and focus target at 120 x 24.
local c = Geometry.Frame(base({ portrait = false, power = false, level = false }), 120, 24, 1)
assert(c.compact, "24 units tall is a compact frame")
assert(c.name and near(c.name.y, c.health.y) and near(c.name.h, c.health.h), "the name sits inside the health bar")
assert(c.healthText and c.healthText.x + c.healthText.w <= c.health.x + c.health.w + 1e-6, "the health text sits inside the bar, at its right")
assert(c.name.x + c.name.w <= c.healthText.x, "the name stops before the health text")
assert(near(c.health.y + c.health.h + c.health.y, 24), "without a power bar the health bar fills the height")
local cp = Geometry.Frame(base({ portrait = true, power = true, powerHeight = 3, level = true }), 120, 24, 1)
assert(near(cp.portrait.w, 24) and cp.badge == nil, "a compact frame can have a portrait, but no level badge")
assert(cp.power and near(cp.power.h, 3) and cp.power.y > cp.health.y, "a compact frame can have a thin power bar")

-- Big text never pushes a part out of the frame: the name row gives way first.
local crowded = Geometry.Frame(base({ fonts = { name = { size = 32 }, health = { size = 11 }, power = { size = 9 }, level = { size = 9 } } }), 266, 46, 1)
for key, part in pairs(crowded) do
	if type(part) == "table" and key ~= "powerText" then
		assert(part.y >= 0 and part.y + part.h <= 46 + 1e-6, key .. " stays inside the frame")
	end
end
assert(crowded.health.h >= 2 and crowded.power and crowded.power.h == 5, "the bars keep their room")
local tall = Geometry.Frame(base({ powerHeight = 24 }), 266, 46, 1)
assert(tall.power.y + tall.power.h <= 46 + 1e-6 and tall.health.h >= 2, "a power bar taller than the room shrinks")

-- At the smallest width Layout allows, text columns give way so the bars stay usable.
for _, format in ipairs({ "percent", "currentMax", "both" }) do
	local small = Geometry.Frame(base({ healthText = format }), 120, 46, 1)
	assert(small.health.w > 0 and small.power.w > 0, format .. ": the bars keep some width at 120 units")
	assert(small.healthText.x >= small.panel.x, format .. ": the health text stays inside the panel")
	assert(small.health.w >= (small.panel.w - 12) / 2 - Geometry.TEXT_GAP - 1e-6, format .. ": a text column takes at most half the panel")
end

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

-- Without a curve API the percentage falls back to current and max, and says so once in the devlog.
env.C_CurveUtil, env.CurveConstants = nil, nil
Format.ResetCurve()
assert(show("percent") == "3120 / 3980", "no curve: current and max instead of a wrong percentage")

assert(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
print("unitframes geometry ok")
