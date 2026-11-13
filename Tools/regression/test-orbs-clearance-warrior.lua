-- test-orbs-clearance-warrior.lua: under the Orbs HUD style a warrior's stance bar, the reputation and honour bars and the tracked buffs keep out of the orbs, Tank, at 1280x720 and 1920x1080.
dofile("Tools/regression/orbs_clearance_lib.lua").Run("Tank", "WARRIOR", { pet = false, stance = true })
