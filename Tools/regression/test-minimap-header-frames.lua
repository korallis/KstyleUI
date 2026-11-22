-- test-minimap-header-frames.lua: under the Frames HUD style, the zone in capitals keeps clear of the north diamond and the N stays inside its diamond (KSTY-77, the owner's live Shen'dar Highlands at 3456x2234), at every screen, zone length, zone size and font scale.
assert(loadfile("Tools/regression/test-minimap-header.lua"))("frames")
