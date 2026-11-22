-- test-ornament-surfaces-xp-f.lua: on the Tank and Healer HUDs at 1920x1080, the data bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.NoBarPieces(lib.Cases({ "Tank", "Healer" }, { "Subtle", "Full" }, { lib.SCREENS[3] }, { "databars", "actionbars" }), "data bars in Tank and Healer")
