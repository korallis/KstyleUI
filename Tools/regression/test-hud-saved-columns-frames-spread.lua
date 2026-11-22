-- test-hud-saved-columns-frames-spread.lua: saved frames columns keep their coordinates on the ultrawide Spread screen.
dofile("Tools/regression/hud_reach_lib.lua").SavedColumns("frames", 3, "spread")
