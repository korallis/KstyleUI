-- test-ornament-surfaces-xp-e.lua: on the DPS HUD at 3456x2234, the data bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.NoBarPieces(lib.Cases({ "DPS" }, { "Subtle", "Full" }, { lib.SCREENS[9] }, { "databars", "actionbars" }), "data bars at 3456x2234")
