-- test-perf.lua: the core, action bar, combat text, cooldown, group frame and meter combat paths registered in Tools/regression/perf/ stay within their time budgets and allocate nothing on addon lines (Tools/regression/perf_runner.lua).
dofile("Tools/regression/perf_runner.lua")("core")
