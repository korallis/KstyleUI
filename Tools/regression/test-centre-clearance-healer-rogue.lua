-- test-centre-clearance-healer-rogue.lua: every occupied rogue centre lane clears its neighbours after Healer Setup.Apply on screens 1 to 6 (screens 7 to 11 are in test-centre-clearance-healer-rogue-screens-7-11.lua).
dofile("Tools/regression/centre_clearance_lib.lua").Run("Healer", "ROGUE", 1, 6)
