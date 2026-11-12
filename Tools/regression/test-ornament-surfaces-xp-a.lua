-- test-ornament-surfaces-xp-a.lua: on the DPS HUD at 1280x720 and 1366x768, the data bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local s = lib.SCREENS
lib.NoBarPieces(lib.Cases({ "DPS" }, { "Subtle", "Full" }, { s[1], s[2] }, { "databars", "actionbars" }), "data bars at 1280x720 and 1366x768")
