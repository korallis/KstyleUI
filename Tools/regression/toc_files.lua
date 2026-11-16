-- toc_files.lua: list the files the game loads, in load order, from the TOCs and their XML includes.
local fs = dofile("Tools/regression/fs.lua")

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
	for _, toc in ipairs(fs.list(root, { match = "*.toc" })) do
		walkToc(prefix, toc, rels)
		for _, folder in ipairs(fs.list(root, { dirs = true, match = toc:match("^(.+)%.toc$") .. "_*", allow_empty = true })) do
			for _, moduleToc in ipairs(fs.list(prefix .. folder, { match = "*.toc", allow_empty = true })) do
				walkToc(prefix, folder .. "/" .. moduleToc, rels)
			end
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
