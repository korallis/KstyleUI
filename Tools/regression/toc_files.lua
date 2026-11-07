-- toc_files.lua: list the files the game loads, in load order, from the TOCs and their XML includes.

local function shellQuote(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Lua 5.1 has no directory API, so the shell expands the glob.
local function list(glob)
	local out = {}
	local pipe = assert(io.popen("ls -1d " .. glob .. " 2>/dev/null"))
	for line in pipe:lines() do
		out[#out + 1] = line
	end
	pipe:close()
	table.sort(out)
	return out
end

local function readFile(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local text = f:read("*a")
	f:close()
	return text
end

local function normalize(path)
	local parts = {}
	for seg in path:gmatch("[^/]+") do
		if seg == ".." and #parts > 0 and parts[#parts] ~= ".." then
			parts[#parts] = nil
		elseif seg ~= "." then
			parts[#parts + 1] = seg
		end
	end
	return table.concat(parts, "/")
end

local function join(dir, rel)
	rel = rel:gsub("\\", "/")
	if dir == "" then
		return normalize(rel)
	end
	return normalize(dir .. "/" .. rel)
end

local function dirname(path)
	return path:match("^(.*)/[^/]*$") or ""
end

local function isXml(path)
	return path:lower():match("%.xml$") ~= nil
end

local walkXml

local function add(prefix, path, out, visiting)
	if isXml(path) then
		walkXml(prefix, path, out, visiting)
	else
		out[#out + 1] = path
	end
end

function walkXml(prefix, rel, out, visiting)
	out[#out + 1] = rel
	if visiting[rel] then
		return
	end
	local text = readFile(prefix .. rel)
	if not text then
		return
	end
	visiting[rel] = true
	text = text:gsub("<!%-%-.-%-%->", "")
	local dir = dirname(rel)
	for tag, attrs in text:gmatch("<(%a+)([^>]*)>") do
		if tag == "Script" or tag == "Include" then
			local file = attrs:match("%sfile%s*=%s*\"([^\"]+)\"") or attrs:match("%sfile%s*=%s*'([^']+)'")
			if file then
				add(prefix, join(dir, file), out, visiting)
			end
		end
	end
	visiting[rel] = nil
end

local function walkToc(prefix, rel, out)
	local text = readFile(prefix .. rel) or ""
	local dir = dirname(rel)
	for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
		local line = raw:gsub("\r$", ""):match("^%s*(.-)%s*$")
		if line ~= "" and line:sub(1, 1) ~= "#" then
			add(prefix, join(dir, line), out, {})
		end
	end
end

-- TocFiles(pattern, root) -> { path, ... }
-- Walks <root>/<Name>.toc, then each <root>/<Name>_*/*.toc module TOC. Paths use "/" and start with
-- root unless root is ".". A nil pattern returns every path, XML files included.
return function(pattern, root)
	root = (root or "."):gsub("/+$", "")
	if root == "" then
		root = "."
	end
	local prefix = root == "." and "" or root .. "/"
	local rels = {}
	for _, tocPath in ipairs(list(shellQuote(root) .. "/*.toc")) do
		local name = tocPath:match("([^/]+)%.toc$")
		walkToc(prefix, name .. ".toc", rels)
		for _, moduleToc in ipairs(list(shellQuote(root) .. "/" .. shellQuote(name) .. "_*/*.toc")) do
			walkToc(prefix, moduleToc:match("([^/]+/[^/]+)$"), rels)
		end
	end
	local files = {}
	for _, rel in ipairs(rels) do
		if not pattern or rel:match(pattern) then
			files[#files + 1] = prefix .. rel
		end
	end
	return files
end
