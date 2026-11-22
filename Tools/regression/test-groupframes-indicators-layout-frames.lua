-- test-groupframes-indicators-layout-frames.lua: on Frames, the role icon (KSTY-57: the role pip), the leader icon, the raid marker and the health text never overlap on a group frame, resolved by the renderer's anchor solver at the default, smallest and largest party and raid frame sizes.
assert(loadfile("Tools/regression/test-groupframes-indicators-layout.lua"))("frames")
