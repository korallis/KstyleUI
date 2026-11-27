-- test-actionbars-crest-popoffs-reach-rest.lua: test-actionbars-crest-popoffs-reach.lua's check for the warlock, druid, shaman, warrior and rogue (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } }, { "WARLOCK", "DRUID", "SHAMAN", "WARRIOR", "ROGUE" }, true)
print("actionbars crest pop-offs reach rest ok")
