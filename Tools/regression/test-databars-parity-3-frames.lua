-- test-databars-parity-3-frames.lua: under the Frames HUD style, round 3 of the data bar's EllesmereUI parity (per-readout icons, text and icon colour, the second data bar, per-click travel text) keeps today's defaults, applies when on, restores when off, follows its events and reaches the preview.
assert(loadfile("Tools/regression/test-databars-parity-3.lua"))("frames")
