-- test-centre-clearance-healer-bear.lua: every occupied bear centre lane clears its neighbours after Healer Setup.Apply on nine screens.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Healer", "DRUID", "bear")
