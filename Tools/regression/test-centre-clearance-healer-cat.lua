-- test-centre-clearance-healer-cat.lua: every occupied cat centre lane clears its neighbours after Healer Setup.Apply on nine screens.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Healer", "DRUID", "cat")
