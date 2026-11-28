-- test-actionbars-crest-popoffs-reach-wide.lua: test-actionbars-crest-popoffs-reach.lua's check for the paladin at 3440x1440, 5120x1440 and 3840x2160 (Tools/regression/popoff_reach.lua).
dofile("Tools/regression/popoff_reach.lua").Check({ { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 } }, { "PALADIN" })
print("actionbars crest pop-offs reach wide ok")
