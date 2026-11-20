-- test-hud-caith-healer-rows-screens-3-4.lua: Medallions Healer rows clear the complete HUD, maximum consumables and rows extra bars at ultrawide and 4K and both arrangements.
dofile("Tools/regression/hud_reach_lib.lua").Run("medallions", "Healer", { 3, 4 }, "rows")
