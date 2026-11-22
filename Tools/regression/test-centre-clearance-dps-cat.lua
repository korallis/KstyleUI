-- test-centre-clearance-dps-cat.lua: every occupied cat centre lane clears its neighbours after DPS Setup.Apply on screens 1 to 6 (screens 7 to 11 are in test-centre-clearance-dps-cat-screens-7-11.lua).
dofile("Tools/regression/centre_clearance_lib.lua").Run("DPS", "DRUID", "cat", 1, 6)
