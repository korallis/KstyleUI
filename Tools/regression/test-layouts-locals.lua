-- test-layouts-locals.lua: Core/Setup/Layouts.lua keeps a margin under Lua 5.1's limit of 200 local variables in one function.
local PATH, MARGIN, LIMIT = "Core/Setup/Layouts.lua", 5, 200

local handle = assert(io.open(PATH, "rb"))
local source = handle:read("*a")
handle:close()

local function compiles(extra)
	local names = {}
	for i = 1, extra do
		names[i] = "kstyle_pad_" .. i
	end
	local pad = extra > 0 and ("local " .. table.concat(names, ", ") .. " ") or ""
	local chunk, err = loadstring(pad .. source, "=" .. PATH)
	return chunk ~= nil, err
end

local ok, err = compiles(0)
assert(ok, PATH .. " does not compile: " .. tostring(err))

local free = 0
while free < LIMIT and compiles(free + 1) do
	free = free + 1
end
assert(
	free >= MARGIN,
	PATH .. " has room for only " .. free .. " more top-level locals; keep " .. MARGIN .. " free. Put new data in a table or a function scope instead of a new top-level local."
)
print("layouts locals ok (" .. free .. " free)")
