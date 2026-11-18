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

local locales = {}
for _, path in ipairs(TocFiles("%.lua$")) do
	if path:match("^Core/Locales/") then
		locales[#locales + 1] = path
	end
end
assert(table.concat(locales, ",") == "Core/Locales/deDE.lua,Core/Locales/frFR.lua,Core/Locales/esES.lua,Core/Locales/esES.lua,Core/Locales/zhCN.lua", "P9: strip locale conditions and check every locale file, including esMX's shared Spanish table, in load order")
