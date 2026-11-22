-- test-centre-clearance-healer-paladin-screens-7-11.lua: every occupied paladin centre lane clears its neighbours after Healer Setup.Apply on screens 7 to 11.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Healer", "PALADIN", 7, 11)
