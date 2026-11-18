-- setup_welcome.lua: the real first-run welcome page at the selected screen, HUD style and locale.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local W = dofile("Tools/regression/widget_env.lua")

return Common.Run(function()
	local env, K = W.New(Common.ScreenOpts({
		saved = Gallery.Saved({}),
		boot = false,
		setup = function(env)
			Gallery.Setup(env)
		end,
	}))
	W.CoreEnv.Boot(env)
	if os.getenv("RENDER_WELCOME") == "classic" then
		K.Options.Write("Widgets", "general.brandedWelcome", false)
	end
	assert(K.Setup.Open(true))
	W.Settle(env)
	env.RunTimers()
	Gallery.Ticks(W, env, 40)
	local err = Common.Errors(env, K)
	assert(not err, tostring(err))
	return dofile("Tools/render/scenes/_welcome.lua")(Gallery.Build(env))
end)
