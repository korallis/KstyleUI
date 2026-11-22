-- test-actionbars-options-2.lua: the second half of test-actionbars-options.lua's bars, in a window of its own.
rawset(_G, "ACTIONBARS_OPTIONS_SECOND", true)
dofile("Tools/regression/test-actionbars-options.lua")
