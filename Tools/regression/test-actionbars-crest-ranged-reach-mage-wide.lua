-- test-actionbars-crest-ranged-reach-mage-wide.lua: test-actionbars-crest-ranged-reach-wide.lua's mage check in the Fire and Frost trees, in the centred layout, at 5120x1440 and 3840x2160 (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 5120, 1440 }, { 3840, 2160 } }, true, { "MAGE" }, { 2, 3 })
print("actionbars crest ranged reach mage wide ok")
