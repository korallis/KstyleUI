-- test-perf-popoff-draw-last.lua: the shaman's, warrior's and rogue's signature pop-offs, all lit at once, keep the suite under its draw limit from rise to fold (Tools/regression/popoff_draw.lua).
dofile("Tools/regression/popoff_draw.lua").Check({ "SHAMAN", "WARRIOR", "ROGUE" })
