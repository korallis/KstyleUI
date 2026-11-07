-- options_env.lua: load the core, its widget kit and the on-demand KstyleUI_Options addon into a stub environment.
--
--   local O = dofile("Tools/regression/options_env.lua")
--   local env, K, ns = O.New()       -- core booted, KstyleUI_Options loaded the way LoadAddOn loads it
--   K.Options.Open("Profiles")       -- opens the settings window on a page
--
-- O.New(opts) takes the widget_env options. opts.before(env, K) runs after the core boots and before
-- the settings addon loads, for registering test modules. C_AddOns.LoadAddOn loads the addon's files.
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local O = { W = W }

local optionFiles
function O.Files()
	if not optionFiles then
		optionFiles = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:match("^KstyleUI_Options/") then
				optionFiles[#optionFiles + 1] = path
			end
		end
		assert(#optionFiles > 0, "no KstyleUI_Options files found")
	end
	return optionFiles
end

function O.New(opts)
	opts = opts or {}
	local setup = opts.setup
	opts.setup = function(env)
		env._loads = {}
		env.C_AddOns = {
			LoadAddOn = function(name)
				env._loads[#env._loads + 1] = name
				if name == "KstyleUI_Options" and not env._addons.KstyleUI_Options then
					Load(O.Files(), env)
				end
				return true
			end,
		}
		if setup then
			setup(env)
		end
	end
	local boot = opts.boot
	opts.boot = false
	local env, K = W.New(opts)
	if boot ~= false then
		W.CoreEnv.Boot(env)
	end
	if opts.before then
		opts.before(env, K)
	end
	if opts.load ~= false then
		env.C_AddOns.LoadAddOn("KstyleUI_Options")
	end
	return env, K, env._addons.KstyleUI_Options
end

-- Find(list, fn) -> the first item for which fn(item) is true.
function O.Find(list, fn)
	for i, item in ipairs(list) do
		if fn(item) then
			return item, i
		end
	end
end

-- Labels(items) -> the label of every item, in order.
function O.Labels(items)
	local out = {}
	for i, item in ipairs(items) do
		out[i] = item.label
	end
	return out
end

return O
