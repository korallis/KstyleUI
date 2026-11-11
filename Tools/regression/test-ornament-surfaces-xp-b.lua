-- test-ornament-surfaces-xp-b.lua: on the DPS HUD at 1920x1080 and 2560x1440, the data bars' pieces keep 1 px of ink from all other content at Subtle and Full, and Full never draws a smaller end than Subtle.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local s = lib.SCREENS
lib.Run(lib.Cases({ "DPS" }, { "Subtle", "Full" }, { s[3], s[4] }, { "databars", "actionbars" }, "databars.", { "databars.xp" }), "data bars at 1920x1080 and 2560x1440")
