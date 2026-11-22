-- options_setup.lua: one real Options page or setup step at a chosen window scale for G4/G9 evidence.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = O.W

return Common.Run(function()
	local profile = {}
	local unitFrames = os.getenv("RENDER_PAGE") == "UnitFrames"
	if unitFrames then profile.UnitFrames = { enabled = true, edit = "target" } end
	if os.getenv("RENDER_OPTIONS_FINISH") == "previous" then
		profile.OptionsPresentation = { tasks = false, synonyms = false, preview = false, switches = false, samples = false, columns = false, readableText = false }
		profile.Setup = { layoutPictures = false, readableNotes = false }
	end
	local loader = unitFrames and dofile("Tools/regression/unitframes_env.lua") or O
	local env, K = loader.New(Common.ScreenOpts({
		saved = Gallery.Saved(profile),
		setup = function(env)
			Gallery.Setup(env)
			env.C_AddOns = {
				IsAddOnLoaded = function(name) return name == os.getenv("RENDER_ADDON") end,
				DoesAddOnExist = function() return true end,
				LoadAddOn = function(name)
					if name == "KstyleUI_Options" and not env._addons[name] then Load(O.Files(), env) end
					return true
				end,
			}
		end,
	}))
	local key
	if os.getenv("RENDER_SUBJECT") == "setup" then
		for _, name in ipairs(K.Setup.PICKER) do K.Modules.Register(W.CoreEnv.Module(name.name)) end
		assert(K.Setup.Open(true))
		assert(K.Setup.Go(tonumber(os.getenv("RENDER_SETUP_STEP")) or 3))
		key = "setup.window"
	else
		local page = os.getenv("RENDER_PAGE")
		assert(K.Options.Open(page ~= "" and page or nil))
		if unitFrames then
			for _, element in ipairs(K.Layout.Elements()) do
				if element.module == "UnitFrames" then K.Layout.Element(element.key).frame:Hide() end
			end
		end
		key = "Options.Window"
	end
	K.Layout.Set(key, "scale", tonumber(os.getenv("RENDER_WINDOW_SCALE")) or 1)
	env.RunTimers()
	Gallery.Ticks(W, env, 40)
	env.RunTimers()
	if os.getenv("RENDER_SECTION") and env._addons.KstyleUI_Options then
		local options = env._addons.KstyleUI_Options
		for i, item in ipairs(options.Window.State().items) do
			if item.kind == "header" and item.label == os.getenv("RENDER_SECTION") then options.Window.Parts().content:ScrollToIndex(i, true, "TOP"); break end
		end
		Gallery.Ticks(W, env, 40)
	end
	local query = os.getenv("RENDER_QUERY")
	if query and env._addons.KstyleUI_Options then
		local parts = env._addons.KstyleUI_Options.Window.Parts()
		parts.search:SetText(query)
		parts.search:GetScript("OnTextChanged")(parts.search, true)
		Gallery.Ticks(W, env, 40)
	end
	local err = Common.Errors(env, K)
	assert(not err, tostring(err))
	return Gallery.Build(env)
end)
