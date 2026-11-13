-- test-centre-clearance-healer-paladin.lua: every occupied paladin centre lane clears its neighbours after Healer Setup.Apply on eleven screens.
dofile("Tools/regression/centre_clearance_lib.lua").Run("Healer", "PALADIN")
