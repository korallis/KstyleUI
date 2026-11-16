-- test-shell-guard.lua: only fs.lua runs shell commands, and every file the tests read opens with "rb", so the suite reads and lists the same on Windows as on the Mac.
local Source = dofile("Tools/regression/lua_source.lua")
local fs = dofile("Tools/regression/fs.lua")

local SHELL = { popen = "io", execute = "os", tmpname = "os" }

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

local problems = {}
local scanned = 0
for _, path in ipairs(fs.tracked("Tools/regression/*.lua")) do
	if not path:find("^Tools/regression/fixtures/") then
		scanned = scanned + 1
		local tokens = Source.Lex(read(path))
		for i = 1, #tokens - 3 do
			local lib, dot, fn, open = tokens[i], tokens[i + 1], tokens[i + 2], tokens[i + 3]
			if lib.type == "name" and dot.type == "op" and dot.value == "." and fn.type == "name" and (i == 1 or tokens[i - 1].value ~= ".") then
				local where = path .. ":" .. fn.line .. ": " .. lib.value .. "." .. fn.value
				if SHELL[fn.value] == lib.value and path ~= "Tools/regression/fs.lua" then
					problems[#problems + 1] = where .. " runs the shell; use Tools/regression/fs.lua (fs.list, fs.tracked, fs.mkdir, fs.rmtree, fs.TMP), the one file that may, so a failed command raises on every platform"
				elseif lib.value == "io" and fn.value == "lines" then
					problems[#problems + 1] = where .. ' reads in text mode, which drops CR on Windows; use io.open(path, "rb") and handle:lines()'
				elseif lib.value == "io" and fn.value == "open" and open.value == "(" then
					local m = literalMode(tokens, i + 3)
					if not m or (m:find("r") and not m:find("b")) then
						problems[#problems + 1] = where .. ' must name its mode as a string, "rb" to read, so Windows reads the bytes the Mac does'
					end
				end
			end
		end
	end
end
assert(scanned > 100, "expected the test files, scanned " .. scanned)
assert(#problems == 0, #problems .. " problems:\n" .. table.concat(problems, "\n"))

print("shell guard ok: " .. scanned .. " files")
