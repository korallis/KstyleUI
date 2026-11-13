-- test-centre-clearance-healer-rogue.lua: every occupied rogue centre lane clears its neighbours after Healer Setup.Apply on eleven screens.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Healer", "ROGUE")
