-- test-hud-caith-dps-rows.lua: Medallions DPS rows clear the complete HUD, maximum consumables and rows extra bars at the first two owner sizes and both arrangements.
dofile("Tools/regression/hud_reach_lib.lua").Run("medallions", "DPS", { 1, 2 }, "rows")
