-- test-centre-clearance-dps-rogue.lua: every occupied rogue centre lane clears its neighbours after DPS Setup.Apply on eleven screens.
dofile("Tools/regression/centre_clearance_lib.lua").Run("DPS", "ROGUE")
