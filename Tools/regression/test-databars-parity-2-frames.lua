-- test-databars-parity-2-frames.lua: under the Frames HUD style, round 2 of the data bar's EllesmereUI parity keeps today's defaults, and each option applies when on, restores when off, follows its events and reaches the preview.
assert(loadfile("Tools/regression/test-databars-parity-2.lua"))("frames")
