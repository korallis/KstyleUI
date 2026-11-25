-- test-actionbars-crest-ranged-reach.lua: at 1920x1080 and 2560x1440 no lit break-out piece of a hunter, mage or warlock crest, nor a hunter's lifted hawk (also at 1280x720, the KSTY-61 plan's smallest screen), at full alpha, grown by its scale animations and swept along its translations, draws on an action slot, the level badge, a unit frame or a cast bar, or outside the crest's column (Tools/regression/ranged_reach.lua; the wide screens are test-actionbars-crest-ranged-reach-wide.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 1920, 1080 }, { 2560, 1440 } })
dofile("Tools/regression/ranged_reach.lua").Check({ { 1280, 720 } }, { "HUNTER" })
print("actionbars crest ranged reach ok")
