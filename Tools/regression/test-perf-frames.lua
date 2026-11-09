-- test-perf-frames.lua: the nameplate and unit frame combat paths registered in Tools/regression/perf/ stay within their time budgets and allocate nothing on addon lines (Tools/regression/perf_runner.lua).
dofile("Tools/regression/perf_runner.lua")("frames")
