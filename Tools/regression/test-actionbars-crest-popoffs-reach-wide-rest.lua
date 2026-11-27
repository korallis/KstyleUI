-- test-actionbars-crest-popoffs-reach-wide-rest.lua: test-actionbars-crest-popoffs-reach.lua's check for the warlock, druid, shaman, warrior and rogue at 3440x1440, 5120x1440 and 3840x2160 (Tools/regression/ranged_reach.lua).
dofile("Tools/regression/ranged_reach.lua").Check({ { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 } }, { "WARLOCK", "DRUID", "SHAMAN", "WARRIOR", "ROGUE" }, true)
print("actionbars crest pop-offs reach wide rest ok")
