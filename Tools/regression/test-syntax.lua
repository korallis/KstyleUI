-- test-syntax.lua: every Lua file the TOCs load compiles.
local TocFiles = dofile("Tools/regression/toc_files.lua")

local files = TocFiles("%.lua$")
assert(#files > 0, "no Lua files found")
for _, path in ipairs(files) do
	assert(loadfile(path))
end

print(#files .. " TOC files compile")
