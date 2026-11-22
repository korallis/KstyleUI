-- test-centre-clearance-healer-bear.lua: every occupied bear centre lane clears its neighbours after Healer Setup.Apply on screens 1 to 6 (screens 7 to 11 are in test-centre-clearance-healer-bear-screens-7-11.lua).
dofile("Tools/regression/centre_clearance_lib.lua").Run("Healer", "DRUID", "bear", 1, 6)
