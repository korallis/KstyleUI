-- test-actionbars-crest-ranged-reach-wide.lua: test-actionbars-crest-ranged-reach.lua's check at 5120x1440 and 3840x2160 (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 5120, 1440 }, { 3840, 2160 } })
print("actionbars crest ranged reach wide ok")
