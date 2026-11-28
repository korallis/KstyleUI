-- test-actionbars-crest-ranged-reach-1440-centred.lua: test-actionbars-crest-ranged-reach.lua's check at 2560x1440 with the centred cast bars (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 2560, 1440 } }, true)
print("actionbars crest ranged reach 1440 centred ok")
