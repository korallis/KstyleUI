-- test-groupframes-parity-r1-frames.lua: on Frames, EllesmereUI parity round 1: v0.2.8 profiles keep every default; each new group frame option switched on applies, follows its events, reaches the preview and switches back.
assert(loadfile("Tools/regression/test-groupframes-parity-r1.lua"))("frames")
