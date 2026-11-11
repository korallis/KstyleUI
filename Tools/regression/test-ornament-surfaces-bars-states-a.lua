-- test-ornament-surfaces-bars-states-a.lua: in every state of the databars_ornaments scene at 1280x720, 1366x768 and 1920x1080, the data bars' pieces keep 1 px of ink from all other content at Subtle and Full, the hovered reputation bar draws none, the reputation bar's rails lie flush on its border, and Full never draws a smaller end than Subtle.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.States({ lib.SCREENS[1], lib.SCREENS[2], lib.SCREENS[3] }, "at 1280x720, 1366x768 and 1920x1080")
