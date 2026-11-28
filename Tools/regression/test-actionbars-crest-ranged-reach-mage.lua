-- test-actionbars-crest-ranged-reach-mage.lua: the crest reach check (Tools/regression/ranged_reach.lua) for the mage's Fire and Frost trees in the centred layout: every piece, the orb and its school's sheets included, at 1280x720 and 1920x1080 (the other screens are test-actionbars-crest-ranged-reach-mage-1440.lua and test-actionbars-crest-ranged-reach-mage-wide.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 1280, 720 }, { 1920, 1080 } }, true, { "MAGE" }, { 2, 3 })
print("actionbars crest ranged reach mage ok")
