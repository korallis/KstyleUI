-- test-options-rows-minimum.lua: run the shared row geometry checks at the minimum window size in their own memory budget.
assert(loadfile("Tools/regression/test-options-rows.lua"))("minimum")
