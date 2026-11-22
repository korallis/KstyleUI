-- test-consumables-clearance.lua: the maximum Medallions DPS consumables grid clears units and the full player aura row at the first two owner sizes.
dofile("Tools/regression/consumables_clearance_lib.lua")("DPS", { { 1920, 1080 }, { 2560, 1440 } })
