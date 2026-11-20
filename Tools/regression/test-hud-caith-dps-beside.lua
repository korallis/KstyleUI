-- test-hud-caith-dps-beside.lua: Medallions DPS rows clear the complete HUD, maximum consumables and beside extra bars at four owner sizes and both arrangements.
dofile("Tools/regression/hud_reach_lib.lua").Run("medallions", "DPS", { 1, 4 }, "beside")
