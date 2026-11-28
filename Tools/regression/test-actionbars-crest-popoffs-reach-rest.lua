-- test-actionbars-crest-popoffs-reach-rest.lua: test-actionbars-crest-popoffs-reach.lua's check for the warlock and druid (Tools/regression/popoff_reach.lua).
dofile("Tools/regression/popoff_reach.lua").Check({ { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } }, { "WARLOCK", "DRUID" })
print("actionbars crest pop-offs reach rest ok")
