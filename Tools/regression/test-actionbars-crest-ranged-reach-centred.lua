-- test-actionbars-crest-ranged-reach-centred.lua: test-actionbars-crest-ranged-reach.lua's check at 1280x720 with the centred cast bars (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 1280, 720 } }, true)
print("actionbars crest ranged reach centred ok")
