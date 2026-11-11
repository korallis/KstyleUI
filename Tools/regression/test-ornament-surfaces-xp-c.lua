-- test-ornament-surfaces-xp-c.lua: on the DPS HUD at 3440x1440 and 5120x1440, the data bars' pieces keep 1 px of ink from all other content at Subtle and Full, and Full never draws a smaller end than Subtle.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local s = lib.SCREENS
lib.Run(lib.Cases({ "DPS" }, { "Subtle", "Full" }, { s[5], s[6] }, { "databars", "actionbars" }, "databars.", { "databars.xp" }), "data bars at 3440x1440 and 5120x1440")
