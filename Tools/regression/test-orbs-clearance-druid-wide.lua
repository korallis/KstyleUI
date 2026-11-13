-- test-orbs-clearance-druid-wide.lua: under the Orbs HUD style a druid's four forms on the stance bar, the reputation and honour bars and the tracked buffs keep out of the orbs, Healer, at 3440x1440 and 5120x1440.
dofile("Tools/regression/orbs_clearance_lib.lua").Run("Healer", "DRUID", { pet = false, stance = true }, true)
