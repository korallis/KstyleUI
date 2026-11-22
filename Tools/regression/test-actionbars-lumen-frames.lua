-- test-actionbars-lumen-frames.lua: under the Frames HUD style, the Lumen socket on the action buttons: a quiet rim at rest, the keybind at the top left,
-- a centred cooldown timer, a gilt proc rim with a breathing glow inside the socket, a red out-of-range tint, a cool
-- desaturated tint without resource, visible empty tiles, and bar 1 as one floating row.
assert(loadfile("Tools/regression/test-actionbars-lumen.lua"))("frames")
