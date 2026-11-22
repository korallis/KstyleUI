-- test-ornament-surfaces-xp-k.lua: on the DPS HUD at 3456x2234 with Stormwind watched, the experience and reputation bars, clean since the overhaul (KSTY-44 bible 3.4), draw no forged ornament piece at Subtle or Full.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
local cases = lib.Cases({ "DPS" }, { "Subtle", "Full" }, { lib.SCREENS[9] }, { "databars", "actionbars" })
for _, case in ipairs(cases) do case.faction = true end
lib.NoBarPieces(cases, "data bars watching a faction at 3456x2234")
