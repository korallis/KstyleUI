-- test-perf-skins.lua: the quest card's combat paths registered in Tools/regression/perf/KstyleUI_Skins.lua stay within their time budgets and allocate nothing on addon lines (Tools/regression/perf_runner.lua).
dofile("Tools/regression/perf_runner.lua")("skins")
