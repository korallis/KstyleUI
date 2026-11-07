-- test-toc-walker.lua: the TOC and XML walker resolves fixture files in load order.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local root = "Tools/regression/fixtures/toc"

local files = TocFiles("%.lua$", root)
assert(#files == 3, "expected 3 lua files, got " .. #files)
assert(files[1] == root .. "/Core/A.lua", files[1])
assert(files[2] == root .. "/Core/Sub/B.lua", "nested include must resolve from Sub/: " .. tostring(files[2]))
assert(files[3] == root .. "/Fix_Mod/C.lua", tostring(files[3]))

local all = TocFiles(nil, root)
local expected = { "Core/Core.xml", "Core/A.lua", "Core/Sub/Sub.xml", "Core/Sub/B.lua", "Fix_Mod/Mod.xml", "Fix_Mod/C.lua" }
assert(#all == #expected, "expected " .. #expected .. " files, got " .. #all)
for i, rel in ipairs(expected) do
	assert(all[i] == root .. "/" .. rel, "file " .. i .. ": " .. tostring(all[i]))
end

print("toc walker ok")
