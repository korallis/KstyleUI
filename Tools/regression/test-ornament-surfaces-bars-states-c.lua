-- test-ornament-surfaces-bars-states-c.lua: in every state of the databars_ornaments scene at 3840x2160, 2383x1540 and 3456x2234, the data bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full, and the hovered reputation bar shows its label's plate.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.States({ lib.SCREENS[7], lib.SCREENS[8], lib.SCREENS[9] }, "at 3840x2160, 2383x1540 and 3456x2234")
