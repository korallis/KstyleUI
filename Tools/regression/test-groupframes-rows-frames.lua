-- test-groupframes-rows-frames.lua: on Frames, KSTY-57's party and raid rows at 1280x720, 1920x1080 and 2560x1440 (groupframes_rows_frames.lua).
dofile("Tools/regression/groupframes_rows_frames.lua").Run({ { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } })
print("groupframes rows ok")
