-- test-groupframes-rows-frames-wide.lua: on Frames, KSTY-57's party and raid rows at 3440x1440, 5120x1440 and 3840x2160 (groupframes_rows_frames.lua).
dofile("Tools/regression/groupframes_rows_frames.lua").Run({ { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 } })
print("groupframes rows wide ok")
