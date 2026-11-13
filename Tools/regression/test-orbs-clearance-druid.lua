-- test-orbs-clearance-druid.lua: under the Orbs HUD style a druid's four forms on the stance bar, the reputation and honour bars and the tracked buffs keep out of the orbs, Healer, at 1280x720 and 1920x1080.
dofile("Tools/regression/orbs_clearance_lib.lua").Run("Healer", "DRUID", { pet = false, stance = true })
