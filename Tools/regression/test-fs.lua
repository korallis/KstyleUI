-- test-fs.lua: fs.lua lists folders and tracked files the same way on every platform and raises on a listing it cannot make.
local fs = dofile("Tools/regression/fs.lua")

local function same(got, want, what)
	assert(table.concat(got, ",") == table.concat(want, ","), what .. ": got " .. table.concat(got, ","))
end

local function raises(fn, text)
	local ok, err = pcall(fn)
	assert(not ok, "expected an error naming " .. text)
	assert(tostring(err):find(text, 1, true), "the error names " .. text .. ": " .. tostring(err))
end

local toc = "Tools/regression/fixtures/toc"
same(fs.list(toc), { "Core", "Fix.toc", "Fix_Mod" }, "a folder lists files and folders, sorted bytewise")
same(fs.list(toc, { dirs = true }), { "Core", "Fix_Mod" }, "dirs lists only the folders")
same(fs.list(toc, { match = "*.toc" }), { "Fix.toc" }, "match keeps the names the glob matches")
same(fs.list(toc, { dirs = true, match = "Fix_*" }), { "Fix_Mod" }, "dirs and match combine")
same(fs.list(toc .. "/Core/"), { "A.lua", "Core.xml", "Sub" }, "a trailing slash lists the same folder")
same(fs.list(".", { dirs = true, match = "KstyleUI_ActionBar?" }), { "KstyleUI_ActionBars" }, "? matches one character")

raises(function()
	fs.list(toc .. "/Missing")
end, "Missing does not exist")
raises(function()
	fs.list(toc .. "/Fix.toc")
end, "Fix.toc does not exist")
raises(function()
	fs.list(toc, { match = "*.none" })
end, "lists nothing matching *.none")
same(fs.list(toc .. "/Missing", { allow_empty = true }), {}, "allow_empty lists a missing folder as empty")
raises(function()
	fs.list("it's")
end, "shell characters")

local tracked = fs.tracked(toc .. "/*.lua")
same(tracked, { toc .. "/Core/A.lua", toc .. "/Core/Sub/B.lua", toc .. "/Fix_Mod/C.lua" }, "tracked lists the files git tracks")

local dir = fs.TMP .. "/test-fs"
fs.rmtree(dir)
fs.mkdir(dir .. "/empty/deeper")
same(fs.list(dir, { allow_empty = true, dirs = true }), { "empty" }, "mkdir makes the folders on the way")
same(fs.list(dir .. "/empty/deeper", { allow_empty = true }), {}, "an empty folder lists as empty with allow_empty")
raises(function()
	fs.list(dir .. "/empty/deeper")
end, "lists nothing")
fs.mkdir(dir .. "/empty/deeper")
fs.rmtree(dir)
same(fs.list(dir, { allow_empty = true }), {}, "rmtree removes the folder")
for _, outside in ipairs({ "Core", fs.TMP, fs.TMP .. "/../Core", fs.TMP .. "x/y" }) do
	raises(function()
		fs.mkdir(outside)
	end, "is outside " .. fs.TMP)
	raises(function()
		fs.rmtree(outside)
	end, "is outside " .. fs.TMP)
end

print("fs ok")
