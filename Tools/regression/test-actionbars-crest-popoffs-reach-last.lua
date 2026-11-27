-- test-actionbars-crest-popoffs-reach-last.lua: test-actionbars-crest-popoffs-reach.lua's check for the shaman, warrior and rogue (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } }, { "SHAMAN", "WARRIOR", "ROGUE" }, true)
print("actionbars crest pop-offs reach last ok")
