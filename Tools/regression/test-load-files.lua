-- test-load-files.lua: Load runs addon files in a stub environment with the game's varargs.
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local dir = os.tmpname()
os.remove(dir)
os.execute("mkdir -p '" .. dir .. "/Core' '" .. dir .. "/KstyleUI_Bars'")

local function write(rel, text)
	local f = assert(io.open(dir .. "/" .. rel, "wb"))
	f:write(text)
	f:close()
	return dir .. "/" .. rel
end

local ok, err = pcall(function()
	local files = {
		write("Core/Init.lua", "local name, ns = ...\nKstyleUI = ns\nns.name = name\nns.order = { 'Init' }\n"),
		write("Core/Second.lua", "local _, ns = ...\nns.order[#ns.order + 1] = 'Second'\n"
			.. "ns.frame = CreateFrame('Frame', 'KstyleUITestFrame')\nns.kind = type(Secret(3))\n"),
		write("KstyleUI_Bars/Bars.lua", "local name, ns = ...\nns.name = name\nKstyleUI_BarsLoaded = ns\n"),
	}
	local env = Stubs.NewEnv()
	assert(Load(files, env) == env, "Load returns the environment it ran in")

	local core = env.KstyleUI
	assert(type(core) == "table" and core.name == "KstyleUI", "core files get the addon name KstyleUI")
	assert(core.order[1] == "Init" and core.order[2] == "Second", "files share one private table, in order")
	assert(core.frame == env.KstyleUITestFrame, "loaded code reaches the stub API")
	assert(core.kind == "number", "loaded code gets the stub's secret-aware type()")

	local bars = env.KstyleUI_BarsLoaded
	assert(bars and bars.name == "KstyleUI_Bars", "a KstyleUI_<Module>/ file gets its folder's addon name")
	assert(bars ~= core, "each addon gets its own private table")

	for _, name in ipairs({ "KstyleUI", "KstyleUI_BarsLoaded", "KstyleUITestFrame" }) do
		assert(rawget(_G, name) == nil, name .. " leaked into the real globals")
	end

	local broken = write("Core/Broken.lua", "local x = = 1\n")
	local loaded, message = pcall(Load, { broken }, Stubs.NewEnv())
	assert(not loaded and tostring(message):find("Broken.lua", 1, true), "a syntax error names the file")
end)
os.execute("rm -rf '" .. dir .. "'")
assert(ok, err)

print("load files ok")
