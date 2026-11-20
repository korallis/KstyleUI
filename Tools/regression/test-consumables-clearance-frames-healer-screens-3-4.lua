-- test-consumables-clearance-frames-healer-screens-3-4.lua: the maximum Frames Healer consumables grid clears units and the full player aura row at the last two owner sizes.
dofile("Tools/regression/consumables_clearance_lib.lua")("Frames", "Healer", { { 5120, 1440 }, { 3840, 2160 } })
