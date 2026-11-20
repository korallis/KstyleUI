-- test-hud-caith-dps-rows-screens-3-4.lua: Medallions DPS rows clear the complete HUD, maximum consumables and rows extra bars at ultrawide and 4K and both arrangements.
dofile("Tools/regression/hud_reach_lib.lua").Run("medallions", "DPS", { 3, 4 }, "rows")
