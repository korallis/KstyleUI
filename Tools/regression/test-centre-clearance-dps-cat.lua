-- test-centre-clearance-dps-cat.lua: every occupied cat centre lane clears its neighbours after DPS Setup.Apply on nine screens.
dofile("Tools/regression/centre_clearance_lib.lua").Run("DPS", "DRUID", "cat")
