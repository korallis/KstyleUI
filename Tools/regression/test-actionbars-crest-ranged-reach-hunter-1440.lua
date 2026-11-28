-- test-actionbars-crest-ranged-reach-hunter-1440.lua: the crest reach check (Tools/regression/ranged_reach.lua) for the hunter's Marksmanship and Survival trees in the centred layout: every piece, the bow with Rapid Killing's arrows and Expose Prey's window included, at 2560x1440 and 3440x1440.
dofile("Tools/regression/ranged_reach.lua").Check({ { 2560, 1440 }, { 3440, 1440 } }, true, { "HUNTER" }, { 2, 3 })
print("actionbars crest ranged reach hunter-1440 ok")
