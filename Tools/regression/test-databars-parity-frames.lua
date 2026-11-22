-- test-databars-parity-frames.lua: under the Frames HUD style, the data bar's EllesmereUI parity options keep today's defaults, apply when on, restore when off, follow their events and reach the preview.
assert(loadfile("Tools/regression/test-databars-parity.lua"))("frames")
