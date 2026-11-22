-- test-ornament-surfaces-xp-h.lua: on the DPS HUD at 1920x1080 and 2560x1440 with Stormwind watched, the experience and reputation bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local cases = lib.Cases({ "DPS" }, { "Subtle", "Full" }, { lib.SCREENS[3], lib.SCREENS[4] }, { "databars", "actionbars" })
for _, case in ipairs(cases) do case.faction = true end
lib.NoBarPieces(cases, "data bars watching a faction at 1920x1080 and 2560x1440")
