-- test-centre-clearance-healer-rogue-screens-7-11.lua: every occupied rogue centre lane clears its neighbours after Healer Setup.Apply on screens 7 to 11.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Healer", "ROGUE", 7, 11)
