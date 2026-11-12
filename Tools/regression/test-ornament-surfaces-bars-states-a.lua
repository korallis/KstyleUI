-- test-ornament-surfaces-bars-states-a.lua: in every state of the databars_ornaments scene at 1280x720, 1366x768 and 1920x1080, the data bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full, and the hovered reputation bar shows its label's plate.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.States({ lib.SCREENS[1], lib.SCREENS[2], lib.SCREENS[3] }, "at 1280x720, 1366x768 and 1920x1080")
