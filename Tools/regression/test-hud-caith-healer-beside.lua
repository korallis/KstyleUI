-- test-hud-caith-healer-beside.lua: Medallions Healer rows clear the complete HUD, maximum consumables and beside extra bars at the first two owner sizes and both arrangements.
dofile("Tools/regression/hud_reach_lib.lua").Run("medallions", "Healer", { 1, 2 }, "beside")
