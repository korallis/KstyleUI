-- test-meters-threat-frames.lua: under the Frames HUD style, the threat meter lists the group's threat on the target, highest first, passes secret values only to widget setters, and warns on readable values.
assert(loadfile("Tools/regression/test-meters-threat.lua"))("frames")
