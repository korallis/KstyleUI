-- test-actionbars-crest-ranged-reach-1080-centred.lua: test-actionbars-crest-ranged-reach.lua's check at 1920x1080 with the centred cast bars (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 1920, 1080 } }, true)
print("actionbars crest ranged reach 1080 centred ok")
