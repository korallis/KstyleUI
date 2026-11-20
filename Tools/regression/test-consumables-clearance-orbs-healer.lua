-- test-consumables-clearance-orbs-healer.lua: the maximum Orbs Healer consumables grid clears units and the full player aura row at the first two owner sizes.
dofile("Tools/regression/consumables_clearance_lib.lua")("Orbs", "Healer", { { 1920, 1080 }, { 2560, 1440 } })
