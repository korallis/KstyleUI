-- test-hud-caith-dps-off.lua: Medallions DPS rows clear the complete HUD, maximum consumables and off extra bars at four owner sizes and both arrangements.
dofile("Tools/regression/hud_reach_lib.lua").Run("medallions", "DPS", { 1, 4 }, "off")
