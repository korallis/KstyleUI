-- test-ornament-surfaces-minimap-subtle.lua: at Subtle the minimap's corners keep 1 px of ink from all other content in every preset on nine screens.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.Run(lib.Cases({ "DPS", "Tank", "Healer" }, { "Subtle" }, lib.SCREENS, { "minimap", "auras" }, "minimap.", { "minimap.map" }), "Subtle minimap")
