-- test-groupframes-parity-r3c-frames.lua: on Frames, EllesmereUI parity round 3c: a v0.2.8 profile keeps every default and makes nothing new; each new bar, highlight and name option switched on applies, follows its events and switches back. Layout and the preview are in test-groupframes-parity-r3c-layout.lua.
assert(loadfile("Tools/regression/test-groupframes-parity-r3c.lua"))("frames")
