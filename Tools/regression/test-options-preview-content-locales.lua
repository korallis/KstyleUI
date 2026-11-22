-- test-options-preview-content-locales.lua: preserve French 1920x1080 preview coverage in a separate PUC Lua CPU budget.
assert(loadfile("Tools/regression/test-options-preview-content.lua"))({
 { 1920, 1080, "frFR" }, { 1920, 1080, "frFR", nil, "auto" },
})
