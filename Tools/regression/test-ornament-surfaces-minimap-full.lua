-- test-ornament-surfaces-minimap-full.lua: at Full the minimap, a card since the overhaul (KSTY-44), draws no forged ornament piece in any preset on nine screens: its corners are the card's brackets.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.Bare(lib.Cases({ "DPS", "Tank", "Healer" }, { "Full" }, lib.SCREENS, { "minimap", "auras" }), "Full minimap")
