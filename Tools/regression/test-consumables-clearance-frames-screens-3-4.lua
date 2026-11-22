-- test-consumables-clearance-frames-screens-3-4.lua: the maximum Frames DPS consumables grid clears units and the full player aura row at the last two owner sizes.
dofile("Tools/regression/consumables_clearance_lib.lua")("DPS", { { 5120, 1440 }, { 3840, 2160 } }, "Frames")
