-- test-actionbars-crest-ranged-reach-mage.lua: test-actionbars-crest-ranged-reach.lua's mage check in the Fire and Frost trees, in the centred layout: every piece, the orb and its school's sheets included, at 1920x1080 and 2560x1440, and the rail alone at 1280x720 and 3440x1440 (Tools/regression/ranged_reach.lua).
local Reach = dofile("Tools/regression/ranged_reach.lua")
Reach.Check({ { 1920, 1080 }, { 2560, 1440 } }, { "MAGE" }, nil, { 2, 3 })
Reach.Check({ { 1280, 720 }, { 3440, 1440 } }, { "MAGE" }, "crestRail", { 2, 3 })
print("actionbars crest ranged reach mage ok")
