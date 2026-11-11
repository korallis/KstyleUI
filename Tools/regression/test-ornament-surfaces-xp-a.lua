-- test-ornament-surfaces-xp-a.lua: on the DPS HUD at 1280x720 and 1366x768, the data bars' pieces keep 1 px of ink from all other content at Subtle and Full, and Full never draws a smaller end than Subtle.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local s = lib.SCREENS
lib.Run(lib.Cases({ "DPS" }, { "Subtle", "Full" }, { s[1], s[2] }, { "databars", "actionbars" }, "databars.", { "databars.xp" }), "data bars at 1280x720 and 1366x768")
