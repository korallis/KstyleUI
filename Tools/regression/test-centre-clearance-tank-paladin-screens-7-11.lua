-- test-centre-clearance-tank-paladin-screens-7-11.lua: every occupied paladin centre lane clears its neighbours after Tank Setup.Apply on screens 7 to 11.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Tank", "PALADIN", 7, 11)
