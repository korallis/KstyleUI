-- test-ornament-surfaces-xp-e.lua: on the DPS HUD at 3456x2234, the data bars' pieces keep 1 px of ink from all other content at Subtle and Full, and Full never draws a smaller end than Subtle.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.Run(lib.Cases({ "DPS" }, { "Subtle", "Full" }, { lib.SCREENS[9] }, { "databars", "actionbars" }, "databars.", { "databars.xp" }), "data bars at 3456x2234")
