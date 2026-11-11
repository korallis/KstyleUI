-- test-ornament-surfaces-xp-j.lua: on the DPS HUD at 3840x2160 and 2383x1540 with Stormwind watched, the experience and reputation bars' pieces keep 1 px of ink from all other content at Subtle and Full, and Full never draws a smaller end or fewer rails than Subtle except where a piece drawn only at Full (the tray) takes the place.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local cases = lib.Cases({ "DPS" }, { "Subtle", "Full" }, { lib.SCREENS[7], lib.SCREENS[8] }, { "databars", "actionbars" }, "databars.", { "databars.xp" })
for _, case in ipairs(cases) do case.faction = true end
lib.Run(cases, "data bars watching a faction at 3840x2160 and 2383x1540")
