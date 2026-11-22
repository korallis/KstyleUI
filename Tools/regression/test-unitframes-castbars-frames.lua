-- test-unitframes-castbars-frames.lua: on Frames, cast bars run on duration objects through SetTimerDuration, pass secret cast data only to setters, and follow their settings.
assert(loadfile("Tools/regression/test-unitframes-castbars.lua"))("frames")
