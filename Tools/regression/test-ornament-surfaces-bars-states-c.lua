-- test-ornament-surfaces-bars-states-c.lua: in every state of the databars_ornaments scene at 3840x2160, 2383x1540 and 3456x2234, the data bars' pieces keep 1 px of ink from all other content at Subtle and Full, the hovered reputation bar draws none, the reputation bar's rails lie flush on its border, and Full never draws a smaller end than Subtle.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.States({ lib.SCREENS[7], lib.SCREENS[8], lib.SCREENS[9] }, "at 3840x2160, 2383x1540 and 3456x2234")
