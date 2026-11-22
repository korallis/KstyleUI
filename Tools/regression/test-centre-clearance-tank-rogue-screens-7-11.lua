-- test-centre-clearance-tank-rogue-screens-7-11.lua: every occupied rogue centre lane clears its neighbours after Tank Setup.Apply on screens 7 to 11.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Tank", "ROGUE", 7, 11)
