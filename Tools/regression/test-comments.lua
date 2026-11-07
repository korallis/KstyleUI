-- test-comments.lua: every TOC-loaded Lua file has one comment, its first line, "-- <File>.lua: <what it is>."
-- The roadmap's Global Constraints set this rule. Anything else a reader needs goes in a README or in docs/.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Source = dofile("Tools/regression/lua_source.lua")

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- Problems(path, text) -> a list of "line N: problem" strings.
local function Problems(path, text)
	local name = path:match("([^/]+)$")
	local comments = {}
	Source.Lex(text, comments)
	local out = {}
	local first = comments[1]
	if not first or first.line ~= 1 then
		out[#out + 1] = "line 1: the file starts with no comment; write -- " .. name .. ": <what it is>."
	else
		local escaped = name:gsub("%p", "%%%0")
		if not first.text:match("^%-%- " .. escaped .. ": %S.*%.$") then
			out[#out + 1] = "line 1: the first comment must read -- " .. name .. ": <what it is>."
		end
	end
	for i = first and first.line == 1 and 2 or 1, #comments do
		out[#out + 1] = "line " .. comments[i].line .. ": a second comment; move it to the README or docs/"
	end
	return out
end

-- The check itself.
assert(#Problems("Core/A.lua", "-- A.lua: a thing.\nlocal x = 1\n") == 0, "one first-line comment passes")
assert(#Problems("Core/A.lua", '-- A.lua: a thing.\nlocal s = "-- not a comment"\n') == 0, "dashes in a string are not a comment")
assert(#Problems("Core/A.lua", "-- A.lua: a thing.\nlocal x = 1 -- note\n") == 1, "a trailing comment fails")
assert(#Problems("Core/A.lua", "-- A.lua: a thing.\n--[[ block ]]\n") == 1, "a block comment fails")
assert(#Problems("Core/A.lua", "local x = 1\n") == 1, "a file with no comment fails")
assert(#Problems("Core/A.lua", "-- B.lua: a thing.\n") == 1, "the comment names the file")
assert(#Problems("Core/A.lua", "-- A.lua: a thing\n") == 1, "the comment is a sentence")
assert(#Problems("Core/A.lua", "-- A.lua: a thing.\r\nlocal x = 1\r\n") == 0, "CRLF files pass")

local problems, count = {}, 0
for _, path in ipairs(TocFiles("%.lua$")) do
	if not (path:match("^Libs/") or path:find("/Libs/", 1, true)) then
		for _, problem in ipairs(Problems(path, read(path))) do
			problems[#problems + 1] = path .. ":" .. problem
		end
		count = count + 1
	end
end
assert(count > 0, "no TOC-loaded Lua files found")
if #problems > 0 then
	print(#problems .. " comment problems. A file has one comment, its first line; the rest goes in a README or docs/.")
	for _, problem in ipairs(problems) do
		print(problem)
	end
	os.exit(1)
end

print("comments ok: " .. count .. " files")
