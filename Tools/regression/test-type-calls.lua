-- test-type-calls.lua: addon code never passes a function call straight to type(); it wraps it as type((f())).
-- A Blizzard API that has nothing to report returns no values at all, not nil: UnitCastingInfo on a unit that is
-- not casting is one. type(f()) then gets no argument and raises "bad argument #1 to 'type' (value expected)",
-- which broke the nameplate cast bar in game. The extra brackets pass exactly one value, nil when f returns nothing.
-- The test stub's type() cannot check this itself without allocating, so this scan does it.
local TocFiles = dofile("Tools/regression/toc_files.lua")

local FIX = "write type((...)) so the call passes exactly one value; a function that returns nothing makes type() raise"

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- Calls(text) -> the line numbers where type( wraps a function call directly.
local function Calls(text)
	local lines, n = {}, 0
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		local start = 1
		while true do
			local s, e = line:find("type%(", start)
			if not s then
				break
			end
			local before = s > 1 and line:sub(s - 1, s - 1) or ""
			local rest = line:sub(e + 1)
			if not before:match("[%w_%.:]") and not rest:match("^%(") and rest:match("^%s*[%a_][%w_%.:]*%s*%(") then
				lines[#lines + 1] = n
				break
			end
			start = e + 1
		end
	end
	return lines
end

assert(#Calls("return type(UnitCastingInfo(unit)) ~= 'nil'\n") == 1, "a direct call is found")
assert(#Calls("return type((UnitCastingInfo(unit))) ~= 'nil'\n") == 0, "the bracketed form passes")
assert(#Calls("if type(value) == 'table' then end\n") == 0, "a plain value passes")
assert(#Calls("local t = x.type(f())\n") == 0, "only the global type is checked")
assert(#Calls("local ok = type(frame.GetName) == 'function'\n") == 0, "a field, not a call, passes")
assert(#Calls("local a = type(frame:GetName())\n") == 1, "a method call is found")
assert(Calls("a\r\nb = type(f())\r\n")[1] == 2, "CRLF lines are counted")

local problems, count = {}, 0
for _, path in ipairs(TocFiles("%.lua$")) do
	if not (path:match("^Libs/") or path:find("/Libs/", 1, true)) then
		for _, line in ipairs(Calls(read(path))) do
			problems[#problems + 1] = path .. ":" .. line .. ": type() wraps a call; " .. FIX
		end
		count = count + 1
	end
end
assert(count > 0, "no TOC-loaded Lua files found")
if #problems > 0 then
	print(#problems .. " type() calls that can raise on a function returning nothing:")
	for _, problem in ipairs(problems) do
		print(problem)
	end
	os.exit(1)
end
