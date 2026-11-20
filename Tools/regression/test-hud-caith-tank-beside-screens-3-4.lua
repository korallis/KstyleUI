-- test-hud-caith-tank-beside-screens-3-4.lua: Medallions Tank rows clear the complete HUD, maximum consumables and beside extra bars at ultrawide and 4K and both arrangements.
dofile("Tools/regression/hud_reach_lib.lua").Run("medallions", "Tank", { 3, 4 }, "beside")
