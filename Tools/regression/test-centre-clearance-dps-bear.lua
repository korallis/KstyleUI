-- test-centre-clearance-dps-bear.lua: every occupied bear centre lane clears its neighbours after DPS Setup.Apply on nine screens.
dofile("Tools/regression/centre_clearance_lib.lua").Run("DPS", "DRUID", "bear")
