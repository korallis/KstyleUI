-- test-ornament-surfaces-xp-d.lua: on the DPS HUD at 3840x2160 and 2383x1540, the data bars' pieces keep 1 px of ink from all other content at Subtle and Full, and Full never draws a smaller end than Subtle.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local s = lib.SCREENS
lib.Run(lib.Cases({ "DPS" }, { "Subtle", "Full" }, { s[7], s[8] }, { "databars", "actionbars" }, "databars.", { "databars.xp" }), "data bars at 3840x2160 and 2383x1540")
