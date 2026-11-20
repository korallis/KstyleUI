-- test-consumables-clearance-orbs.lua: the maximum Orbs DPS consumables grid clears units and the full player aura row at the first two owner sizes.
dofile("Tools/regression/consumables_clearance_lib.lua")("Orbs", "DPS", { { 1920, 1080 }, { 2560, 1440 } })
