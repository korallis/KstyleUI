-- test-consumables-clearance-orbs-tank.lua: the maximum Orbs Tank consumables grid clears units and the full player aura row at the first two owner sizes.
dofile("Tools/regression/consumables_clearance_lib.lua")("Orbs", "Tank", { { 1920, 1080 }, { 2560, 1440 } })
