-- test-perf-hud.lua: the data bar and minimap paths registered in Tools/regression/perf/ stay within their time budgets and allocate nothing on addon lines (Tools/regression/perf_runner.lua).
dofile("Tools/regression/perf_runner.lua")("hud")
