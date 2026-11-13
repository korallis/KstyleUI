-- test-orbs-clearance-warrior-wide.lua: under the Orbs HUD style a warrior's stance bar, the reputation and honour bars and the tracked buffs keep out of the orbs, Tank, at 3440x1440, 5120x1440 and 3840x1080.
dofile("Tools/regression/orbs_clearance_lib.lua").Run("Tank", "WARRIOR", { pet = false, stance = true }, true)
