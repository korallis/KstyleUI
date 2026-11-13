-- test-orbs-clearance-hunter-wide.lua: under the Orbs HUD style a hunter's pet bar, the reputation and honour bars and the tracked buffs keep out of the orbs, DPS, at 3440x1440 and 5120x1440.
dofile("Tools/regression/orbs_clearance_lib.lua").Run("DPS", "HUNTER", { pet = true, stance = false }, true)
