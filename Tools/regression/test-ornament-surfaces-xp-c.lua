-- test-ornament-surfaces-xp-c.lua: on the DPS HUD at 3440x1440 and 5120x1440, the data bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local s = lib.SCREENS
lib.NoBarPieces(lib.Cases({ "DPS" }, { "Subtle", "Full" }, { s[5], s[6] }, { "databars", "actionbars" }), "data bars at 3440x1440 and 5120x1440")
