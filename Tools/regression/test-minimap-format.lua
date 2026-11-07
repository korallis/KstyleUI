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

-- The map is a square at the element's height, beside the button column.
local left, size = Format.MapRect(226, 196, "left")
check(left, 30, "the column on the left puts the map on the right")
check(size, 196, "the map is as tall as the element")
left, size = Format.MapRect(226, 196, "right")
check(left, 0, "the column on the right puts the map on the left")
check(size, 196, "the map is as tall as the element on either side")
left, size = Format.MapRect(150, 200, "left")
check(left, 0, "a narrow element puts the map at its left edge")
check(size, 150, "a narrow element keeps the map square at its width")

print("minimap format ok")
