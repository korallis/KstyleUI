-- test-secrets.lua: no TOC-loaded file compares, does arithmetic on, or tests a secret value, or touches the combat log.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Lint = dofile("Tools/regression/secret_lint.lua")

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local problems, count = {}, 0
for _, path in ipairs(TocFiles("%.lua$")) do
	if not (path:match("^Libs/") or path:find("/Libs/", 1, true)) then
		local ok, result = pcall(Lint, read(path))
		assert(ok, path .. ": " .. tostring(result))
		for _, f in ipairs(result) do
			problems[#problems + 1] = string.format("%s:%d: %s %s", path, f.line, f.kind, f.name)
		end
		count = count + 1
	end
end
assert(count > 0, "the secret lint found no TOC-loaded Lua files")

if #problems > 0 then
	-- run-all.sh shows the last 5 lines, so the problems come last and error()'s traceback is avoided.
	print(#problems .. " secret-lint problems. Guard each use with issecretvalue; Tools/regression/README.md shows how. Full list: luajit Tools/regression/test-secrets.lua")
	for _, problem in ipairs(problems) do
		print(problem)
	end
	os.exit(1)
end

print("secret lint ok: " .. count .. " files")
