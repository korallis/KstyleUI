-- test-shell-guard.lua: only fs.lua runs shell commands, and every Lua file in the repository opens files to read with "rb", so the suite and the helpers it runs read and list the same on Windows as on the Mac.
local Source = dofile("Tools/regression/lua_source.lua")
local fs = dofile("Tools/regression/fs.lua")

local SHELL = { popen = "io", execute = "os", tmpname = "os" }
local TEXT = { lines = true, input = true }

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function literalMode(tokens, i)
	local depth, from = 0, nil
	for j = i, #tokens do
		local t = tokens[j]
		if t.type == "op" and (t.value == "(" or t.value == "{" or t.value == "[") then
			depth = depth + 1
		elseif t.type == "op" and (t.value == ")" or t.value == "}" or t.value == "]") then
			depth = depth - 1
			if depth == 0 then
				break
			end
		elseif depth == 1 and t.type == "op" and t.value == "," then
			from = j + 1
		end
	end
	local t, after = tokens[from or 0], tokens[(from or 0) + 1]
	return t and t.type == "string" and after.type == "op" and after.value == ")" and t.value or nil
end

local function Problems(path, text)
	local problems = {}
	local tokens = Source.Lex(text)
	for i = 1, #tokens - 3 do
		local lib, dot, fn, call = tokens[i], tokens[i + 1], tokens[i + 2], tokens[i + 3]
		if lib.type == "name" and dot.type == "op" and dot.value == "." and fn.type == "name" and (i == 1 or tokens[i - 1].value ~= ".") then
			local where = path .. ":" .. fn.line .. ": " .. lib.value .. "." .. fn.value
			if SHELL[fn.value] == lib.value and path ~= "Tools/regression/fs.lua" then
				problems[#problems + 1] = where .. " runs the shell; use Tools/regression/fs.lua (fs.list, fs.tracked, fs.tmp, fs.mkdir, fs.rmtree), the one file that may, so a failed command raises on every platform"
			elseif lib.value == "io" and TEXT[fn.value] then
				problems[#problems + 1] = where .. ' reads in text mode, which drops CR on Windows; use io.open(path, "rb") and handle:lines()'
			elseif lib.value == "io" and fn.value == "open" then
				local mode = call.type == "op" and call.value == "(" and literalMode(tokens, i + 3)
				if not mode or (mode:find("r") and not mode:find("b")) then
					problems[#problems + 1] = where .. ' must be called as io.open(path, "rb") to read, the mode a string, so Windows reads the bytes the Mac does'
				end
			end
		end
	end
	return problems
end

for _, case in ipairs({
	{ 'local p = io.popen("ls")', "runs the shell" },
	{ "os.execute('mkdir x')", "runs the shell" },
	{ "local t = os.tmpname()", "runs the shell" },
	{ "local run = io.popen", "runs the shell" },
	{ 'local f = io.open(path)', '"rb"' },
	{ 'local f = io.open(path, "r")', '"rb"' },
	{ "local f = io.open(path, mode)", '"rb"' },
	{ 'local text = io.open "AGENTS.md":read("*a")', '"rb"' },
	{ 'local f = io.open { "AGENTS.md" }', '"rb"' },
	{ "local open = io.open", '"rb"' },
	{ 'for line in io.lines("AGENTS.md") do end', "text mode" },
	{ 'for line in io.lines "AGENTS.md" do end', "text mode" },
	{ 'io.input("AGENTS.md")', "text mode" },
}) do
	local found = Problems("Tools/render/x.lua", "if false then " .. case[1] .. " end")
	assert(#found == 1 and found[1]:find(case[2], 1, true), "the guard rejects " .. case[1] .. ": " .. table.concat(found, "; "))
end
for _, fine in ipairs({ 'io.open(path, "rb")', 'io.open(path, "wb")', 'io.open(path, "ab")', 'io.open(path, "a")', 'f:read("*a")', "x.io.open(path)", 's = "io.open(path)"' }) do
	local found = Problems("Tools/render/x.lua", fine)
	assert(#found == 0, "the guard accepts " .. fine .. ": " .. table.concat(found, "; "))
end
assert(#Problems("Tools/regression/fs.lua", 'io.popen("ls")') == 0, "fs.lua may run the shell")

local problems = {}
local scanned = 0
for _, path in ipairs(fs.tracked("*.lua")) do
	if not path:find("^Tools/regression/fixtures/") then
		scanned = scanned + 1
		for _, problem in ipairs(Problems(path, read(path))) do
			problems[#problems + 1] = problem
		end
	end
end
assert(scanned > 500, "expected the repository's Lua files, scanned " .. scanned)
assert(#problems == 0, #problems .. " problems:\n" .. table.concat(problems, "\n"))

print("shell guard ok: " .. scanned .. " files")
