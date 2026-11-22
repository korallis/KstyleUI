-- test-centre-clearance-dps-rogue-screens-7-11.lua: every occupied rogue centre lane clears its neighbours after DPS Setup.Apply on screens 7 to 11.
dofile("Tools/regression/centre_clearance_lib.lua").Run("DPS", "ROGUE", 7, 11)
