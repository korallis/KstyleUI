-- test-centre-clearance-healer-paladin.lua: every occupied paladin centre lane clears its neighbours after Healer Setup.Apply on screens 1 to 6 (screens 7 to 11 are in test-centre-clearance-healer-paladin-screens-7-11.lua).
dofile("Tools/regression/centre_clearance_lib.lua").Run("Healer", "PALADIN", 1, 6)
