-- fs.lua: the one file in the Lua tests that runs shell commands; a listing that fails raises an error instead of coming back empty, on macOS, Linux and Windows alike.
--
--   local fs = dofile("Tools/regression/fs.lua")
--   fs.list(dir, { dirs = true, match = "KstyleUI_*", allow_empty = true }) -> sorted names in dir
--   fs.tracked("*.lua")                                                     -> sorted paths git tracks
--   fs.mkdir(path), fs.rmtree(path)                                         -> only under fs.TMP
--
-- Lua 5.1 drops a pipe's exit status, so each command ends in "&& echo __OK__" and a missing sentinel means it
-- failed. Names are sorted bytewise and must be ASCII, and .DS_Store, desktop.ini and Thumbs.db are left out.
-- match is a glob of * and ? on the name. With KSTYLEUI_TRACE set, trace.lua records each listing as
-- "n <dir>" or "n <dir>/<match>", and each tracked pattern as "t <pattern>", for run_all.py --affected.
local fs = {}

local WINDOWS = package.config:sub(1, 1) == "\\"
local SENTINEL = "__OK__"
local MISSING = "__MISSING__"
local HIDDEN = { [".DS_Store"] = true, ["desktop.ini"] = true, ["Thumbs.db"] = true }

fs.TMP = ((os.getenv("KSTYLEUI_TMP") or ""):gsub("\\", "/"):gsub("/+$", ""))
if fs.TMP == "" then
	fs.TMP = "Tools/regression/.tmp"
end

local function quote(path)
	assert(not path:find('["%%!^&|<>\r\n]') and not path:find("'", 1, true), "fs: a path with quotes or shell characters: " .. path)
	if WINDOWS then
		return '"' .. path:gsub("/", "\\") .. '"'
	end
	return "'" .. path .. "'"
end

local function run(command, what)
	local pipe = assert(io.popen(command))
	local lines, ok, missing = {}, false, false
	for line in pipe:lines() do
		line = line:gsub("\r$", "")
		if line == SENTINEL then
			ok = true
		elseif line == MISSING then
			missing = true
		else
			lines[#lines + 1] = line
		end
	end
	pipe:close()
	if missing then
		return nil
	end
	assert(ok, "fs: " .. what .. " failed: " .. command)
	return lines
end

local function trace(kind, pattern)
	local note = package.loaded["kstyleui.trace"]
	if note then
		note(kind, pattern)
	end
end

local function globPattern(glob)
	return "^" .. glob:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0"):gsub("%*", ".*"):gsub("%?", ".") .. "$"
end

local function ascii(name, where)
	assert(not name:find("[\128-\255]"), "fs: " .. where .. " holds a name that is not ASCII: " .. name)
	return name
end

function fs.list(dir, opts)
	opts = opts or {}
	local command
	if WINDOWS then
		local q = quote(dir)
		command = string.format('if exist %s (dir /b /a%s %s 2>nul & echo %s) else echo %s', quote(dir .. "/"), opts.dirs and "d" or "", q, SENTINEL, MISSING)
	else
		local q = quote(dir)
		command = string.format("if [ -d %s ]; then ls -1Ap %s && echo %s; else echo %s; fi", q, q, SENTINEL, MISSING)
	end
	trace("n", opts.match and dir .. "/" .. opts.match or dir)
	local lines = run(command, "listing " .. dir)
	assert(lines or opts.allow_empty, "fs: " .. dir .. " does not exist")
	local keep = opts.match and globPattern(opts.match)
	local names = {}
	for _, line in ipairs(lines or {}) do
		local isDir = line:sub(-1) == "/"
		local name = line:gsub("/$", "")
		if name ~= "" and not HIDDEN[name] and (WINDOWS or not opts.dirs or isDir) and (not opts.dirs or name:sub(1, 1) ~= ".") and (not keep or name:match(keep)) then
			names[#names + 1] = ascii(name, dir)
		end
	end
	table.sort(names)
	assert(#names > 0 or opts.allow_empty, "fs: " .. dir .. " lists nothing" .. (opts.match and " matching " .. opts.match or ""))
	return names
end

function fs.tracked(pattern)
	assert(not pattern:find('["\r\n]'), "fs: a pattern with quotes: " .. pattern)
	trace("t", pattern)
	local paths = run('git ls-files "' .. pattern .. '" && echo ' .. SENTINEL, "git ls-files " .. pattern)
	for _, path in ipairs(paths) do
		assert(path:sub(1, 1) ~= '"', "fs: git quoted a path that is not ASCII: " .. path)
	end
	table.sort(paths)
	return paths
end

local function inTmp(path)
	path = path:gsub("\\", "/"):gsub("/+$", "")
	assert(path:sub(1, #fs.TMP + 1) == fs.TMP .. "/" and not ("/" .. path .. "/"):find("/%.%./"), "fs: " .. path .. " is outside " .. fs.TMP)
	return path
end

function fs.mkdir(path)
	path = inTmp(path)
	local q = quote(path)
	if WINDOWS then
		run(string.format("mkdir %s 2>nul & if exist %s echo %s", q, quote(path .. "/"), SENTINEL), "mkdir " .. path)
	else
		run(string.format("mkdir -p %s && echo %s", q, SENTINEL), "mkdir " .. path)
	end
	return path
end

function fs.rmtree(path)
	path = inTmp(path)
	local q = quote(path)
	if WINDOWS then
		run(string.format("(if exist %s rmdir /s /q %s) & if not exist %s echo %s", q, q, q, SENTINEL), "rmtree " .. path)
	else
		run(string.format("rm -rf %s && echo %s", q, SENTINEL), "rmtree " .. path)
	end
end

return fs
