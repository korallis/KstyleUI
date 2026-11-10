-- test-centre-clearance-tank-cat.lua: every occupied cat centre lane clears its neighbours after Tank Setup.Apply on nine screens.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Tank", "DRUID", "cat")
