-- test-actionbars-crest-ranged-reach-2160-centred.lua: test-actionbars-crest-ranged-reach.lua's check at 3840x2160 with the centred cast bars (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 3840, 2160 } }, true)
print("actionbars crest ranged reach 2160 centred ok")
