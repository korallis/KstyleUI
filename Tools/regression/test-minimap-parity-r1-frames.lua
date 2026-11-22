-- test-minimap-parity-r1-frames.lua: under the Frames HUD style, the first EllesmereUI parity round for the minimap: each new option keeps today's default, applies switched on, refreshes on its events and restores when switched off.
assert(loadfile("Tools/regression/test-minimap-parity-r1.lua"))("frames")
