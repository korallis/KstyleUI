-- test-minimap-format.lua: the minimap's pure helpers: coordinates, clock text, zone colours, wheel zoom steps and the map's place in its element.
local Stubs = dofile("Tools/regression/stubs/wow.lua")
local Load = dofile("Tools/regression/load_files.lua")

local env = Stubs.NewEnv()
env.KstyleUI = { L = setmetatable({}, { __index = function(_, key) return key end }) }
Load({ "KstyleUI_Minimap/Init.lua", "KstyleUI_Minimap/Format.lua" }, env)
local Format = env._addons.KstyleUI_Minimap.Format
assert(type(Format) == "table", "Format.lua must set ns.Format")

local function check(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

-- Coordinates are map fractions shown as percentages, with 0, 1 or 2 decimals.
check(Format.Coords(0.4532, 0.6218, 0), "45, 62", "whole numbers")
check(Format.Coords(0.4532, 0.6218, 1), "45.3, 62.2", "tenths")
check(Format.Coords(0.4532, 0.6218, 2), "45.32, 62.18", "hundredths")
check(Format.Coords(0.455, 0.0049, 0), "46, 0", "whole numbers round half up")
check(Format.Coords(0.4532, 0.6218, 7), "45.3, 62.2", "an unknown precision falls back to tenths")
check(Format.Coords(nil, 0.5, 1), nil, "a missing x gives no text")
check(Format.Coords(0.5, "0.5", 1), nil, "a string y gives no text")
check(Format.Coords(0 / 0, 0.5, 1), nil, "NaN gives no text")
check(Format.Coords(env.Secret(0.5), 0.5, 1), nil, "a secret x gives no text")

-- The clock: 24-hour with leading zeros, or 12-hour with AM and PM.
check(Format.Time(14, 32, true), "14:32", "24-hour afternoon")
check(Format.Time(9, 5, true), "09:05", "24-hour morning keeps the leading zeros")
check(Format.Time(14, 32, false), "2:32 PM", "12-hour afternoon")
check(Format.Time(0, 7, false), "12:07 AM", "midnight is 12 AM")
check(Format.Time(12, 0, false), "12:00 PM", "noon is 12 PM")
check(Format.Time(env.Secret(3), 0, true), nil, "a secret hour gives no text")
check(Format.Time(25, 0, true), nil, "an hour out of range gives no text")

-- Zone text colours: plain, the accent, or Blizzard's PvP meaning mapped onto KstyleUI's tokens.
check(Format.ZoneToken("hostile", "plain"), "textEmphasis", "plain ignores the zone type")
check(Format.ZoneToken("hostile", "accent"), "accent", "accent follows the accent")
check(Format.ZoneToken("hostile", "pvp"), "hostile", "hostile zones")
check(Format.ZoneToken("arena", "pvp"), "hostile", "free-for-all zones read as hostile")
check(Format.ZoneToken("combat", "pvp"), "hostile", "combat zones read as hostile")
check(Format.ZoneToken("friendly", "pvp"), "friendly", "friendly zones")
check(Format.ZoneToken("contested", "pvp"), "neutral", "contested zones")
check(Format.ZoneToken("sanctuary", "pvp"), "rare", "sanctuaries use the cool blue")
check(Format.ZoneToken(nil, "pvp"), "textEmphasis", "a zone with no PvP type")
check(Format.ZoneToken(env.Secret("hostile"), "pvp"), "textEmphasis", "a secret zone type is never compared")

-- Wheel zoom moves one level and stops at either end.
check(Format.NextZoom(2, 6, 1), 3, "wheel up zooms in")
check(Format.NextZoom(3, 6, -1), 2, "wheel down zooms out")
check(Format.NextZoom(5, 6, 1), nil, "no zoom past the last level")
check(Format.NextZoom(0, 6, -1), nil, "no zoom below 0")
check(Format.NextZoom(9, 6, -1), 4, "a zoom past the end steps down from the last level")
check(Format.NextZoom(9, 6, 1), 5, "a zoom past the end comes back to the last level")
check(Format.NextZoom(2, 6, 0), nil, "no wheel movement, no zoom")
check(Format.NextZoom(env.Secret(2), 6, 1), nil, "a secret zoom is never compared")
check(Format.NextZoom(2, nil, 1), nil, "no zoom levels, no zoom")

-- The zoom slider: the filled share of the track for a zoom level, and the level a share of the track means.
check(Format.ZoomShare(0, 6), 0, "zoom 0 is an empty track")
check(Format.ZoomShare(5, 6), 1, "the last level fills the track")
check(Format.ZoomShare(2, 6), 0.4, "a middle level fills its share")
check(Format.ZoomShare(9, 6), 1, "a zoom past the end reads as full")
check(Format.ZoomShare(2, 1), 0, "one level is no zoom at all")
check(Format.ZoomShare(env.Secret(2), 6), nil, "a secret zoom gives no share")
check(Format.ZoomShare(2, nil), nil, "no zoom levels, no share")
check(Format.ZoomAt(0.62, 6), 3, "a share of the track rounds to the nearest level")
check(Format.ZoomAt(0, 6), 0, "the bottom is zoom 0")
check(Format.ZoomAt(1.5, 6), 5, "past the top clamps to the last level")
check(Format.ZoomAt(-0.2, 6), 0, "below the bottom clamps to 0")
check(Format.ZoomAt(0.5, 1), 0, "one level is always 0")
check(Format.ZoomAt(env.Secret(0.5), 6), nil, "a secret share gives no level")
check(Format.ZoomAt(0.5, nil), nil, "no zoom levels, no level")

-- The lens: the largest circle that fits the card's width inside its inset and the room between the head and
-- the foot, centred under the head. Head and foot are fixed card bands.
local function near(a, b, what)
	assert(math.abs(a - b) < 1e-6, what .. ": want " .. tostring(b) .. ", got " .. tostring(a))
end
-- The card is the lens plus its foot: the lens sits a rim inside the card's top and sides, as the mockup's
-- round map nearly fills its glass, and the foot carries the zone and the clock under it. No head band: the
-- north mark sits on the lens's top edge.
check(Format.RIM, 6, "the rim between the card's edge and the lens")
check(Format.FOOT, 34, "the foot band, for the zone and the clock")
local left, top, lens = Format.Lens(318, 326, 6, 34)
near(lens, 326 - 6 - 34, "on the Lumen card the lens is limited by the height: the room between the rim and the foot")
near(left, (318 - lens) / 2, "and centred across the card")
near(top, 6, "a rim under the card's top")
local narrowLeft, narrowTop, narrowLens = Format.Lens(200, 400, 6, 34)
near(narrowLens, 200 - 2 * 6, "a narrow card limits the lens by its width inside the rim")
near(narrowLeft, 6, "so the lens starts at the rim")
near(narrowTop, 6 + (400 - 6 - 34 - narrowLens) / 2, "and sits in the middle of the room over the foot")
local _, _, tinyLens = Format.Lens(30, 30, 6, 34)
near(tinyLens, 0, "a card too small for the rim and the foot has no lens, never a negative one")

-- Rim buttons: each button's centre sits on the lens circle, spaced one button and one gap apart along the
-- arc, starting on the upper right (or upper left) and going down, or from the lower end and going up.
local step = Format.ArcStep(22, 7, 100)
near(step * 100, 29, "the step along a 100 radius covers one 22 button and a 7 gap")
local ax, ay = Format.Arc(1, 22, 7, 100, "right", false)
assert(ax > 0 and ay > 0, "the first button is on the upper right")
near(math.sqrt(ax * ax + ay * ay), 100, "on the circle")
local ax2, ay2 = Format.Arc(2, 22, 7, 100, "right", false)
assert(ax2 > 0 and ay2 < ay, "the second is further round and lower")
near(math.atan2(ay, ax) - math.atan2(ay2, ax2), step, "one step apart along the arc")
local lx = Format.Arc(1, 22, 7, 100, "left", false)
near(lx, -ax, "the left side mirrors the right")
local upX, upY = Format.Arc(1, 22, 7, 100, "right", true)
near(upX, ax, "growing up starts at the mirror of the first slot, below the middle")
near(upY, -ay, "below the middle")
local ix = Format.Arc(1, 22, 7, 100, "inside", false)
near(ix, ax, "the old inside strip reads as the right side")
near(Format.ARC_START, math.rad(52), "the arc starts 52 degrees above the horizontal, where the mockup's first disc sits")

-- The drawer: which way it opens, where each icon sits, and how big the drawer is.
check(Format.Direction("auto", "right"), "left", "with the rim buttons on the lens's right, where the card meets the screen's edge, the drawer opens inward, over the lens")
check(Format.Direction("auto", "left"), "right", "and on the left, to the right")
check(Format.Direction("auto", "inside"), "left", "the old inside strip reads as the right side")
check(Format.Direction("up", "left"), "up", "a chosen direction wins")
check(Format.Direction("sideways", "right"), "left", "an unknown direction opens inward")

local point, x, y = Format.Grid(1, 6, 24, 4, "left", 4)
check(point, "TOPRIGHT", "a drawer opening left fills from its top right")
check(x, -4, "the first icon sits one padding in")
check(y, -4, "and one padding down")
point, x, y = Format.Grid(8, 6, 24, 4, "left", 4)
check(point, "TOPRIGHT", "every icon of a left drawer counts from the top right")
check(x, -(4 + 28), "the eighth of six per row is the second in its row")
check(y, -(4 + 28), "on the second row")
point, x, y = Format.Grid(2, 6, 24, 4, "right", 4)
check(point, "TOPLEFT", "a drawer opening right fills from its top left")
check(x, 4 + 28, "rightward")
check(y, -4, "first row")
point, x, y = Format.Grid(7, 3, 20, 2, "up", 3)
check(point, "BOTTOMLEFT", "a drawer opening up fills from its bottom left")
check(x, 3, "first column")
check(y, 3 + 2 * 22, "third row, upward")
point = Format.Grid(1, 0, 20, 2, "down", 3)
check(point, "TOPLEFT", "a drawer opening down fills from its top left")

local w, h = Format.GridSize(8, 6, 24, 4, 4)
check(w, 4 + 6 * 24 + 5 * 4 + 4, "a full row sets the width")
check(h, 4 + 2 * 24 + 4 + 4, "two rows set the height")
w, h = Format.GridSize(2, 6, 24, 4, 4)
check(w, 4 + 2 * 24 + 4 + 4, "a short row is only as wide as its icons")
check(h, 4 + 24 + 4, "one row")
w, h = Format.GridSize(0, 6, 24, 4, 4)
check(w, 0, "an empty drawer has no width")
check(h, 0, "and no height")

local anchor, relative, xs, ys = Format.DrawerAnchor("left")
check(anchor .. relative .. xs .. ys, "TOPRIGHTTOPLEFT-10", "opening left hangs the drawer's top right on the button's top left")
anchor, relative, xs, ys = Format.DrawerAnchor("down")
check(anchor .. relative .. xs .. ys, "TOPLEFTBOTTOMLEFT0-1", "opening down hangs it under the button")
anchor, relative, xs, ys = Format.DrawerAnchor("up")
check(anchor .. relative .. xs .. ys, "BOTTOMLEFTTOPLEFT01", "opening up stands it on the button")

print("minimap format ok")
