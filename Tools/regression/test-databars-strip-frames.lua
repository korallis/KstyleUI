-- test-databars-strip-frames.lua: under the Frames HUD style, the data strip against the stub game: items, order, values, colours, settings, clicks, the secure click proxy, tooltips and the ticker.
assert(loadfile("Tools/regression/test-databars-strip.lua"))("frames")
