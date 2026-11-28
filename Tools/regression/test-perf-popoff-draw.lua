-- test-perf-popoff-draw.lua: the paladin's signature pop-offs, all lit at once, keep the suite under its draw limit from rise to fold (Tools/regression/popoff_draw.lua; the priest, warlock and druid are -rest, the shaman, warrior and rogue -last).
dofile("Tools/regression/popoff_draw.lua").Check({ "PALADIN" })
