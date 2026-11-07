-- test-taint-allow.lua: the per-area allow-list loads and merges, rejects bad files, and must match findings exactly.
local Scan = dofile("Tools/regression/taint_scan.lua")
local loader = assert(loadfile("Tools/regression/taint_allow.lua"))

local root = os.tmpname()
os.remove(root)
local cases = 0

local function write(path, text)
	local handle = assert(io.open(path, "wb"))
	handle:write(text)
	handle:close()
end

-- A fresh folder holding the given area files.
local function folder(files)
	cases = cases + 1
	local dir = root .. "/case" .. cases
	os.execute("mkdir -p '" .. dir .. "'")
	for name, text in pairs(files) do
		write(dir .. "/" .. name, text)
	end
	return dir
end

local function rejects(files, message)
	local ok, err = pcall(loader, folder(files))
	assert(not ok, "expected the loader to reject: " .. message)
	assert(err:find(message, 1, true), "wrong error for " .. message .. ": " .. tostring(err))
	assert(err:find("%.lua: ") or err:find("%.txt: "), "the error must name the area file: " .. err)
end

local ok, err = pcall(function()
	-- Area files merge into one table, and each entry remembers its file.
	local dir = folder({
		["Core.lua"] = 'return { ["Core/Safe.lua"] = { why = "Safe reparents Blizzard frames", calls = { ["?:SetParent"] = 1 } } }',
		["KstyleUI_Bags.lua"] = [[return {
			["KstyleUI_Bags/Bags.lua"] = { why = "the bag bar is hidden in place", calls = { ["MainMenuBarBackpackButton:Hide"] = 2 } },
		}]],
	})
	local allow = loader(dir)
	assert(allow["Core/Safe.lua"].calls["?:SetParent"] == 1, "Core entry missing")
	assert(allow["KstyleUI_Bags/Bags.lua"].calls["MainMenuBarBackpackButton:Hide"] == 2, "Bags entry missing")
	assert(allow["Core/Safe.lua"].file == dir .. "/Core.lua", "entry file: " .. tostring(allow["Core/Safe.lua"].file))
	assert(allow["Core/Safe.lua"].why == "Safe reparents Blizzard frames", "why lost")

	-- No folder, or an empty one, allows nothing.
	assert(next(loader(root .. "/missing")) == nil, "a missing folder allows nothing")
	assert(next(loader(folder({}))) == nil, "an empty folder allows nothing")

	-- Each file covers its own folder only, and every entry has a why and whole counts.
	rejects({ ["Bags.lua"] = "return {}" }, "name an area file after its folder")
	rejects({ ["notes.txt"] = "" }, "holds only area files")
	rejects({ ["KstyleUI_Bags.lua"] = 'return { ["Core/Init.lua"] = { why = "x", calls = { ["A:Hide"] = 1 } } }' }, "is outside KstyleUI_Bags/")
	rejects({ ["Core.lua"] = 'return { ["Core/Init.lua"] = { why = " ", calls = { ["A:Hide"] = 1 } } }' }, "needs a why")
	rejects({ ["Core.lua"] = 'return { ["Core/Init.lua"] = { calls = { ["A:Hide"] = 1 } } }' }, "needs a why")
	rejects({ ["Core.lua"] = 'return { ["Core/Init.lua"] = { why = "x", calls = {} } }' }, "needs at least one call")
	rejects({ ["Core.lua"] = 'return { ["Core/Init.lua"] = { why = "x", calls = { ["A:Hide"] = 0 } } }' }, "a whole number of 1 or more")
	rejects({ ["Core.lua"] = 'return { ["Core/Init.lua"] = { why = "x", calls = { ["A:Hide"] = 1.5 } } }' }, "a whole number of 1 or more")
	rejects({ ["Core.lua"] = 'return { ["Core/Init.lua"] = { why = "x", reason = "y", calls = { ["A:Hide"] = 1 } } }' }, "unknown field reason")
	rejects({ ["Core.lua"] = "return 1" }, "must return a table")
	rejects({ ["Core.lua"] = "return {" }, "Core.lua")
	rejects({ ["Core.lua"] = "os.exit(1)" }, "Core.lua")
end)
os.execute("rm -rf '" .. root .. "'")
assert(ok, err)

-- Check: a finding needs an entry, and the entry's count must match the number of places in the
-- file that make the call. One place can give a frame-call and a setparent-unguarded finding.
local function finding(line, kind, call, site)
	return { line = line, kind = kind, call = call, site = site }
end
local allow = {
	["Core/Safe.lua"] = { why = "x", calls = { ["PlayerFrame:SetParent"] = 2 }, file = "Tools/regression/taint_allow/Core.lua" },
}
local first = { finding(3, "frame-call", "PlayerFrame:SetParent", 10), finding(3, "setparent-unguarded", "PlayerFrame:SetParent", 10) }
local second = finding(9, "frame-call", "PlayerFrame:SetParent", 50)

local function check(scanned, want)
	local problems = Scan.Check(scanned, allow)
	local got = table.concat(problems, "\n")
	if not want then
		assert(#problems == 0, "expected no problems, got:\n" .. got)
		return
	end
	assert(#problems == 1, "expected one problem, got:\n" .. got)
	for _, part in ipairs(want) do
		assert(got:find(part, 1, true), "the problem must mention " .. part .. ":\n" .. got)
	end
end

check({ ["Core/Safe.lua"] = { first[1], first[2], second }, ["Core/Init.lua"] = {} })
check(
	{ ["Core/Safe.lua"] = { first[1], first[2], second }, ["Core/Init.lua"] = { finding(12, "frame-call", "TargetFrame:Hide", 7) } },
	{ "Core/Init.lua:12: frame-call TargetFrame:Hide is not allowed", '["TargetFrame:Hide"] = 1', "Tools/regression/taint_allow/Core.lua" }
)
check(
	{ ["Core/Safe.lua"] = { first[1], first[2], second }, ["KstyleUI_Bags/Bags.lua"] = { finding(5, "field-write", "ContainerFrame1.x", 3) } },
	{ "KstyleUI_Bags/Bags.lua:5: field-write ContainerFrame1.x", "to Tools/regression/taint_allow/KstyleUI_Bags.lua" }
)
local third = finding(40, "frame-call", "PlayerFrame:SetParent", 90)
check({ ["Core/Safe.lua"] = { first[1], first[2], second, third } }, { "found 3 times (lines 3, 9, 40) but allowed 2" })
check({ ["Core/Safe.lua"] = first }, { "allowed 2 times but found 1 (lines 3)", "Lower the count to 1" })
check({ ["Core/Safe.lua"] = {} }, { "Core/Safe.lua PlayerFrame:SetParent is no longer found" })
check({}, { "Core/Safe.lua is not a scanned TOC-loaded Lua file" })

print("taint allow ok")
