-- test-ornament-surfaces-xp-d.lua: on the DPS HUD at 3840x2160 and 2383x1540, the data bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local s = lib.SCREENS
lib.NoBarPieces(lib.Cases({ "DPS" }, { "Subtle", "Full" }, { s[7], s[8] }, { "databars", "actionbars" }), "data bars at 3840x2160 and 2383x1540")
