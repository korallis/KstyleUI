-- test-orbs-clearance-hunter.lua: under the Orbs HUD style a hunter's pet bar, the reputation and honour bars and the tracked buffs keep out of the orbs, DPS, at 1280x720, 1920x1080 and 2560x1080.
dofile("Tools/regression/orbs_clearance_lib.lua").Run("DPS", "HUNTER", { pet = true, stance = false })
