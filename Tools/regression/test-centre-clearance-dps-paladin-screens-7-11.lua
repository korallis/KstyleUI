-- test-centre-clearance-dps-paladin-screens-7-11.lua: every occupied paladin centre lane clears its neighbours after DPS Setup.Apply on screens 7 to 11.
dofile("Tools/regression/centre_clearance_lib.lua").Run("DPS", "PALADIN", 7, 11)
