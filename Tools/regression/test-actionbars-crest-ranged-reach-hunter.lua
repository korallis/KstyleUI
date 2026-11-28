-- test-actionbars-crest-ranged-reach-hunter.lua: the crest reach check (Tools/regression/ranged_reach.lua) for the hunter's Marksmanship and Survival trees in the centred layout: every piece, the bow with Rapid Killing's arrows and Expose Prey's window included, at 1280x720 and 1920x1080 (the other screens are test-actionbars-crest-ranged-reach-hunter-1440.lua and test-actionbars-crest-ranged-reach-hunter-wide.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 1280, 720 }, { 1920, 1080 } }, true, { "HUNTER" }, { 2, 3 })
print("actionbars crest ranged reach hunter ok")
