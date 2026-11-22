-- test-options-preview-content-locales-2.lua: preserve French ultrawide and Spanish preview coverage in a separate PUC Lua CPU budget.
assert(loadfile("Tools/regression/test-options-preview-content.lua"))({
 { 5120, 1440, "frFR" }, { 1920, 1080, "esES" },
})
