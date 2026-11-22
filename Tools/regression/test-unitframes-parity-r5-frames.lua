-- test-unitframes-parity-r5-frames.lua: on Frames, parity round 5 keeps v0.2.8 frames and makes nothing new, then turns on, probes after events and turns off the spell target's own text, the global cooldown fill, the detached power bar and the buff block apart, with its fallbacks, and checks the preview.
assert(loadfile("Tools/regression/test-unitframes-parity-r5.lua"))("frames")
