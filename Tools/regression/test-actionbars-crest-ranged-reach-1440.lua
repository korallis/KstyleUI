-- test-actionbars-crest-ranged-reach-1440.lua: test-actionbars-crest-ranged-reach.lua's check at 2560x1440 with the cast bars on the unit frames (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 2560, 1440 } }, false)
print("actionbars crest ranged reach 1440 ok")
