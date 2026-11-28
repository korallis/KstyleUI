-- test-actionbars-crest-ranged-reach-2160.lua: test-actionbars-crest-ranged-reach.lua's check at 3840x2160 with the cast bars on the unit frames (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 3840, 2160 } }, false)
print("actionbars crest ranged reach 2160 ok")
