-- test-orbs-clearance-druid.lua: under the Orbs HUD style a druid's four forms on the stance bar, the reputation and honour bars and the tracked buffs keep out of the orbs, Healer, on four screens.
dofile("Tools/regression/orbs_clearance_lib.lua").Run("Healer", "DRUID", { pet = false, stance = true })
