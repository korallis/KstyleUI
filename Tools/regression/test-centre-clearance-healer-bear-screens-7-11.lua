-- test-centre-clearance-healer-bear-screens-7-11.lua: every occupied bear centre lane clears its neighbours after Healer Setup.Apply on screens 7 to 11.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Healer", "DRUID", "bear", 7, 11)
