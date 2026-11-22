-- test-centre-clearance-tank-rogue.lua: every occupied rogue centre lane clears its neighbours after Tank Setup.Apply on screens 1 to 6 (screens 7 to 11 are in test-centre-clearance-tank-rogue-screens-7-11.lua).
dofile("Tools/regression/centre_clearance_lib.lua").Run("Tank", "ROGUE", 1, 6)
