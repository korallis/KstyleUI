-- load_files.lua: run addon files in a stub environment, as the game loads them.

-- Load(files, env) -> env
-- Runs each file with setfenv(chunk, env) and the varargs the game passes: the addon name and the
-- addon's private table. Files under a KstyleUI_<Module>/ folder belong to that module's addon; every
-- other file belongs to KstyleUI. Each addon's private table is kept in env._addons[name].
-- When env._size is a number (Stubs.NewEnv's size option, 1 unless a test asks for "default"), the Interface size
-- defaults to it once Core/Appearance.lua registers its defaults, before the saved data loads.
local function PinSize(env, ns)
	local size = env._size
	if type(size) ~= "number" or not (ns.Appearance and ns.Store and ns.Scale) then
		return
	end
	ns.Appearance.defaults.uiScale = size
	ns.Store.Defaults("Appearance").uiScale = size
	ns.Scale.SetUserScale(size)
end

return function(files, env)
	env._addons = env._addons or {}
	for _, path in ipairs(files) do
		local addon = path:match("(KstyleUI_[%w_]+)/") or "KstyleUI"
		env._addons[addon] = env._addons[addon] or {}
		local chunk = assert(loadfile(path))
		setfenv(chunk, env)
		chunk(addon, env._addons[addon])
		if path == "Core/Setup/Layouts.lua" and not env._fitScale then
			local ns = env._addons[addon]
			ns.Setup.Layouts.ScaleLimit = function()
				return ns.Scale.MAX_USER_SCALE
			end
		end
		if path == "Core/Appearance.lua" then
			PinSize(env, env._addons[addon])
		end
	end
	return env
end
