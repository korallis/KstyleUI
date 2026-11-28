-- test-actionbars-crest-ranged-reach-1440.lua: test-actionbars-crest-ranged-reach.lua's check at 2560x1440 and 3440x1440 (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 2560, 1440 }, { 3440, 1440 } })
print("actionbars crest ranged reach 1440 ok")
