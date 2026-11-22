-- test-centre-clearance-tank-bear.lua: every occupied bear centre lane clears its neighbours after Tank Setup.Apply on eleven screens.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Tank", "DRUID", "bear")
