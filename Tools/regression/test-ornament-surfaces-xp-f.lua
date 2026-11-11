-- test-ornament-surfaces-xp-f.lua: on the Tank and Healer HUDs at 1920x1080, the data bars' pieces keep 1 px of ink from all other content at Subtle and Full, and Full never draws a smaller end than Subtle.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.Run(lib.Cases({ "Tank", "Healer" }, { "Subtle", "Full" }, { lib.SCREENS[3] }, { "databars", "actionbars" }, "databars.", { "databars.xp" }), "data bars in Tank and Healer")
