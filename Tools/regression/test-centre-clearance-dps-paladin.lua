-- test-centre-clearance-dps-paladin.lua: every occupied paladin centre lane clears its neighbours after DPS Setup.Apply on screens 1 to 6 (screens 7 to 11 are in test-centre-clearance-dps-paladin-screens-7-11.lua).
dofile("Tools/regression/centre_clearance_lib.lua").Run("DPS", "PALADIN", 1, 6)
