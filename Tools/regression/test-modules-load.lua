-- test-modules-load.lua: each module addon's files run after the core in the stub environment, and a module that loads with the core creates no frames.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- Files in load order, grouped by addon folder.
local core, byFolder, order = {}, {}, {}
for _, path in ipairs(TocFiles("%.lua$")) do
	local folder = path:match("^(KstyleUI_[%w_]+)/")
	if folder then
		if not byFolder[folder] then
			byFolder[folder] = {}
			order[#order + 1] = folder
		end
		local files = byFolder[folder]
		files[#files + 1] = path
	else
		core[#core + 1] = path
	end
end
assert(#order > 0, "no module Lua files found")

for _, folder in ipairs(order) do
	local env = Load(core, Stubs.NewEnv())
	local frames = #env._frames
	local ok, err = pcall(Load, byFolder[folder], env)
	assert(ok, folder .. " failed to load: " .. tostring(err))

	local ns = env._addons[folder]
	assert(type(ns) == "table", folder .. " has no addon table")
	assert(env.KstyleUI == env._addons.KstyleUI, folder .. " replaced the KstyleUI global")

	-- The spec's module lifecycle: at load a module only registers itself, so a player who never
	-- enables it pays nothing. A load-on-demand addon loads only when it is used.
	local onDemand = ("\n" .. read(folder .. "/" .. folder .. ".toc")):match("\n##%s*LoadOnDemand%s*:%s*1")
	if not onDemand then
		assert(#env._frames == frames, folder .. " created " .. (#env._frames - frames) .. " frames at load; build frames in Enable")
	end
end

print("modules load ok: " .. #order .. " modules")
