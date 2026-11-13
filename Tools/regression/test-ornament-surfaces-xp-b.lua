-- test-ornament-surfaces-xp-b.lua: on the DPS HUD at 1920x1080 and 2560x1440, the data bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local s = lib.SCREENS
lib.NoBarPieces(lib.Cases({ "DPS" }, { "Subtle", "Full" }, { s[3], s[4] }, { "databars", "actionbars" }), "data bars at 1920x1080 and 2560x1440")
