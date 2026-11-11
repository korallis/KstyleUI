-- test-ornament-surfaces-bars-states-b.lua: in every state of the databars_ornaments scene at 2560x1440, 3440x1440 and 5120x1440, the data bars' pieces keep 1 px of ink from all other content at Subtle and Full, the hovered reputation bar draws none, the reputation bar's rails lie flush on its border, and Full never draws a smaller end than Subtle.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.States({ lib.SCREENS[4], lib.SCREENS[5], lib.SCREENS[6] }, "at 2560x1440, 3440x1440 and 5120x1440")
