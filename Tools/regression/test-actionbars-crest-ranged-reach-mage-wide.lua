-- test-actionbars-crest-ranged-reach-mage-wide.lua: the crest reach check (Tools/regression/ranged_reach.lua) for the mage's Fire and Frost trees in the centred layout at 5120x1440 and 3840x2160.
dofile("Tools/regression/ranged_reach.lua").Check({ { 5120, 1440 }, { 3840, 2160 } }, true, { "MAGE" }, { 2, 3 })
print("actionbars crest ranged reach mage wide ok")
