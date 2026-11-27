-- test-perf-popoff-draw-rest.lua: the priest's, warlock's and druid's signature pop-offs, all lit at once, keep the suite under its draw limit from rise to fold (Tools/regression/popoff_draw.lua).
dofile("Tools/regression/popoff_draw.lua").Check({ "PRIEST", "WARLOCK", "DRUID" })
