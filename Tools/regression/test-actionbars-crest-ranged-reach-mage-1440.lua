-- test-actionbars-crest-ranged-reach-mage-1440.lua: the crest reach check (Tools/regression/ranged_reach.lua) for the mage's Fire and Frost trees in the centred layout at 2560x1440 and 3440x1440.
dofile("Tools/regression/ranged_reach.lua").Check({ { 2560, 1440 }, { 3440, 1440 } }, true, { "MAGE" }, { 2, 3 })
print("actionbars crest ranged reach mage 1440 ok")
