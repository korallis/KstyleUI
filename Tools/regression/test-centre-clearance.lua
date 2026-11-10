-- test-centre-clearance.lua: the drawn-asset guard rejects overlaps and each clearance threshold independently, with only the attached level discs exempted.
local C = dofile("Tools/regression/centre_clearance_lib.lua")
local function Part(x)
	return { x = x, y = 10, w = 10, h = 10, asset = "probe" }
end
local function Reject(x, pixels, expected)
	local ok, why = pcall(C.Check, { a = { Part(10) }, b = { Part(x) } }, pixels, "probe", { 100, 100 })
	assert(not ok and why:find(expected, 1, true), "the guard rejects " .. expected .. ", got " .. tostring(why))
end
Reject(19, 1, "overlaps")
Reject(23.5, 1, "3.5000 root, 3.5000 px")
Reject(25, 0.5, "5.0000 root, 2.5000 px")
C.Check({ a = { Part(10) }, b = { Part(24) } }, 1, "probe", { 100, 100 })
for _, kind in ipairs({ "player", "target" }) do
	C.Check({ [kind .. ".level"] = { Part(10) }, [kind .. ".portrait"] = { Part(10) } }, 1, "attached disc", { 100, 100 })
end
print("ok centre clearance guard thresholds and named exceptions")
