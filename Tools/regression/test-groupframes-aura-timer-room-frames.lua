-- test-groupframes-aura-timer-room-frames.lua: on Frames, raid tiles keep every debuff icon and show no time left, and party debuff timers stay clear of stacks, dispel letters, the power strip, name and health text, on four screens and in the preview.
assert(loadfile("Tools/regression/test-groupframes-aura-timer-room.lua"))("frames")
