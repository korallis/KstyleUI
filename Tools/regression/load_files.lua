-- load_files.lua: run addon files in a stub environment, as the game loads them.

-- Load(files, env) -> env
-- Runs each file with setfenv(chunk, env) and the varargs the game passes: the addon name and the
-- addon's private table. Files under a KstyleUI_<Module>/ folder belong to that module's addon; every
-- other file belongs to KstyleUI. Each addon's private table is kept in env._addons[name].
-- When env._size is a number (Stubs.NewEnv's size option, 1 unless a test asks for "default"), the Interface size
-- defaults to it, with the automatic size off, once Core/Appearance.lua registers its defaults, before the saved data
-- loads. "default" pins the size KstyleUI shipped before the automatic size (Scale.DEFAULT_USER_SCALE) the same way.
-- A pinned size applies exactly, not snapped to the screen's pixel-perfect step, as ScaleLimit is pinned below, so a
-- module's test measures exact unit sizes. "auto" leaves the shipped automatic size and its steps on.
local function PinSize(env, ns)
	local size = env._size
	if not (ns.Appearance and ns.Store and ns.Scale) then
		return
	end
	if size == "default" then
		size = ns.Scale.DEFAULT_USER_SCALE
	end
	if type(size) ~= "number" then
		return
	end
	ns.Appearance.defaults.uiScale, ns.Appearance.defaults.uiScaleAuto = size, false
	ns.Store.Defaults("Appearance").uiScale, ns.Store.Defaults("Appearance").uiScaleAuto = size, false
	ns.Scale.Nearest = function(requested, _, maximum)
		return math.min(requested, maximum)
	end
	ns.Scale.SetAuto(false)
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
