-- test-unitframes-lumen.lua: every frame takes the Medallions slab with the classic plate as a choice; the Lumen geometry of the vitals line, the sigil, the cards and the compact pill rows, which the frames no longer draw, keeps its shapes.
local U = dofile("Tools/regression/unitframes_env.lua")

local env, K, ns = U.New({ lumen = true })
K.Options.Write("UnitFrames", "player.powerSeparate", false)
local Settings, Geometry = ns.Settings, ns.Geometry

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function mid(r)
	return r.y + r.h / 2
end

local function inside(part, w, h, what)
	assert(part.x >= -1e-6 and part.y >= -1e-6 and part.x + part.w <= w + 1e-6 and part.y + part.h <= h + 1e-6, what .. " stays inside the frame")
end

noErrors("enable")

-- Every frame draws the Medallions slab; the classic plate stays a choice.
for _, kind in ipairs(Settings.KINDS) do
	assert(Settings.Form(kind) == "slab" and Settings.Snapshot(kind).form == "slab", kind .. " takes the Medallions slab, got " .. tostring(Settings.Form(kind)))
end
K.Options.Write("UnitFrames", "pet.style", "plate")
assert(Settings.Form("pet") == "plate", "the classic plate is a choice")
K.Options.Write("UnitFrames", "pet.style", "nonsense")
assert(Settings.Form("pet") == "slab", "a value that is not a choice falls back to the slab")
K.Options.Write("UnitFrames", "pet.style", "lumen")
assert(Settings.Value("player", "powerColor") == "power", "power bars keep the power type's colour")
assert(Settings.Value("player", "portraitShape") == "round", "portraits stay round by default")

local function lumen(form, overrides)
	local s = {
		form = form, portrait = true, portraitSide = "LEFT", level = true, name = true, power = true, powerHeight = 5,
		healthText = "both", powerText = "none", castbar = true,
		fonts = { name = { size = 17 }, health = { size = 15 }, power = { size = 10 }, level = { size = 12 } },
	}
	for k, v in pairs(overrides or {}) do
		s[k] = v
	end
	return s
end

-- The vitals line at its Lumen footprint, 490 by 80: a 62-unit ring at the left with the level disc on its lower
-- right, then one column: the name and the health value on one row, a 12-unit health pill, a 5-unit power pill, its
-- foot level with the ring's, and the cast line under it all.
local v = Geometry.Frame(lumen("vitals"), 490, 80, 1)
assert(v.form == "vitals" and not v.compact and v.chrome == false, "the vitals line is a full frame with no glass of its own")
assert(near(v.portrait.x, 0) and near(v.portrait.y, 0) and near(v.portrait.w, 62) and near(v.portrait.h, 62), "the ring is 62 units at the top left")
local disc = v.badge
assert(disc and near(disc.w, disc.h) and disc.w >= 20 and disc.w <= 24, "the level disc is about 22 units, got " .. tostring(disc and disc.w))
assert(disc.x + disc.w > 62 and disc.y + disc.h > 62 and disc.x > 31 and disc.y > 31, "the disc sits on the ring's lower right, standing a little past it")
assert(near(v.health.h, 12) and near(v.power.h, 5), "a 12-unit health pill over a 5-unit power pill")
assert(near(v.power.y + v.power.h, 62, 0.5), "the power pill's foot is level with the ring's")
assert(v.power.y >= v.health.y + v.health.h + 3 and v.power.y <= v.health.y + v.health.h + 5, "4 units between the two pills")
assert(near(v.health.x, v.power.x) and near(v.health.w, v.power.w), "both pills span the column")
local col = v.health.x
assert(col > 62 + 10 and col < 62 + 22, "the column starts about 16 units past the ring, got " .. col)
assert(near(v.health.x + v.health.w, 490), "and runs to the frame's right edge")
assert(v.name and v.name.y + v.name.h <= v.health.y - 4, "the name sits over the health pill")
assert(near(v.name.x, col), "the name starts the column")
assert(v.healthSub and near(v.healthSub.x + v.healthSub.w, 490), "the max ends at the column's right edge")
assert(v.healthText.x + v.healthText.w <= v.healthSub.x + 1e-6, "the current value sits before the max")
assert(near(v.healthText.y + v.healthText.h, v.name.y + v.name.h, 1) and near(v.healthSub.y + v.healthSub.h, v.name.y + v.name.h, 1), "the values share the name's row, on its baseline")
assert(v.caption and v.caption.x >= v.name.x, "a stance or spec caption follows the name")
assert(v.cast and near(v.cast.x, col) and near(v.cast.x + v.cast.w, 490) and v.cast.y >= 62, "the cast line runs under the column, below the ring")
assert(v.cast.h >= 10 and v.cast.h <= 14 and near(v.cast.y + v.cast.h, 80) and v.cast.y >= v.power.y + v.power.h + 5, "a thin line at the frame's foot, clear of the power pill")
for key, part in pairs(v) do
	if type(part) == "table" and part.w and key ~= "badge" then
		inside(part, 490, 80, "vitals " .. key)
	end
end
local noCast = Geometry.Frame(lumen("vitals", { castbar = false }), 490, 80, 1)
assert(noCast.cast == nil and noCast.portrait.h > 62, "without the cast line the ring takes the room")
local narrow = Geometry.Frame(lumen("vitals"), 220, 70, 1)
assert(narrow.caption == nil and narrow.name.w > 0, "a narrow vitals line drops the caption and gives the name a fixed width to cut it short")
for key, part in pairs(narrow) do
	if type(part) == "table" and part.w and key ~= "badge" then
		inside(part, 220, 70, "narrow vitals " .. key)
		assert(part.w >= 0 and part.h >= 0, "no negative sizes")
	end
end
local bare = Geometry.Frame(lumen("vitals", { portrait = false }), 490, 80, 1)
assert(bare.portrait == nil and bare.badge == nil and near(bare.health.x, 0), "without the portrait the column takes the whole line")

-- The sigil at 640 units: centred name, the level line under it, a clean 12-unit pill with no gems (KSTY-60 item 1).
local t = Geometry.Frame(lumen("sigil", { fonts = { name = { size = 20 }, health = { size = 12 }, power = { size = 10 }, level = { size = 13 } } }), 640, 80, 1)
assert(t.form == "sigil" and t.chrome == false and t.portrait == nil and t.badge == nil and t.power == nil, "the sigil is text and one pill: no glass, portrait, badge or power")
assert(near(t.name.x, 0) and near(t.name.w, 640), "the name row spans the sigil, centred")
assert(t.caption and t.caption.y >= t.name.y + t.name.h - 1e-6 and near(t.caption.w, 640), "the level line is under the name, centred")
assert(near(t.health.h, 12) and t.health.y > t.caption.y + t.caption.h, "the 12-unit pill is under the level line")
assert(t.gemLeft == nil and t.gemRight == nil, "no gems close the pill")
assert(near(t.health.x, 0) and near(t.health.w, 640), "the pill runs the sigil's whole width")
assert(t.healthText == nil, "the sigil shows no numbers, as the mockup")
assert(t.cast and t.cast.y > t.health.y + t.health.h and near(t.cast.x + t.cast.w / 2, 320), "the target's cast line is centred under the pill")
for key, part in pairs(t) do
	if type(part) == "table" and part.w then
		inside(part, 640, 80, "sigil " .. key)
	end
end
local squeezed = Geometry.Frame(lumen("sigil", { fonts = { name = { size = 20 }, health = { size = 12 }, power = { size = 10 }, level = { size = 13 } } }), 640, 72, 1)
assert(squeezed.cast and squeezed.cast.y + squeezed.cast.h <= 72 + 1e-6 and squeezed.cast.y >= squeezed.health.y + squeezed.health.h, "a short sigil closes its gaps first and keeps the cast line")
assert(Geometry.Frame(lumen("sigil"), 640, 50, 1).cast == nil, "a sigil too short for its cast line leaves it out")

-- The card: a section cap, the name with the percentage, a pill and the cast line, with no glass card round them (KSTY-60 item 1).
local c = Geometry.Frame(lumen("card", { power = false, fonts = { name = { size = 16 }, health = { size = 14 }, power = { size = 9 }, level = { size = 12 } } }), 318, 120, 1)
assert(c.form == "card" and c.chrome == false, "the card wears no glass")
assert(near(c.glass.x, 0) and near(c.glass.w, 318) and near(c.glass.h, 120), "the glass is the whole card")
assert(c.cap and c.capGem and c.capLabel and near(mid(c.capGem), mid(c.cap)), "a section cap: the gem on the cap's middle, then the label")
assert(c.capGem.x >= 12 and c.capLabel.x > c.capGem.x + c.capGem.w, "inside the card's padding, label after the gem")
assert(c.caption and near(c.caption.x + c.caption.w, c.cap.x + c.cap.w) and near(mid(c.caption), mid(c.cap)), "the classification at the cap's right")
assert(c.name.y > c.cap.y + c.cap.h and c.healthText and near(mid(c.healthText), mid(c.name), 1), "the name under the cap, the percentage on its row")
assert(c.name.x + c.name.w <= c.healthText.x + 1e-6, "the name stops before the percentage")
assert(c.health.y > c.name.y + c.name.h - 1e-6 and c.health.h >= 8 and c.health.h <= 12, "a 10-unit pill under the name")
assert(c.power == nil, "no power pill unless it is on")
assert(c.cast and c.cast.y > c.health.y + c.health.h and near(c.cast.x, c.health.x) and near(c.cast.w, c.health.w), "the cast line under the pill, as wide")
assert(c.cast.y + c.cast.h <= 120 - 10, "the card keeps its bottom padding")
assert(c.portrait == nil and c.badge == nil, "the card has no portrait")
for _, h in ipairs({ 24, 40, 60, 80, 100 }) do
	local short = Geometry.Frame(lumen("card", { power = true, powerHeight = 4 }), 318, h, 1)
	for key, part in pairs(short) do
		if type(part) == "table" and part.w then
			inside(part, 318, h, "a " .. h .. "-unit card's " .. key)
		end
	end
	assert(short.health and short.health.h > 0, "a " .. h .. "-unit card keeps its pill")
end
local cp = Geometry.Frame(lumen("card", { power = true, powerHeight = 4 }), 318, 120, 1)
assert(cp.power and cp.power.y > cp.health.y + cp.health.h and near(cp.power.h, 4), "with power on, a thin power pill under the health pill")

-- The compact row: the name and the percentage on one line over a 6-unit pill, no glass.
local r = Geometry.Frame(lumen("row", { portrait = false, power = false, healthText = "percent", fonts = { name = { size = 12 }, health = { size = 12 }, power = { size = 9 }, level = { size = 10 } } }), 88, 22, 1)
assert(r.form == "row" and r.compact and r.chrome == false, "a row is compact, with no glass")
assert(near(r.health.h, 6) and near(r.health.y + r.health.h, 22) and near(r.health.w, 88), "a 6-unit pill across the row's foot")
assert(r.name and near(r.name.x, 0) and r.name.y + r.name.h <= r.health.y + 1e-6, "the name over the pill")
assert(r.healthText and near(r.healthText.x + r.healthText.w, 88) and r.name.x + r.name.w <= r.healthText.x + 1e-6, "the percentage at the right, after the name")
assert(r.portrait == nil and r.badge == nil and r.cast == nil, "no portrait, badge or cast line")

-- The classic plate is unchanged: a full frame with its glass.
local plate = Geometry.Frame(lumen("plate"), 220, 70, 1)
assert(plate.form == "plate" and plate.chrome == true and plate.glass.x > 0 and plate.cast == nil, "the plate keeps its glass under the portrait")
noErrors("geometry")

print("unitframes lumen ok")
