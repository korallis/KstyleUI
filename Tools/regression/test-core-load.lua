-- test-core-load.lua: the core addon's TOC files run in the stub environment and publish KstyleUI.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local core = {}
for _, path in ipairs(TocFiles("%.lua$")) do
	if not path:match("^KstyleUI_") then
		core[#core + 1] = path
	end
end
assert(#core > 0, "no core Lua files found")

local env = Load(core, Stubs.NewEnv())
assert(type(env.KstyleUI) == "table", "KstyleUI global missing")
assert(env.KstyleUI == env._addons.KstyleUI, "KstyleUI must be the addon's private table")
assert(env.KstyleUI.CODE_BUILD == 1, "CODE_BUILD must be 1")
assert(type(env.KstyleUI.VERSION) == "string", "VERSION must be a string")
assert(rawget(_G, "KstyleUI") == nil, "addon code leaked into the real globals")

print("core load ok (" .. #core .. " files)")
