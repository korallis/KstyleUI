-- options_aura_filters.lua: the real aura filter rows in use on each of the three module pages, selected with RENDER_AURA_MODULE.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")

return Common.Run(function()
	local module = os.getenv("RENDER_AURA_MODULE") or "Auras"
	local loaders = { Auras = "auras_env", Nameplates = "nameplates_env", GroupFrames = "group_env" }
	local loader = dofile("Tools/regression/" .. assert(loaders[module], "unknown aura module") .. ".lua")
	local env, K = loader.New(Common.ScreenOpts({
		saved = Gallery.Saved({ [module] = {} }), setup = function(env)
			Gallery.Setup(env)
			env.C_AddOns = { LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not env._addons[name] then Load(O.Files(), env) end
				return true
			end }
		end,
	}))
	local prefix = module == "GroupFrames" and "auras" or "debuffs"
	for key, value in pairs({ onlyMine = true, dispellable = true, allowSpells = "589, 139, 774", blockSpells = "139" }) do
		K.Options.Write(module, prefix .. "." .. key, value)
	end
	K.Options.Write(module, prefix .. "." .. (module == "Nameplates" and "order" or "sort"), module == "Nameplates" and "longest" or "name")
	if module == "Auras" then K.Options.Write(module, "timer.position", "inside") end
	if module == "GroupFrames" then K.Options.Write(module, "raid.width", 160) end
	assert(K.Options.Open(module))
	K.Layout.Set("Options.Window", "scale", 1)
	K.Layout.Set("Options.Window", "width", 1100)
	K.Layout.Set("Options.Window", "height", 800)
	for _, element in ipairs(K.Layout.Elements()) do
		if element.module == module then K.Layout.Element(element.key).frame:Hide() end
	end
	env.RunTimers()
	Gallery.Ticks(O.W, env, 40)
	env.RunTimers()
	local ns = env._addons.KstyleUI_Options
	for i, item in ipairs(ns.Window.State().items) do
		if item.key == prefix .. ".onlyMine" then
			ns.Window.Parts().content:ScrollToIndex(i, true, "TOP")
			break
		end
	end
	Gallery.Ticks(O.W, env, 40)
	env.RunTimers()
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Gallery.Build(env)
end)
