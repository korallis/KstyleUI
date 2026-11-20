-- options_frames_parity.lua: each real frame options page, selected with RENDER_PARITY_MODULE and optionally RENDER_OPTIONS_KEY.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
return Common.Run(function()
	local module = os.getenv("RENDER_PARITY_MODULE") or "UnitFrames"
	local loaders = { UnitFrames = "unitframes_env", GroupFrames = "group_env", Nameplates = "nameplates_env" }
	local loader = dofile("Tools/regression/" .. assert(loaders[module]) .. ".lua")
	local env, K = loader.New(Common.ScreenOpts({ saved = Gallery.Saved({ module }), setup = function(e)
		Gallery.Setup(e)
		e.C_AddOns = { LoadAddOn = function(name)
			if name == "KstyleUI_Options" and not e._addons[name] then Load(O.Files(), e) end
			return true
		end }
	end }))
	if module == "UnitFrames" then K.Options.Write(module, "edit", "player") end
	if module == "UnitFrames" and os.getenv("RENDER_PARITY_ENABLED") == "1" then
		K.Options.Write(module, "player.castbarSmooth", true)
		K.Options.Write(module, "player.castbarChannelOverride", true)
	end
	if module == "GroupFrames" then
		K.Options.Write(module, "party.width", 350)
		K.Options.Write(module, "party.healthTextPlace", "BAR")
	end
	assert(K.Options.Open(module))
	K.Layout.Set("Options.Window", "width", 1100)
	K.Layout.Set("Options.Window", "height", 800)
	for _, element in ipairs(K.Layout.Elements()) do
		if element.module == module then K.Layout.Element(element.key).frame:Hide() end
	end
	env.RunTimers(); Gallery.Ticks(O.W, env, 40)
	local keys = { UnitFrames = "player.castbarSpark", GroupFrames = "icons.afk", Nameplates = "cast.spark" }
	env._addons.KstyleUI_Options.Window.Jump({ page = module, module = module, key = os.getenv("RENDER_OPTIONS_KEY") or keys[module] })
	env.RunTimers(); Gallery.Ticks(O.W, env, 40)
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Gallery.Build(env)
end)
