-- layout_links.lua: the real player and detached cast bar share a width and follow a four-side link, with their Options rows or Layout Mode selected.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
return Common.Run(function(opts)
	opts = opts or {}
	local env, K = U.New(Common.ScreenOpts({
		saved = Gallery.Saved({ UnitFrames = { player = { castbarInside = false } } }),
		setup = function(e)
			Gallery.Setup(e)
			e._units.player = { name = "Valerin", class = "WARRIOR", level = 38, health = 2750, healthMax = 3350,
				power = 45, powerMax = 100, powerType = 1, powerToken = "RAGE", isPlayer = true, reaction = 5,
				cast = { name = "Slam", texture = 132340, start = 8500, finish = 11000, spellID = 1464 } }
		end,
	}))
	local mode = opts.mode or os.getenv("RENDER_LINK_VIEW") == "mode"
	local target, child = "unitframes.player", "unitframes.castbar.player"
	assert(K.Layout.Update(target, { anchor = "CENTER", x = mode and 0 or 460, y = 0, width = 380 }))
	assert(K.Layout.Update(child, { attachTo = target, side = "below", offset = 24, matchWidth = true }))
	env._time = 10
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 1464)
	env.RunTimers()
	if mode then
		if opts.coordinates ~= nil or os.getenv("RENDER_COORDINATES") then
			K.Options.Write("Layout", "showCoordinates", opts.coordinates == true or os.getenv("RENDER_COORDINATES") == "1")
		end
		assert(K.Layout.Enter())
		K.Layout.Mode.Select(child)
	else
		Load(O.Files(), env)
		assert(K.Options.Open("Elements"))
		local ns = env._addons.KstyleUI_Options
		assert(K.Layout.Update("Options.Window", { anchor = "LEFT", x = 24, y = 0, scale = 0.85 }))
		local search = ns.Window.Parts().search
		search:SetText("Player cast bar")
		search:GetScript("OnTextChanged")(search, true)
	end
	Gallery.Ticks(U.W, env, 20)
	local err = Common.Errors(env, K)
	assert(not err, tostring(err))
	local roots = mode and { K.Layout.Mode.Overlay(), K.Layout.Mode.Toolbar() } or nil
	return Gallery.Build(env, { time = env._time, roots = roots })
end)
