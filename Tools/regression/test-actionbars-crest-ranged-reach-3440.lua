-- test-actionbars-crest-ranged-reach-3440.lua: test-actionbars-crest-ranged-reach.lua's check at 3440x1440 with the cast bars on the unit frames (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 3440, 1440 } }, false)
print("actionbars crest ranged reach 3440 ok")
