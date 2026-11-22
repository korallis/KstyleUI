-- test-centre-clearance-dps-cat-screens-7-11.lua: every occupied cat centre lane clears its neighbours after DPS Setup.Apply on screens 7 to 11.
dofile("Tools/regression/centre_clearance_lib.lua").Run("DPS", "DRUID", "cat", 7, 11)
