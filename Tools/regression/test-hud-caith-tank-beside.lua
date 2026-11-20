-- test-hud-caith-tank-beside.lua: Medallions Tank rows clear the complete HUD, maximum consumables and beside extra bars at the first two owner sizes and both arrangements.
dofile("Tools/regression/hud_reach_lib.lua").Run("medallions", "Tank", { 1, 2 }, "beside")
