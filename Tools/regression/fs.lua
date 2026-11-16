-- fs.lua: the one file in the Lua tests that runs shell commands; a listing that fails raises an error instead of coming back empty, on macOS, Linux and Windows alike.
--
--   local fs = dofile("Tools/regression/fs.lua")
--   fs.list(dir, { dirs = true, match = "KstyleUI_*", allow_empty = true }) -> sorted names in dir
--   fs.tracked("*.lua")                                                     -> sorted paths git tracks
--   fs.tmp()                                                                -> this process's own temp folder
--   fs.popen                                                                -> io.popen; a test may replace it
--   fs.mkdir(path), fs.rmtree(path)                                         -> only inside fs.tmp()
--
-- Lua 5.1 drops a pipe's exit status, so each command prints a status line only when it succeeded. A status line
-- holds "//", which no file name can, so a file can never pass for one. Names are sorted bytewise and must be
-- ASCII, and .DS_Store, desktop.ini and Thumbs.db are left out. match is a glob of * and ? on the name. fs.tmp()
-- is a new folder under KSTYLEUI_TMP (Tools/regression/.tmp by default), removed when Lua exits. With
-- KSTYLEUI_TRACE set, trace.lua records each listing as "n <dir>" or "n <dir>/<match>", and each tracked pattern
-- as "t <pattern>", for run_all.py --affected.
local fs = { popen = io.popen }

local WINDOWS = package.config:sub(1, 1) == "\\"
local OK = "//fs:ok//"
local MISSING = "//fs:missing//"
local NULL = WINDOWS and "nul" or "/dev/null"
local HIDDEN = { [".DS_Store"] = true, ["desktop.ini"] = true, ["Thumbs.db"] = true }

local BASE = (os.getenv("KSTYLEUI_TMP") or ""):gsub("\\", "/"):gsub("/+$", "")
if BASE == "" then
	BASE = "Tools/regression/.tmp"
end

local function quote(path)
	assert(not path:find('["%%!^&|<>\r\n]') and not path:find("'", 1, true), "fs: a path with quotes or shell characters: " .. path)
	if WINDOWS then
		return '"' .. path:gsub("/", "\\") .. '"'
	end
	return "'" .. path .. "'"
end

-- run(command) -> the lines the command printed and its status: "ok", "missing" or "failed".
local function run(command)
	local pipe = assert(fs.popen(command))
	local lines, status = {}, "failed"
	for line in pipe:lines() do
		line = line:gsub("\r$", "")
		if line == OK then
			status = "ok"
		elseif line == MISSING then
			status = "missing"
		else
			lines[#lines + 1] = line
		end
	end
	pipe:close()
	return lines, status
end

local function must(command, what)
	local lines, status = run(command)
	assert(status == "ok", "fs: " .. what .. " failed: " .. command)
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
	local q = quote(dir)
	local command
	if WINDOWS then
		command = string.format("if exist %s (dir /a %s >%s 2>%s && (dir /b /a%s %s 2>%s & echo %s)) else echo %s",
			quote(dir .. "/"), q, NULL, NULL, opts.dirs and "d" or "", q, NULL, OK, MISSING)
	else
		command = string.format("if [ -d %s ]; then ls -1Ap %s 2>%s && echo %s; else echo %s; fi", q, q, NULL, OK, MISSING)
	end
	trace("n", opts.match and dir .. "/" .. opts.match or dir)
	local lines, status = run(command)
	assert(status ~= "failed", "fs: listing " .. dir .. " failed: " .. command)
	assert(status == "ok" or opts.allow_empty, "fs: " .. dir .. " does not exist")
	local keep = opts.match and globPattern(opts.match)
	local names = {}
	for _, line in ipairs(lines) do
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
	local paths = must('git ls-files "' .. pattern .. '" && echo ' .. OK, "git ls-files " .. pattern)
	for _, path in ipairs(paths) do
		assert(path:sub(1, 1) ~= '"', "fs: git quoted a path that is not ASCII: " .. path)
	end
	table.sort(paths)
	return paths
end

local root, guard

local function remove(path)
	local q = quote(path)
	if WINDOWS then
		return run(string.format("(if exist %s rmdir /s /q %s) & if not exist %s echo %s", q, q, q, OK))
	end
	return run(string.format("rm -rf %s && echo %s", q, OK))
end

function fs.tmp()
	if root and guard then
		return root
	end
	local seed = os.time() .. "-" .. tostring({}):match("(%x+)$") .. "-" .. math.floor(os.clock() * 1e6)
	for attempt = 1, 20 do
		local folder = BASE .. "/" .. seed .. "-" .. attempt
		local command = WINDOWS and string.format("mkdir %s 2>%s & mkdir %s 2>%s && echo %s", quote(BASE), NULL, quote(folder), NULL, OK)
			or string.format("mkdir -p %s && mkdir %s 2>%s && echo %s", quote(BASE), quote(folder), NULL, OK)
		if select(2, run(command)) == "ok" then
			root = folder
			guard = newproxy(true)
			getmetatable(guard).__gc = function()
				pcall(remove, folder)
			end
			return root
		end
	end
	error("fs: could not make a temp folder under " .. BASE)
end

local function inTmp(path)
	path = path:gsub("\\", "/"):gsub("/+$", "")
	local tmp = fs.tmp()
	assert(path:sub(1, #tmp + 1) == tmp .. "/" and not ("/" .. path .. "/"):find("/%.%./"), "fs: " .. path .. " is outside " .. tmp)
	return path
end

function fs.mkdir(path)
	path = inTmp(path)
	local q = quote(path)
	if WINDOWS then
		must(string.format("mkdir %s 2>%s & if exist %s echo %s", q, NULL, quote(path .. "/"), OK), "mkdir " .. path)
	else
		must(string.format("mkdir -p %s && echo %s", q, OK), "mkdir " .. path)
	end
	return path
end

function fs.rmtree(path)
	path = inTmp(path)
	local _, status = remove(path)
	assert(status == "ok", "fs: rmtree " .. path .. " failed")
end

return fs
