-- test-actionbars-crest-popoffs-reach-wide.lua: test-actionbars-crest-popoffs-reach.lua's check for the mage, hunter, paladin and priest at 3440x1440, 5120x1440 and 3840x2160 (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 } }, { "MAGE", "HUNTER", "PALADIN", "PRIEST" }, true)
print("actionbars crest pop-offs reach wide ok")
