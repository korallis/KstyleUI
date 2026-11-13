-- test-orbs-clearance-hunter.lua: under the Orbs HUD style a hunter's pet bar, the reputation and honour bars and the tracked buffs keep out of the orbs, DPS, on four screens.
dofile("Tools/regression/orbs_clearance_lib.lua").Run("DPS", "HUNTER", { pet = true, stance = false })
