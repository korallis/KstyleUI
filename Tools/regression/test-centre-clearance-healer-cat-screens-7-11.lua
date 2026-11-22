-- test-centre-clearance-healer-cat-screens-7-11.lua: every occupied cat centre lane clears its neighbours after Healer Setup.Apply on screens 7 to 11.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Healer", "DRUID", "cat", 7, 11)
