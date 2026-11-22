-- test-consumables-clearance-frames-healer.lua: the maximum Frames Healer consumables grid clears units and the full player aura row at the first two owner sizes.
dofile("Tools/regression/consumables_clearance_lib.lua")("Healer", { { 1920, 1080 }, { 2560, 1440 } }, "Frames")
