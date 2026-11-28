-- test-actionbars-crest-ranged-reach-1080.lua: test-actionbars-crest-ranged-reach.lua's check at 1920x1080 with the cast bars on the unit frames (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 1920, 1080 } }, false)
print("actionbars crest ranged reach 1080 ok")
