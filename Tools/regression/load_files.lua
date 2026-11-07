-- load_files.lua: run addon files in a stub environment, as the game loads them.

-- Load(files, env) -> env
-- Runs each file with setfenv(chunk, env) and the varargs the game passes: the addon name and the
-- addon's private table. Files under a KstyleUI_<Module>/ folder belong to that module's addon; every
-- other file belongs to KstyleUI. Each addon's private table is kept in env._addons[name].
return function(files, env)
	env._addons = env._addons or {}
	for _, path in ipairs(files) do
		local addon = path:match("(KstyleUI_[%w_]+)/") or "KstyleUI"
		env._addons[addon] = env._addons[addon] or {}
		local chunk = assert(loadfile(path))
		setfenv(chunk, env)
		chunk(addon, env._addons[addon])
	end
	return env
end
