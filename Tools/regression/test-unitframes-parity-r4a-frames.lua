-- test-unitframes-parity-r4a-frames.lua: on Frames, parity round 4a keeps v0.2.8 frames, then turns on, probes after events and turns off the text bar, the boss cast bar's width and height, trailing zeros and tracked debuffs, and checks the preview.
assert(loadfile("Tools/regression/test-unitframes-parity-r4a.lua"))("frames")
