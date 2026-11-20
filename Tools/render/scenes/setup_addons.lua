-- setup_addons.lua: the real setup with a client-list fixture: RestedXP, Questie, Details, Bartender; the unsupported addon is omitted.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Addons = dofile("Tools/regression/addons_fake.lua")

return Common.Run(function()
	local env, K = W.New(Common.ScreenOpts({ boot = false, saved = Gallery.Saved({}), setup = function(e)
		Gallery.Setup(e)
		Addons.Install(e)
	end }))
	local files = {}
	for _, path in ipairs(TocFiles("%.lua$")) do
		if path:match("^KstyleUI_") and not path:match("^KstyleUI_Options/") then files[#files + 1] = path end
	end
	Load(files, env)
	W.CoreEnv.Boot(env)
	assert(K.Setup.Open(true))
	assert(K.Setup.Go(K.Setup.Integrations.Addons and 5 or 4))
	Gallery.Ticks(W, env, 40)
	local err = Common.Errors(env, K)
	assert(not err, tostring(err))
	return Gallery.Build(env)
end)
