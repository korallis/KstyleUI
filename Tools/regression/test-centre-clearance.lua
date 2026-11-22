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
local function Art(x)
	local part = Part(x)
	part.asset, part.ornament = "ornament probe", true
	return part
end
for pair, reason in pairs(C.ORNAMENT_PAIRS) do
	assert(type(reason) == "string" and #reason >= 40, pair .. " has a written reason")
	local a, b = pair:match("^(.-)/(.-)$")
	C.Check({ [a] = { Art(10) }, [b] = { Part(21) } }, 1, "ornament 1 px clear", { 100, 100 })
	C.Check({ [a] = { Art(10) }, [b] = { Art(15) } }, 1, "ornament meets ornament", { 100, 100 })
	local function Fails(groups, expected, why)
		local ok, err = pcall(C.Check, groups, 1, "probe", { 100, 100 })
		assert(not ok and err:find(expected, 1, true), pair .. ": " .. why .. ", got " .. tostring(err))
	end
	Fails({ [a] = { Part(10) }, [b] = { Part(21) } }, "gap 1.0000 root", "non-ornament art in the ornament's place still fails")
	Fails({ [a] = { Art(10) }, [b] = { Part(20) } }, "ornament gap 0.0000 px", "ornament art touching content fails")
	Fails({ [a] = { Art(10) }, [b] = { Part(15) } }, "ornament overlaps", "ornament art over content fails")
	Fails({ [a] = { Art(10) }, [b] = { Part(20.5) } }, "ornament gap 0.5000 px", "half a pixel is not clear")
end
for _, groups in ipairs({
	{ ["target.body"] = { Art(10) }, ["target.auras"] = { Part(21) } },
	{ ["player.body"] = { Art(10) }, ["target.portrait"] = { Part(21) } },
	{ ["player.cast"] = { Art(10) }, ["player.portrait"] = { Part(21) } },
}) do
	local ok, err = pcall(C.Check, groups, 1, "probe", { 100, 100 })
	assert(not ok and err:find("gap 1.0000 root", 1, true), "ornament art outside the named pairs keeps the full clearance, got " .. tostring(err))
end
print("ok centre clearance guard thresholds and named exceptions")
