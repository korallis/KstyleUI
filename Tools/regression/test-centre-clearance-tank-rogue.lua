-- test-centre-clearance-tank-rogue.lua: every occupied rogue centre lane clears its neighbours after Tank Setup.Apply on nine screens.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Tank", "ROGUE")
