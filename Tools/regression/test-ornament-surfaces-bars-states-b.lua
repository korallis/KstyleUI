-- test-ornament-surfaces-bars-states-b.lua: in every state of the databars_ornaments scene at 2560x1440, 3440x1440 and 5120x1440, the data bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full, and the hovered reputation bar shows its label's plate.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.States({ lib.SCREENS[4], lib.SCREENS[5], lib.SCREENS[6] }, "at 2560x1440, 3440x1440 and 5120x1440")
