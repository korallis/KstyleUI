-- test-actionbars-crest-ranged-reach-wide.lua: test-actionbars-crest-ranged-reach.lua's check at 5120x1440 with the cast bars on the unit frames (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 5120, 1440 } }, false)
print("actionbars crest ranged reach wide ok")
