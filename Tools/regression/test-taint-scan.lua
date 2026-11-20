-- test-taint-scan.lua: every taint-scan finding in a TOC-loaded file is listed, with a reason, in the allow-list.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Scan = dofile("Tools/regression/taint_scan.lua")
local allow = dofile("Tools/regression/taint_allow.lua")
local names = Scan.BlizzardNames(dofile("Tools/data/forever_globals.lua").read)

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local scanned, count = {}, 0
for _, path in ipairs(TocFiles("%.lua$")) do
	if not (path:match("^Libs/") or path:find("/Libs/", 1, true)) then
		local ok, result = pcall(Scan, read(path), names)
		assert(ok, path .. ": " .. tostring(result))
		scanned[path] = result
		count = count + 1
	end
end
assert(count > 0, "the taint scan found no TOC-loaded Lua files")

local problems = Scan.Check(scanned, allow)
if #problems > 0 then
	-- run-all.sh shows the last 5 lines, so the problems come last and error()'s traceback is avoided.
	print(#problems .. " taint-scan problems. Tools/regression/README.md explains the allow-list. Full list: luajit Tools/regression/test-taint-scan.lua")
	for _, problem in ipairs(problems) do
		print(problem)
	end
	os.exit(1)
end

print("taint scan ok: " .. count .. " files")
