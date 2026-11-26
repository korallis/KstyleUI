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

local dir = fs.tmp() .. "/test-fs"
local other = dofile("Tools/regression/fs.lua")
assert(fs.tmp() == fs.tmp() and other.tmp() ~= fs.tmp(), "each fs gets its own temp folder and keeps it")
fs.mkdir(dir .. "/empty/deeper")
same(fs.list(dir, { allow_empty = true, dirs = true }), { "empty" }, "mkdir makes the folders on the way")
same(fs.list(dir .. "/empty/deeper", { allow_empty = true }), {}, "an empty folder lists as empty with allow_empty")
raises(function()
	fs.list(dir .. "/empty/deeper")
end, "lists nothing")
fs.mkdir(dir .. "/empty/deeper")
fs.rmtree(dir)
same(fs.list(dir, { allow_empty = true }), {}, "rmtree removes the folder")
for _, outside in ipairs({ "Core", fs.tmp(), fs.tmp() .. "/../Core", fs.tmp() .. "x/y" }) do
	raises(function()
		fs.mkdir(outside)
	end, "is outside " .. fs.tmp())
	raises(function()
		fs.rmtree(outside)
	end, "is outside " .. fs.tmp())
end

fs.mkdir(dir)
for _, name in ipairs({ "__OK__", "__MISSING__", "OK" }) do
	local handle = assert(io.open(dir .. "/" .. name, "wb"))
	handle:close()
end
same(fs.list(dir), { "OK", "__MISSING__", "__OK__" }, "a file named like a status word is listed as a file")

-- Intent: the approved faster-gate plan asks that a listing start one process per run, not one per call.
local started, real = 0, fs.popen
fs.popen = function(...)
	started = started + 1
	return real(...)
end
other.popen = fs.popen
local first = fs.list(toc)
first[1] = "changed by the caller"
same(fs.list(toc), { "Core", "Fix.toc", "Fix_Mod" }, "a remembered listing is not the table an earlier caller changed")
same(other.list(toc), { "Core", "Fix.toc", "Fix_Mod" }, "another fs in the same process answers from the same memory")
fs.tracked(toc .. "/*.lua")
fs.tracked(toc .. "/*.lua")
assert(started == 2, "three listings of one folder and two of one pattern start 2 processes, not " .. started)
same(fs.list(dir), { "OK", "__MISSING__", "__OK__" }, "the temp folder lists what it holds")
assert(io.open(dir .. "/late", "wb")):close()
same(fs.list(dir), { "OK", "__MISSING__", "__OK__", "late" }, "a listing under the temp folder is read again, so it shows a file written since")
fs.mkdir(dir .. "/made")
same(fs.list(dir, { dirs = true }), { "made" }, "and a folder made since")
fs.rmtree(dir .. "/made")
same(fs.list(dir, { dirs = true, allow_empty = true }), {}, "and not a folder removed since")
other.popen = real

local function printing(lines)
	fs.popen = function()
		local i = 0
		return {
			lines = function()
				return function()
					i = i + 1
					return lines[i]
				end
			end,
			close = function() end,
		}
	end
end
printing({ "Core/", "Fix.toc" })
raises(function()
	fs.list(toc, { allow_empty = true })
end, "listing " .. toc .. " failed")
printing({ "Core/", "//fs:missing//x" })
raises(function()
	fs.list(toc, { allow_empty = true })
end, "failed")
printing({ "Core/A.lua" })
raises(function()
	fs.tracked("*.lua")
end, "git ls-files *.lua failed")
fs.popen = other.popen

print("fs ok")
