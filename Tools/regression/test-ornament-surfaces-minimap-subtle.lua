-- test-ornament-surfaces-minimap-subtle.lua: at Subtle the minimap, a card since the overhaul (KSTY-44), draws no forged ornament piece in any preset on nine screens: its corners are the card's brackets.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.Bare(lib.Cases({ "DPS", "Tank", "Healer" }, { "Subtle" }, lib.SCREENS, { "minimap", "auras" }), "Subtle minimap")
