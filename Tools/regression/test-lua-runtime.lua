-- test-lua-runtime.lua: record C-runtime differences and reject new sequence-dependent math.random fixtures.
local fs = dofile("Tools/regression/fs.lua")
local function hash(values)
	local h = 0
	for _, v in ipairs(values) do
		h = (h * 31 + v) % 2147483647
	end
	return h
end

math.randomseed(7)
local draws = {}
for i = 1, 64 do
	draws[i] = math.random(1, 1000000)
end
for _, value in ipairs(draws) do
	assert(value >= 1 and value <= 1000000 and value == math.floor(value), "math.random must return an integer in range")
end
print("lua runtime: random seed=7 hash=" .. hash(draws) .. " platform=" .. (package.config:sub(1, 1) == "\\" and "Windows" or "POSIX"))
for _, path in ipairs(fs.tracked("Tools/regression/*.lua")) do
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a")
	file:close()
	if source:find("math%s*%.%s*random%s*%(") then
		assert(path == "Tools/regression/test-lua-runtime.lua" or path == "Tools/regression/test-ornament-tiers.lua",
			path .. ": math.random sequences differ across C runtimes; use property_lib.lua's portable generator for new fixtures")
	end
end

print("lua runtime: format(2^40)=" .. string.format("%d", 2 ^ 40) .. " infinity=" .. tostring(1 / 0) .. " nan=" .. tostring(0 / 0))
assert(string.format("%d", 2 ^ 30) == "1073741824", "string.format('%d') must preserve the integers used by fixtures")
assert(1 / 0 == math.huge and -1 / 0 == -math.huge, "infinity must retain its numeric value")
local nan = 0 / 0
assert(nan ~= nan, "NaN must remain unequal to itself")

print("lua runtime ok")
