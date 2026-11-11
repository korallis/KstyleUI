-- test-ornament-surfaces-minimap-full.lua: at Full the minimap's corners, point and plaque keep 1 px of ink from all other content in every preset on nine screens.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.Run(lib.Cases({ "DPS", "Tank", "Healer" }, { "Full" }, lib.SCREENS, { "minimap", "auras" }, "minimap.", { "minimap.map", "minimap.plaque" }), "Full minimap")
