-- test-ornament-surfaces-xp-j.lua: on the DPS HUD at 3840x2160 and 2383x1540 with Stormwind watched, the experience and reputation bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local cases = lib.Cases({ "DPS" }, { "Subtle", "Full" }, { lib.SCREENS[7], lib.SCREENS[8] }, { "databars", "actionbars" })
for _, case in ipairs(cases) do case.faction = true end
lib.NoBarPieces(cases, "data bars watching a faction at 3840x2160 and 2383x1540")
