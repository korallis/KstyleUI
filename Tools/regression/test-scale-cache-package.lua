-- test-scale-cache-package.lua: packager version replacement enables the release cache without rewriting the development marker.
local C = dofile("Tools/regression/core_env.lua")
local fs = dofile("Tools/regression/fs.lua")
local tmp = fs.tmp()
fs.mkdir(tmp .. "/Core")
local files, replaced = C.Files(), {}
for i, path in ipairs(files) do
	if path == "Core/Init.lua" or path == "Core/Scale.lua" then
		local input = assert(io.open(path, "rb"))
		local source = input:read("*a")
		input:close()
		local output = assert(io.open(tmp .. "/" .. path, "wb"))
		output:write((source:gsub("@project%-version@", "package-cache-test")))
		output:close()
		replaced[i], files[i] = path, tmp .. "/" .. path
	end
end
local ok, env, K = pcall(C.New, { width = 3456, height = 2234, fit = true, size = "auto" })
for i, path in pairs(replaced) do files[i] = path end
assert(ok, env)
C.Boot(env)
assert(K.VERSION == "package-cache-test", "the fixture must replace the real release version")
assert(env.KstyleUIDB.scaleCache and env.KstyleUIDB.scaleCache.version == K.VERSION,
	"assemble the development marker so packager substitution does not disable release caching")
assert(#env._errors == 0 and K.ErrorCount() == 0, "the packaged bootstrap must load without errors")
print("scale cache package ok")
