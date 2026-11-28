-- test-actionbars-crest-ranged-reach-wide-centred.lua: test-actionbars-crest-ranged-reach.lua's check at 5120x1440 with the centred cast bars (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 5120, 1440 } }, true)
print("actionbars crest ranged reach wide centred ok")
