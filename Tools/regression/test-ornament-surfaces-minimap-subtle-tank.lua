-- test-ornament-surfaces-minimap-subtle-tank.lua: at Subtle the minimap, a card since the overhaul (KSTY-44), draws no forged ornament piece in the Tank preset on every test screen: its corners are the card's brackets.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.Bare(lib.Cases({ "Tank" }, { "Subtle" }, lib.SCREENS, { "minimap", "auras" }), "Subtle Tank minimap")
