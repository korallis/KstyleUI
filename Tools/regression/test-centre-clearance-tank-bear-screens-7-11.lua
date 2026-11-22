-- test-centre-clearance-tank-bear-screens-7-11.lua: every occupied bear centre lane clears its neighbours after Tank Setup.Apply on screens 7 to 11.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Tank", "DRUID", "bear", 7, 11)
