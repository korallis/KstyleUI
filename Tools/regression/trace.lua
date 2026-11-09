-- trace.lua: with KSTYLEUI_TRACE set, record each file a test opens to read and each shell command it runs; run_all.py --affected reads the record.
-- run_all.py loads it before the test through LUA_INIT; it changes no result a test sees.
local path = os.getenv("KSTYLEUI_TRACE")
if not path or path == "" then
	return
end

local log = io.open(path, "a")
if not log then
	return
end
log:setvbuf("line")

local seen = {}

local function note(kind, value)
	if type(value) ~= "string" then
		return
	end
	local line = kind .. " " .. value:gsub("[\r\n]", " ")
	if not seen[line] then
		seen[line] = true
		log:write(line, "\n")
	end
end

local function wrap(owner, name, before)
	local original = owner[name]
	owner[name] = function(first, ...)
		before(first, ...)
		return original(first, ...)
	end
end

wrap(io, "open", function(file, mode)
	if mode == nil or not mode:find("[wa+]") then
		note("f", file)
	end
end)
wrap(io, "lines", function(file)
	note("f", file)
end)
wrap(_G, "dofile", function(file)
	note("f", file)
end)
wrap(_G, "loadfile", function(file)
	note("f", file)
end)
wrap(io, "popen", function(command)
	note("c", command)
end)
wrap(os, "execute", function(command)
	note("c", command)
end)
