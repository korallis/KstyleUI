-- restedxp_arrow.lua: RestedXP's waypoint on its own, for dark/bright backdrop comparisons.
-- RENDER_RXP_ARROW_TEXTURE may name a PNG decoded from the installed RestedXP DarkMode BLP;
-- without it the kit chevron is an explicitly logged alpha stand-in. Rotation is zero because
-- the renderer does not model mask rotation; test-skins-restedxp-arrow.lua verifies that API path.
local Common = dofile("Tools/render/scenes/_common.lua")
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")

return Common.Run(function()
	local rxp
	local env, K = S.New(Common.ScreenOpts({ setup = function(e)
		Common.ForceScreen(e)
		rxp = Fake.Install(e, { activeTheme = "DarkMode", release = os.getenv("RENDER_RXP_RELEASE") })
	end }))
	K.Modules.Enable("Skins")
	env.RunTimers()
	rxp.fake.trust(function()
		local arrow = rxp.arrowFrame
		arrow:ClearAllPoints()
		arrow:SetPoint("TOP", env.UIParent, "TOP", 0, -160)
	end)()
	rxp.fake.arrow("Tirisfal Glades", 126, 0)
	local art = os.getenv("RENDER_RXP_ARROW_TEXTURE")
	local scene = Common.Scene.Build(env, {
		roots = { rxp.arrowFrame },
		paths = function(path)
			if type(path) == "string" and path:find("rxp_navigation_arrow", 1, true) then
				return art or "Media/Textures/GlyphChevron.png"
			end
			return Common.Scene.ResolvePath(path)
		end,
	})
	scene.log[#scene.log + 1] = art and "restedxp arrow: installed DarkMode artwork decoded to PNG" or "restedxp arrow: kit chevron alpha stand-in; set RENDER_RXP_ARROW_TEXTURE for installed artwork"
	local err = Common.Errors(env, K)
	assert(not err, err)
	return scene
end)
