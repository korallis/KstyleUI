-- test-load-files.lua: Load runs addon files in a stub environment with the game's varargs.
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local dir = "Tools/regression/fixtures/load_files/"
local env = Stubs.NewEnv()
assert(Load({ dir .. "Core/Init.lua", dir .. "Core/Second.lua", dir .. "KstyleUI_Bars/Bars.lua" }, env) == env, "Load returns the environment it ran in")

local core = env.KstyleUI
assert(type(core) == "table" and core.name == "KstyleUI", "core files get the addon name KstyleUI")
assert(core.order[1] == "Init" and core.order[2] == "Second", "files share one private table, in order")
assert(core.frame == env.KstyleUITestFrame, "loaded code reaches the stub API")
assert(core.kind == "number", "loaded code gets the stub's secret-aware type()")

local bars = env.KstyleUI_BarsLoaded
assert(bars and bars.name == "KstyleUI_Bars", "a KstyleUI_<Module>/ file gets its folder's addon name")
assert(bars ~= core, "each addon gets its own private table")

for _, name in ipairs({ "KstyleUI", "KstyleUI_BarsLoaded", "KstyleUITestFrame" }) do
	assert(rawget(_G, name) == nil, name .. " leaked into the real globals")
end

local loaded, message = pcall(Load, { dir .. "Core/Broken.lua" }, Stubs.NewEnv())
assert(not loaded and tostring(message):find("Broken.lua", 1, true), "a syntax error names the file")

print("load files ok")
