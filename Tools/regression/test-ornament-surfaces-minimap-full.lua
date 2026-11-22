-- test-ornament-surfaces-minimap-full.lua: at Full the minimap, a card since the overhaul (KSTY-44), draws no forged ornament piece in the DPS preset on every test screen: its corners are the card's brackets.
local lib = dofile("Tools/regression/surfaces_clearance_lib.lua")
lib.Bare(lib.Cases({ "DPS" }, { "Full" }, lib.SCREENS, { "minimap", "auras" }), "Full DPS minimap")
