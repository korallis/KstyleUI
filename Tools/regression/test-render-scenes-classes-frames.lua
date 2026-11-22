-- test-render-scenes-classes-frames.lua: test-render-scenes-classes.lua under the Frames HUD style.
rawset(_G, "RENDER_HUD_STYLE", "Frames")
dofile("Tools/regression/test-render-scenes-classes.lua")
