-- test-unitframes-marker-frames.lua: on Frames, a raid marker never covers its unit's name, on every frame kind in both styles, for short and long names (round 4: Opus #2, the skull centred on the sigil's "FROST HOWLER").
assert(loadfile("Tools/regression/test-unitframes-marker.lua"))("frames")
