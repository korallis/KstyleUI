-- test-options-preview-content-locales.lua: preserve French and Spanish preview coverage in a separate PUC Lua CPU budget.
assert(loadfile("Tools/regression/test-options-preview-content.lua"))({
 { 1920, 1080, "frFR" }, { 1920, 1080, "frFR", nil, "auto" }, { 5120, 1440, "frFR" }, { 1920, 1080, "esES" },
})
