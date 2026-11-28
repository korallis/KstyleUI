-- test-actionbars-crest-ranged-reach-hunter-wide.lua: the crest reach check (Tools/regression/ranged_reach.lua) for the hunter's Marksmanship and Survival trees in the centred layout: every piece, the bow with Rapid Killing's arrows and Expose Prey's window included, at 5120x1440 and 3840x2160.
dofile("Tools/regression/ranged_reach.lua").Check({ { 5120, 1440 }, { 3840, 2160 } }, true, { "HUNTER" }, { 2, 3 })
print("actionbars crest ranged reach hunter-wide ok")
