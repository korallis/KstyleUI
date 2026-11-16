-- test-lua-runtime.lua: the interpreter behaves as the Mac's PUC Lua 5.1 does where the tests depend on it, so a Windows build that differs fails here first.
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
assert(hash(draws) == 708739911, "math.random(1, 1000000) after math.randomseed(7) hashes to " .. hash(draws) .. ", not the Mac's 708739911: this C runtime's rand() differs, so seeded tests draw other values")

assert(string.format("%d", 2 ^ 40) == "1099511627776", "string.format('%d', 2^40) gives " .. string.format("%d", 2 ^ 40) .. ": this C runtime's long is 32 bits")
assert(tostring(1 / 0) == "inf" and tostring(-1 / 0) == "-inf", "tostring(1/0) gives " .. tostring(1 / 0) .. ", not inf")
assert(tostring(0 / 0):find("nan", 1, true), "tostring(0/0) gives " .. tostring(0 / 0) .. ", not nan")

print("lua runtime ok")
